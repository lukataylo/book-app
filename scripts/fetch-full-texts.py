#!/usr/bin/env python3
"""Fetch the public-domain source text for every catalog title.

Run once; commit the output. `BookApp/Resources/FullTexts/<slug>.txt` is
read at launch by `SummaryPackLoader`, which seeds it as the book's
`.original` variant — the summary that used to hold that slot becomes a
`.compressed` one beside it.

    python3 scripts/fetch-full-texts.py [slug ...]

The slug → source map below is hand-checked, not searched. Gutenberg's
search matches the wrong work for at least four of these titles (the
Beagle voyage returns a sailor's dictionary; Douglass returns Equiano),
so every id here was confirmed against the text's own Title: line.

Output is plain UTF-8 with the reader's `# ` heading marker, which the
chapter list, TTS and transformation chunker all already understand.
"""

import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "BookApp/Resources/FullTexts"
UA = "epigrapha-corpus/1.0 (one-time public-domain text fetch)"

# slug -> source. `pg` is a gutenberg.org ebook id; `url` is a direct
# fetch; `ws` is an English Wikisource work fetched chapter by chapter.
# `slice` keeps only the span between two markers (inclusive start,
# exclusive end) — used where the work only exists inside a collection.
# `start` drops everything above a marker, for editions that open with a
# translator's apparatus longer than the book.
CATALOG = {
    "meditations":                                {"pg": 2680},
    # PG 132 is Giles's 1910 scholarly edition: 45k words of translator's
    # apparatus wrapped around, and interleaved with, a 9k-word book.
    # 17405 is the same translation with the commentary stripped.
    "the-art-of-war": {
        "pg": 17405,
        "slice": ("\nI. LAYING PLANS\n", None),
    },
    "the-prince":                                 {"pg": 1232},
    "walden":                                     {"pg": 205},
    "on-liberty":                                 {"pg": 34901},
    "the-republic":                               {"pg": 1497},
    "the-wealth-of-nations":                      {"pg": 3300},
    "on-the-origin-of-species":                   {"pg": 1228},
    "the-voyage-of-the-beagle":                   {"pg": 944},
    "relativity":                                 {"pg": 30155},
    "the-interpretation-of-dreams":               {"pg": 66048},
    # Volume 1 of 2. Volume 2 is another 1.7 MB of a book nobody finishes.
    "the-principles-of-psychology":               {"pg": 57628},
    # Volume 1 of 2, likewise.
    "democracy-in-america":                       {"pg": 815},
    "the-souls-of-black-folk":                    {"pg": 408},
    "up-from-slavery":                            {"pg": 2376},
    "narrative-of-the-life-of-frederick-douglass": {"pg": 23},
    "as-a-man-thinketh":                          {"pg": 4507},
    "how-to-live-on-24-hours-a-day":              {"pg": 2274},
    "the-crowd":                                  {"pg": 445},
    "the-theory-of-the-leisure-class":            {"pg": 833},
    "the-principles-of-scientific-management":    {"pg": 6435},
    "the-essays-of-montaigne":                    {"pg": 3600},
    "the-history-of-the-peloponnesian-war":       {"pg": 7142},
    # Volume 1 of 6. The complete set is 10.7 MB — a third of the whole
    # corpus for one title.
    "the-decline-and-fall-of-the-roman-empire":   {"pg": 731},
    "the-autobiography-of-benjamin-franklin":     {"pg": 20203},
    # Self-Reliance was never published alone; it is the second essay in
    # Essays: First Series. PG 2944 is the plain text — 16643 is a school
    # edition whose footnotes outweigh the essays five to one.
    "self-reliance": {
        "pg": 2944,
        "slice": ("\nSELF-RELIANCE\n", "\nCOMPENSATION\n"),
    },
    # 1929, so US public domain only since 1 Jan 2025. Not on
    # gutenberg.org; Project Gutenberg Australia has the text.
    "a-room-of-ones-own": {
        "url": "https://gutenberg.net.au/ebooks02/0200791.txt",
        # Woolf's six chapters are marked ONE, TWO, … not "Chapter 1".
        "slice": ("\nA ROOM OF ONES OWN\n", None),
    },
    # gutenberg.org has no Moral Letters — its only Seneca prose is
    # L'Estrange's "Morals of a Happy Life", a different work. Wikisource
    # carries Gummere's 1917-25 Loeb translation, also public domain.
    "letters-from-a-stoic": {
        "ws": "Moral letters to Lucilius",
        "ws_pages": [f"Letter {n}" for n in range(1, 125)],
    },
}


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        raw = r.read()
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        # Older PG mirrors still ship Latin-1. Decoding those as UTF-8
        # with errors="replace" silently eats every accented character.
        text = raw.decode("latin-1")
    # Gutenberg ships CRLF. Every marker and regex below assumes \n.
    return text.replace("\r\n", "\n").replace("\r", "\n")


def strip_boilerplate(text: str) -> str:
    """Remove the Project Gutenberg header and licence trailer.

    Stripping these also removes every "Project Gutenberg" trademark
    reference, which is the condition under which the PG licence stops
    attaching to the text at all — what remains is the plain
    public-domain work.
    """
    start = re.search(r"\*\*\*\s*START OF TH(?:E|IS) PROJECT GUTENBERG.*?\*\*\*", text, re.I)
    if start:
        text = text[start.end():]
    end = re.search(r"\*\*\*\s*END OF TH(?:E|IS) PROJECT GUTENBERG", text, re.I)
    if end:
        text = text[:end.start()]
    # PG Australia uses a plain-prose header/footer instead of the
    # asterisk markers.
    text = re.sub(r"(?s)^.*?A Project Gutenberg of Australia eBook.*?\n\n", "", text, count=1)
    text = re.sub(r"(?s)\n\s*This site is full of FREE ebooks.*$", "", text)
    return text.strip()


# Structural markers only. A missed heading costs the chapter list one
# entry; a rule loose enough to catch every stylistic variant would
# promote ordinary sentences instead, which is the worse failure.
KEYWORD = r"(?:chapter|book|part|section|letter|essay|appendix|preface|introduction)"
HEADING = re.compile(
    rf"""^(
          (?i:{KEYWORD})\b.*
        | [IVXLCDM]+\.?\s*(?:[-—.:]\s*.+)?
        | [A-Z][A-Z' ,.\-—]{{2,60}}
        )$""",
    re.X,
)


def mark_headings(text: str) -> str:
    """Convert chapter titles to the reader's `# ` marker.

    A heading is a short standalone block with no terminal punctuation.
    Editions differ: some put the whole title on one line, Gibbon's wraps
    "Chapter I: The Extent Of The Empire In The Age Of The Antonines"
    across two — so a block that *opens* with a structural keyword and
    unwraps short is treated as one heading.

    Everything else is unwrapped into a single paragraph, because
    Gutenberg hard-wraps at ~70 columns and the reader reflows.
    """
    out = []
    for block in re.split(r"\n\s*\n", text):
        line = block.strip()
        if not line:
            continue
        flat = re.sub(r"\s*\n\s*", " ", line)
        stripped = flat.rstrip(".")
        wrapped_title = (
            "\n" in line
            and len(flat) <= 120
            and re.match(rf"(?i:{KEYWORD})\b", flat)
            and not flat.endswith((".", "?", "!"))
        )
        single_title = (
            "\n" not in line
            and 2 < len(flat) <= 70
            and HEADING.match(stripped)
            and not flat.endswith((",", ";", ":"))
        )
        out.append("# " + stripped if (wrapped_title or single_title) else flat)
    return "\n\n".join(out)


def take_slice(text: str, start: str, end: str | None) -> str:
    i = text.find(start)
    if i < 0:
        raise SystemExit(f"slice start {start!r} not found")
    text = text[i:]
    if end:
        j = text.find(end, len(start))
        if j < 0:
            raise SystemExit(f"slice end {end!r} not found")
        text = text[:j]
    return text.strip()


def wikisource(work: str, pages: list[str]) -> str:
    """One rendered page per chapter, tags stripped.

    Wikisource transcludes the body from the Page: namespace, so the raw
    wikitext is just a `<pages index=…>` stub — the rendered HTML is the
    only place the actual text exists.
    """
    parts = []
    for name in pages:
        q = urllib.parse.urlencode({
            "action": "parse", "page": f"{work}/{name}",
            "prop": "text", "format": "json",
        })
        # Wikisource returns 429 well before 124 sequential requests are
        # done. Back off and retry rather than silently dropping letters —
        # a gap here is missing pages of the book, not a cosmetic loss.
        data = None
        for attempt in range(8):
            try:
                data = json.loads(fetch(f"https://en.wikisource.org/w/api.php?{q}"))
                break
            except Exception as exc:
                wait = min(2 ** attempt, 60)
                print(f"    {name}: {exc} — retrying in {wait}s", file=sys.stderr)
                time.sleep(wait)
        if data is None:
            raise SystemExit(f"{name}: gave up after 8 attempts")
        if "parse" not in data:
            raise SystemExit(f"{name}: no such page")
        raw = data["parse"]["text"]["*"]
        raw = re.sub(r"(?s)<(script|style|table|sup).*?</\1>", "", raw)
        raw = re.sub(r"</p>|<br\s*/?>", "\n\n", raw)
        body = html.unescape(re.sub(r"<[^>]+>", "", raw))
        # Everything above the roman-numeral title is site chrome
        # (breadcrumbs, sister-project links, the translator credit).
        m = re.search(r"^\s*([IVXLCDM]+)\.\s+(.+)$", body, re.M)
        if m:
            body = body[m.start():]
        body = re.sub(r"\n{3,}", "\n\n", body).strip()
        if body:
            parts.append(body)
        else:
            raise SystemExit(f"{name}: page parsed to nothing")
        # Wikimedia enforces a short-window per-IP burst limit; 124
        # back-to-back requests trip it every time.
        time.sleep(2.0)
    # A partial fetch is missing pages of the book, and the result still
    # looks like a plausible file. Refuse it rather than commit it.
    if len(parts) != len(pages):
        raise SystemExit(f"expected {len(pages)} sections, got {len(parts)}")
    return "\n\n".join(parts)


def build(slug: str, spec: dict) -> None:
    if "pg" in spec:
        text = strip_boilerplate(fetch(f"https://www.gutenberg.org/ebooks/{spec['pg']}.txt.utf-8"))
    elif "url" in spec:
        text = strip_boilerplate(fetch(spec["url"]))
    else:
        text = wikisource(spec["ws"], spec["ws_pages"])

    if "start" in spec:
        i = text.find(spec["start"])
        if i < 0:
            raise SystemExit(f"{slug}: start marker {spec['start']!r} not found")
        text = text[i:].strip()
    if "slice" in spec:
        text = take_slice(text, *spec["slice"])

    text = mark_headings(text)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f"{slug}.txt").write_text(text + "\n", encoding="utf-8")
    words = len(text.split())
    heads = text.count("\n# ") + text.startswith("# ")
    print(f"  {slug:44} {words:>8,} words  {heads:>4} headings  {len(text)/1024:>7.0f} KB")


def main() -> None:
    wanted = sys.argv[1:] or list(CATALOG)
    total = 0
    for slug in wanted:
        if slug not in CATALOG:
            raise SystemExit(f"unknown slug: {slug}")
        build(slug, CATALOG[slug])
        total += (OUT / f"{slug}.txt").stat().st_size
    print(f"\n{len(wanted)} titles, {total / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
