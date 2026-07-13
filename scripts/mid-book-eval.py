#!/usr/bin/env python3
"""mid-book-eval.py — positional-recall harness for "did the summary forget the middle?"

Implements the eval protocol from
``research/summary-eval/mid-book-fidelity.md`` §4: split a book's full source
text into thirds, extract a panel of verifiable facts from each third, then
score whether a candidate summary demonstrably reflects each fact. The ratio

    positional_recall_gap = recall_middle_third / mean(recall_first_third, recall_last_third)

flags "forgot the middle" failures (well below 1.0) independent of the
summary's raw word-count allocation across the book.

Reuses the EPUB/chunking/Claude-call helpers from ``seed-transform.py`` so
this harness stays consistent with the actual generation pipeline it's
auditing (``Chunker.swift`` / ``TransformationEngine.swift``).

Subcommands:
    facts   BOOK.txt              --out facts.json   [--n 15] [--dry-run]
    score   FACTS.json SUMMARY.md --out recall.json   [--dry-run]
    report  RECALL.json                               [--threshold 0.7]
    run     BOOK.txt SUMMARY.md   --out-dir DIR        (facts + score + report, one shot)

API key: tries the macOS Keychain first (``security find-generic-password``,
same as seed-transform.py), then falls back to the ``ANTHROPIC_API_KEY``
env var — the Keychain isn't available outside macOS, so CI/Linux runs need
the env var.

Cost note: N facts/third × 3 thirds, one extraction call per third and one
scoring call per third (facts batched into a single judge call each) —
roughly the same order of cost as one `seed-learnings.py` book pass.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

# Reuse the EPUB extractor + Claude call helpers from the sibling script,
# exactly as seed-learnings.py / seed-localizations.py already do.
import importlib.machinery
seed = importlib.machinery.SourceFileLoader(
    "seed_transform", str(Path(__file__).resolve().parent / "seed-transform.py")
).load_module()

DEFAULT_MODEL = "claude-sonnet-4-6"
THIRDS = ("first", "middle", "last")


# ---------------------------------------------------------------------------
# API key (Keychain, with an env-var fallback for non-macOS runs)
# ---------------------------------------------------------------------------

def get_key() -> str:
    try:
        return seed.get_key()
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    key = os.environ.get("ANTHROPIC_API_KEY")
    if key:
        return key
    raise RuntimeError(
        "No Anthropic API key found. On macOS this reads the Keychain entry "
        "seed-transform.py uses (com.bookapp.app / anthropic_api_key); "
        "elsewhere, set ANTHROPIC_API_KEY."
    )


# ---------------------------------------------------------------------------
# Splitting the source into thirds (by char count, on paragraph boundaries —
# deliberately NOT the chunker's chapter-aware boundaries, so this eval
# doesn't confound "did the chunker's own boundaries bias coverage" with
# "did the summary lose middle content").
# ---------------------------------------------------------------------------

def split_thirds(text: str) -> dict[str, str]:
    blocks = seed.split_blocks(text)
    total = sum(len(b) for b in blocks)
    target = total / 3
    thirds: dict[str, list[str]] = {"first": [], "middle": [], "last": []}
    running = 0
    for b in blocks:
        idx = min(int(running // target), 2) if target else 0
        thirds[THIRDS[idx]].append(b)
        running += len(b)
    return {k: "".join(v) for k, v in thirds.items()}


# ---------------------------------------------------------------------------
# Step 1 — per-third fact extraction
# ---------------------------------------------------------------------------

FACTS_SYSTEM = (
    "You extract a panel of verifiable facts from a section of a book, for use "
    "as an eval fixture. Each fact must be something a reader could look up or "
    "independently verify against the text — a named person, a specific event, "
    "a concrete number, a direct causal claim, or a quotable line with its "
    "speaker. Do NOT write vague paraphrases ('the author discusses money') — "
    "write the specific claim itself ('Housel says Ronald Read, a gas-station "
    "attendant, died with $6M').\n\n"
    "Reply as a JSON array of exactly {n} objects: "
    '[{{"fact": "...", "evidence": "short quote or paraphrase anchoring it in this text"}}, ...]\n'
    "JSON only — no commentary, no preamble, no markdown fence."
)


def build_facts_prompt(third_text: str, third_label: str, n: int) -> tuple[list[dict], str]:
    system_blocks = [{"type": "text", "text": FACTS_SYSTEM.format(n=n)}]
    user = (
        f"This is the {third_label} third (by character count) of a book's source text.\n\n"
        f"Book excerpt:\n{third_text}"
    )
    return system_blocks, user


def extract_facts(api_key: str, model: str, third_text: str, third_label: str,
                   n: int, dry_run: bool = False) -> list[dict]:
    system_blocks, user = build_facts_prompt(third_text, third_label, n)
    if dry_run:
        print(f"--- DRY RUN: facts prompt for '{third_label}' third ---")
        print(system_blocks[0]["text"])
        print("---")
        print(user[:500] + ("..." if len(user) > 500 else ""))
        return []
    resp = seed.call_claude(
        api_key=api_key, model=model, system_blocks=system_blocks, user_prompt=user,
        max_tokens=3_000, temperature=0.3,
        estimated_input_tokens=seed.token_estimate(user) + 300,
    )
    items = _parse_json_array(resp)
    for it in items:
        it["third"] = third_label
    return items


# ---------------------------------------------------------------------------
# Step 2 — recall scoring against a candidate summary
# ---------------------------------------------------------------------------

SCORE_SYSTEM = (
    "You judge whether a book summary demonstrably reflects a list of facts "
    "extracted from the book's source text. For each fact, decide whether the "
    "summary text below reflects it:\n"
    "  1   = clearly present (the specific entity/claim/event is recoverable "
    "from the summary, even if not verbatim)\n"
    "  0.5 = vaguely gestured at (the general topic is present but the "
    "specific fact is not actually recoverable)\n"
    "  0   = absent\n\n"
    'Reply as a JSON array, same order as the input facts: '
    '[{"fact": "...", "reflected": 0|0.5|1, "reason": "one clause"}, ...]\n'
    "JSON only — no commentary, no preamble, no markdown fence."
)


def score_recall(api_key: str, model: str, facts: list[dict], summary_text: str,
                  dry_run: bool = False) -> list[dict]:
    facts_json = json.dumps([{"fact": f["fact"], "third": f.get("third", "")} for f in facts], indent=2)
    system_blocks = [{"type": "text", "text": SCORE_SYSTEM}]
    user = f"Facts to check:\n{facts_json}\n\nSummary text to judge:\n{summary_text}"
    if dry_run:
        print("--- DRY RUN: score prompt ---")
        print(system_blocks[0]["text"])
        print("---")
        print(user[:800] + ("..." if len(user) > 800 else ""))
        return []
    resp = seed.call_claude(
        api_key=api_key, model=model, system_blocks=system_blocks, user_prompt=user,
        max_tokens=4_000, temperature=0.2,
        estimated_input_tokens=seed.token_estimate(user) + 300,
    )
    scored = _parse_json_array(resp)
    # Carry the third-label back through by matching on fact text (order should
    # already match, but don't trust it blindly).
    by_fact = {f["fact"]: f.get("third", "") for f in facts}
    for s in scored:
        s["third"] = by_fact.get(s.get("fact", ""), "")
    return scored


def _parse_json_array(resp: dict) -> list[dict]:
    text_out = "".join(b["text"] for b in resp["content"] if b["type"] == "text")
    cleaned = text_out.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.split("```", 2)[1]
        if cleaned.startswith("json"):
            cleaned = cleaned[4:]
        cleaned = cleaned.strip().rstrip("`").strip()
    items = json.loads(cleaned)
    assert isinstance(items, list)
    return items


# ---------------------------------------------------------------------------
# Step 3 — the gap metric + report
# ---------------------------------------------------------------------------

def recall_rates(scored: list[dict]) -> dict[str, float]:
    rates = {}
    for third in THIRDS:
        vals = [float(s["reflected"]) for s in scored if s.get("third") == third]
        rates[third] = (sum(vals) / len(vals)) if vals else float("nan")
    return rates


def positional_recall_gap(rates: dict[str, float]) -> float:
    bookends = [rates["first"], rates["last"]]
    bookends = [v for v in bookends if v == v]  # drop NaN
    if not bookends or rates["middle"] != rates["middle"]:
        return float("nan")
    mean_bookend = sum(bookends) / len(bookends)
    return rates["middle"] / mean_bookend if mean_bookend else float("nan")


def print_report(scored: list[dict], threshold: float) -> float:
    rates = recall_rates(scored)
    gap = positional_recall_gap(rates)
    print(f"{'Third':<10}{'N facts':<10}{'Recall':<10}")
    for third in THIRDS:
        n = sum(1 for s in scored if s.get("third") == third)
        print(f"{third:<10}{n:<10}{rates[third]:<10.2f}")
    print(f"\npositional_recall_gap = {gap:.2f}  (threshold {threshold})")
    if gap != gap:
        print("VERDICT: inconclusive (missing data for one or more thirds)")
    elif gap < threshold:
        print("VERDICT: FAIL — summary likely forgot the middle")
    else:
        print("VERDICT: PASS")
    return gap


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def cmd_facts(args: argparse.Namespace) -> None:
    text = Path(args.book).read_text(encoding="utf-8", errors="ignore")
    thirds = split_thirds(text)
    api_key = None if args.dry_run else get_key()
    all_facts: list[dict] = []
    for label, third_text in thirds.items():
        print(f"extracting facts: {label} third ({len(third_text)} chars)...", flush=True)
        all_facts.extend(
            extract_facts(api_key, args.model, third_text, label, args.n, dry_run=args.dry_run)
        )
    if args.dry_run:
        return
    Path(args.out).write_text(json.dumps(all_facts, indent=2), encoding="utf-8")
    print(f"wrote {len(all_facts)} facts -> {args.out}")


def cmd_score(args: argparse.Namespace) -> None:
    facts = json.loads(Path(args.facts).read_text(encoding="utf-8"))
    summary_text = Path(args.summary).read_text(encoding="utf-8")
    api_key = None if args.dry_run else get_key()
    scored: list[dict] = []
    for third in THIRDS:
        third_facts = [f for f in facts if f.get("third") == third]
        if not third_facts:
            continue
        scored.extend(score_recall(api_key, args.model, third_facts, summary_text, dry_run=args.dry_run))
    if args.dry_run:
        return
    Path(args.out).write_text(json.dumps(scored, indent=2), encoding="utf-8")
    print(f"wrote {len(scored)} scored facts -> {args.out}")


def cmd_report(args: argparse.Namespace) -> None:
    scored = json.loads(Path(args.recall).read_text(encoding="utf-8"))
    gap = print_report(scored, args.threshold)
    sys.exit(0 if (gap == gap and gap >= args.threshold) else 1)


def cmd_run(args: argparse.Namespace) -> None:
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    facts_path = out_dir / "facts.json"
    recall_path = out_dir / "recall.json"
    cmd_facts(argparse.Namespace(book=args.book, out=str(facts_path), n=args.n,
                                  model=args.model, dry_run=False))
    cmd_score(argparse.Namespace(facts=str(facts_path), summary=args.summary,
                                  out=str(recall_path), model=args.model, dry_run=False))
    cmd_report(argparse.Namespace(recall=str(recall_path), threshold=args.threshold))


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    p_facts = sub.add_parser("facts", help="extract a positional fact panel from a book's full text")
    p_facts.add_argument("book", help="path to the book's plain-text source")
    p_facts.add_argument("--out", default="facts.json")
    p_facts.add_argument("--n", type=int, default=15, help="facts per third")
    p_facts.add_argument("--model", default=DEFAULT_MODEL)
    p_facts.add_argument("--dry-run", action="store_true", help="print prompts, make no API calls")
    p_facts.set_defaults(func=cmd_facts)

    p_score = sub.add_parser("score", help="score a summary's recall against an extracted fact panel")
    p_score.add_argument("facts", help="facts.json from the `facts` subcommand")
    p_score.add_argument("summary", help="path to the candidate summary text")
    p_score.add_argument("--out", default="recall.json")
    p_score.add_argument("--model", default=DEFAULT_MODEL)
    p_score.add_argument("--dry-run", action="store_true", help="print prompts, make no API calls")
    p_score.set_defaults(func=cmd_score)

    p_report = sub.add_parser("report", help="print recall-by-third and the positional_recall_gap")
    p_report.add_argument("recall", help="recall.json from the `score` subcommand")
    p_report.add_argument("--threshold", type=float, default=0.7)
    p_report.set_defaults(func=cmd_report)

    p_run = sub.add_parser("run", help="one-shot: facts + score + report")
    p_run.add_argument("book")
    p_run.add_argument("summary")
    p_run.add_argument("--out-dir", default="mid-book-eval-out")
    p_run.add_argument("--n", type=int, default=15)
    p_run.add_argument("--model", default=DEFAULT_MODEL)
    p_run.add_argument("--threshold", type=float, default=0.7)
    p_run.set_defaults(func=cmd_run)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
