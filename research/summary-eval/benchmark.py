#!/usr/bin/env python3
"""Score every shipped summary against SKILL.md.

The standard already existed as prose, which meant nobody could tell
whether a pack met it. This turns the measurable half into numbers so a
regression is visible before it ships. It does NOT judge whether a
summary is *good* — no script does. It catches the mechanical tells that
the eval found were our actual failures, and flags outliers for a human
to read.

    python3 research/summary-eval/benchmark.py            # summary table
    python3 research/summary-eval/benchmark.py -v         # per-pack detail

Exit code 1 if any pack fails a hard rule, so it can gate a release.
"""

import glob
import json
import os
import re
import statistics
import sys

PACKS = "BookApp/Resources/SummaryPacks/*.json"

# --- Rule 6: lexical fingerprints, from ai-tells.md §1.1.
#
# Matched as constructions, not bare words. The first pass flagged
# "the leverage is at the start of the chain", "no one's virtue is so
# robust", and "in an era when the idea would have sounded like folk
# wisdom" — all ordinary English. A benchmark that cries wolf gets
# switched off, so each pattern here has to catch the *decorative* use
# and leave the load-bearing one alone.
LEXICAL = [
    r"\bdelv(e|es|ing)\b", r"\btapestry\b", r"\bunderscor(e|es|ing)\b",
    r"\bpivotal\b", r"\bshowcas(e|es|ing)\b", r"\bmeticulous",
    r"\btransformative\b", r"\bmultifaceted\b",
    r"\bin today'?s\b", r"fast-paced world", r"it'?s worth noting",
    r"it is worth noting", r"\bat its core\b",
    r"in an era (defined|marked|characteri[sz]ed) by",
    r"more important than ever", r"\bnavigating the (complexit|challeng|landscape)",
    r"\bis a testament to\b", r"treasure trove", r"game-?changer",
    r"\bdeep dive\b", r"crucial (role|insight|point|distinction)",
    r"vital role", r"\bleverag(e|es|ing|ed) (the|our|their|a|its)\b",
    r"\bmyriad\b", r"\bplethora\b", r"\brich tapestry\b",
]

# --- Rule 6: the balanced-reversal cadence, ai-tells.md §2.2.
NOT_JUST_X = [
    r"\bit'?s not just\b", r"\bthis isn'?t about\b", r"\bnot only does\b",
    r"\bisn'?t just\b", r"\bnot merely\b.{0,40}\bbut\b",
]

# --- Rule 1: closings that advertise us instead of the book.
SELF_ADVERT = [
    r"the full summary", r"this summary (covers|works through|explores)",
    r"read on to", r"in this app",
]

# --- ai-tells.md §2.1: formulaic closers.
FORMULAIC_CLOSE = r"^\s*(overall|in conclusion|in summary|ultimately|to sum up)\b"

# --- Rule 4: a sentence willing to state a limit. Detected by the
# vocabulary of concession, which is crude but catches the difference
# between advocacy and assessment.
FRICTION = [
    "strain", "limit", "objection", "critic", "fails", "wrong", "flaw",
    "aged badly", "does not survive", "unfalsifiable", "overstate",
    "defect", "blind spot", "friction", "where it breaks", "not fatal",
    "half-know", "indefensible", "contested", "weakness", "hole",
    "uncomfortable", "questionable", "concede", "unfair", "误",
]


def sentences(text):
    body = re.sub(r"^#.*$", "", text, flags=re.M)          # drop headings
    body = re.sub(r"\s+", " ", body).strip()
    parts = re.split(r"(?<=[.!?])\s+", body)
    return [p for p in parts if len(p.split()) > 1]


def score(pack):
    text = pack["summary"]
    short = pack.get("summary_short") or ""
    sents = sentences(text)
    lens = [len([w for w in s.split() if re.search(r"\w", w)]) for s in sents]
    words = sum(lens)
    low = text.lower()

    r = {"slug": pack["slug"], "words": words, "short_words": len(short.split())}

    # Rule 3 — rhythm. A wall of uniform sentences is the quietest tell.
    r["sent_sd"] = round(statistics.pstdev(lens), 1) if len(lens) > 1 else 0
    r["short_sents"] = sum(1 for n in lens if n < 8)
    r["short_per_200"] = round(r["short_sents"] / max(words / 200, 1), 2)
    r["longest"] = max(lens) if lens else 0

    # Rule 6 — em-dash budget, one genuine reversal per ~300 words.
    r["dashes"] = text.count("—")
    r["dash_per_300"] = round(r["dashes"] / max(words / 300, 1), 2)

    # Colons are measured for the same reason. Bringing the catalog inside
    # the em-dash budget once pushed colon density from 1.5 to 2.9 per 300
    # words, which is the same tic wearing different punctuation.
    r["colon_per_300"] = round(text.count(":") / max(words / 300, 1), 2)

    # Rule 6 — lexical fingerprints.
    r["lexical"] = sorted({m.group(0) for p in LEXICAL
                           for m in re.finditer(p, low)})

    # Rule 6 — balanced reversals.
    r["not_just_x"] = sum(len(re.findall(p, low)) for p in NOT_JUST_X)

    # Rule 1 — never close by advertising ourselves.
    r["self_advert"] = sum(len(re.findall(p, low)) for p in SELF_ADVERT)
    paras = [p.strip() for p in text.split("\n\n") if p.strip() and not p.startswith("#")]
    r["formulaic_close"] = bool(re.search(FORMULAIC_CLOSE, paras[-1], re.I)) if paras else False

    # Rule 4 — one honest limit somewhere.
    r["friction"] = sum(1 for f in FRICTION if f in low)

    # Rule 5 — lead with the thesis. A first sentence that merely names
    # the book or its topic is throat-clearing.
    first = sents[0] if sents else ""
    r["opens_on_topic"] = bool(re.match(
        r"^(this book|the book|in (this|his|her)|\w+'s book (is|explores))", first.lower()))
    r["first_len"] = len(first.split())

    # Rule 2 — concreteness. Numbers and years are a cheap proxy.
    r["numbers"] = len(re.findall(r"\b\d[\d,\.]*\b", text))

    # Structure — own headings, 3-5 idea sections.
    r["sections"] = len(re.findall(r"^# ", text, flags=re.M))

    # Paragraph uniformity — every paragraph the same size is a tell.
    plens = [len(p.split()) for p in paras]
    r["para_sd"] = round(statistics.pstdev(plens), 1) if len(plens) > 1 else 0

    r["learnings"] = len(pack.get("learnings", []))

    # Hard rules: a pack failing any of these should not ship.
    fails = []
    if r["self_advert"]:                      fails.append("self-advertising")
    if r["formulaic_close"]:                  fails.append("formulaic close")
    if r["short_per_200"] < 0.7:              fails.append("no rhythm variance")
    if r["dash_per_300"] > 1.6:               fails.append("em-dash overuse")
    if r["colon_per_300"] > 3.0:              fails.append("colon overuse")
    if r["lexical"]:                          fails.append("lexical tells")
    if r["not_just_x"] > 1:                   fails.append("not-just-X cadence")
    if r["friction"] < 2:                     fails.append("no friction")
    if r["opens_on_topic"]:                   fails.append("opens on topic")
    if not 3 <= r["sections"] <= 8:           fails.append("section count")
    if r["words"] < 1000:                     fails.append("too short")
    if not 200 <= r["short_words"] <= 450:    fails.append("quick take length")
    if r["learnings"] < 8:                    fails.append("too few learnings")
    r["fails"] = fails
    return r


def main():
    verbose = "-v" in sys.argv
    rows = [score(json.load(open(f))) for f in sorted(glob.glob(PACKS))]
    if not rows:
        print("no packs found — run from the repo root")
        return 1

    bad = [r for r in rows if r["fails"]]
    print(f"{len(rows)} packs · {len(bad)} failing\n")
    hdr = f"{'slug':42} {'words':>5} {'sd':>5} {'<8/200':>6} {'—/300':>6} {':/300':>6} {'frict':>5}  issues"
    print(hdr); print("-" * len(hdr))
    for r in sorted(rows, key=lambda x: (-len(x["fails"]), x["slug"])):
        issues = ", ".join(r["fails"]) or "-"
        if r["lexical"]:
            issues += f"  [{', '.join(r['lexical'])}]"
        print(f"{r['slug']:42} {r['words']:5} {r['sent_sd']:5} {r['short_per_200']:6} "
              f"{r['dash_per_300']:6} {r['colon_per_300']:6} {r['friction']:5}  {issues}")

    # Cross-pack checks. A per-pack score cannot see these: every summary
    # can pass on its own while the catalog reads as one voice with a
    # handful of verbal tics. "The friction" was a section heading in five
    # packs; "worth naming" appeared in nine.
    import collections
    heads = collections.Counter()
    phrases = {
        "worth naming/stating": r"worth (naming|stating|saying)",
        "is the part of the book": r"is the part of the book",
        "the honest X": r"the honest (reading|verdict|answer|limit)",
        "read it/him as": r"\bread (it|him|them|this) as\b",
    }
    texts = {}
    for f in sorted(glob.glob(PACKS)):
        pk = json.load(open(f))
        texts[pk["slug"]] = pk["summary"]
        for h in re.findall(r"^# (.+)$", pk["summary"], flags=re.M):
            heads[h] += 1
    dup = [h for h, n in heads.items() if n > 1]
    print("\nCross-pack")
    print(f"  duplicate headings   {dup or 'none'}")
    firsts = collections.Counter(h.split()[0].lower() for h in heads)
    top, n = firsts.most_common(1)[0]
    print(f"  commonest first word '{top}' in {n}/{sum(firsts.values())} headings")
    for label, pat in phrases.items():
        c = sum(1 for t in texts.values() if re.search(pat, t, re.I))
        flag = "  <-- tic" if c > 4 else ""
        print(f"  {label:22} {c} packs{flag}")

    def spread(key):
        vals = [r[key] for r in rows]
        return f"{min(vals)}–{max(vals)} (median {statistics.median(vals):g})"

    print("\nConsistency across the catalog")
    for k, label in [("words", "summary length"), ("short_words", "quick take"),
                     ("sections", "sections"), ("learnings", "learnings"),
                     ("sent_sd", "sentence-length sd"), ("para_sd", "paragraph sd")]:
        print(f"  {label:20} {spread(k)}")

    if verbose:
        print("\nPer-pack detail")
        for r in rows:
            print(f"\n{r['slug']}")
            for k, v in r.items():
                if k != "slug":
                    print(f"  {k:16} {v}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
