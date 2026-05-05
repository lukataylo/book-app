#!/usr/bin/env python3
"""seed-transform.py — generate the bundled book variants for BookApp.

For each book in ``BOOKS``, this script:
  1. Extracts the EPUB to plain text, mirroring ``EPUBParser.swift`` so the
     bundled output matches what the app would parse at import time.
  2. Chunks the text on chapter boundaries with 4k-token overlap (mirrors
     ``Chunker.swift``).
  3. Generates each variant by mapping over the chunks via the Anthropic
     Messages API, then a per-seam reduce pass. The chunk text is sent as
     a ``cache_control: ephemeral`` system block so subsequent variants of
     the same book pay ~10% on input within the 5-minute cache window.
  4. Writes the outputs + ``meta.json`` into
     ``BookApp/Resources/SeedBooks/<slug>/``.

The Anthropic API key is read from the macOS Keychain at runtime
(``security find-generic-password -s com.bookapp.app -a anthropic_api_key
-w``) so it never appears in the script or in any log line.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from pathlib import Path
from zipfile import ZipFile

import requests

ROOT = Path(__file__).resolve().parent.parent
OUT_ROOT = ROOT / "BookApp" / "Resources" / "SeedBooks"
DOWNLOADS = Path.home() / "Downloads"

ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2023-06-01"

# Tier-1 default rate limit on the Anthropic API: 30K input tokens / minute.
# We track tokens spent in a sliding 60s window and sleep before each call so
# the cumulative load stays under that ceiling.
INPUT_TOKEN_LIMIT_PER_MIN = 30_000
RATE_WINDOW_SECONDS = 60
_token_log: list[tuple[float, int]] = []  # (timestamp, tokens)


def _tokens_in_window(now: float) -> int:
    cutoff = now - RATE_WINDOW_SECONDS
    while _token_log and _token_log[0][0] < cutoff:
        _token_log.pop(0)
    return sum(t for _, t in _token_log)


def throttle_for(estimated_tokens: int) -> None:
    while True:
        now = time.time()
        used = _tokens_in_window(now)
        if used + estimated_tokens <= INPUT_TOKEN_LIMIT_PER_MIN:
            return
        # Wait until the oldest entry rolls off the window.
        if _token_log:
            sleep_for = max(1.0, (_token_log[0][0] + RATE_WINDOW_SECONDS) - now)
        else:
            sleep_for = 5.0
        print(f"    [throttle] {used}/{INPUT_TOKEN_LIMIT_PER_MIN} tok in window, sleeping {sleep_for:.0f}s", flush=True)
        time.sleep(sleep_for)


def record_tokens(tokens: int) -> None:
    _token_log.append((time.time(), tokens))

PRICES = {
    "claude-sonnet-4-6": (3.0, 15.0),
    "claude-opus-4-7":   (15.0, 75.0),
    "claude-haiku-4-5":  (1.0, 5.0),
}


# ---------------------------------------------------------------------------
# Keychain
# ---------------------------------------------------------------------------

def get_key() -> str:
    out = subprocess.run(
        ["security", "find-generic-password",
         "-s", "com.bookapp.app", "-a", "anthropic_api_key", "-w"],
        capture_output=True, text=True, check=True,
    )
    return out.stdout.strip()


# ---------------------------------------------------------------------------
# EPUB → text  (mirrors EPUBParser.swift exactly)
# ---------------------------------------------------------------------------

ENTITIES = {
    "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
    "&quot;": '"', "&apos;": "'", "&#39;": "'", "&mdash;": "—",
    "&ndash;": "–", "&hellip;": "…",
    "&ldquo;": "“", "&rdquo;": "”",
    "&lsquo;": "‘", "&rsquo;": "’",
}

BLOCK_TAGS_CLOSE = [
    "</p>", "</div>", "</section>",
    "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>",
    "</li>", "</blockquote>",
]


def html_to_plain(s: str) -> str:
    s = re.sub(r"<script[\s\S]*?</script>", "", s, flags=re.I)
    s = re.sub(r"<style[\s\S]*?</style>", "", s, flags=re.I)
    s = re.sub(r"<head[\s\S]*?</head>", "", s, flags=re.I)
    for tag in BLOCK_TAGS_CLOSE:
        s = re.sub(re.escape(tag), "\n\n", s, flags=re.I)
    s = re.sub(r"<br[^>]*>", " ", s)
    s = re.sub(r"<[^>]+>", "", s)
    for k, v in ENTITIES.items():
        s = s.replace(k, v)
    s = re.sub(r"&#(\d+);", lambda m: chr(int(m.group(1))), s)
    s = re.sub(r"[ \t]+", " ", s)
    s = re.sub(r" *\n *", "\n", s)
    s = re.sub(r"\n{3,}", "\n\n", s)
    s = merge_fragmented_paragraphs(s)
    return s.strip()


def merge_fragmented_paragraphs(text: str) -> str:
    """Project Gutenberg HTML often wraps every visual line in its own
    ``<p>``, which becomes per-line "paragraphs" after the `</p>` → \\n\\n
    rewrite. Stitch a paragraph back together until it ends with proper
    sentence-terminating punctuation."""
    parts = text.split("\n\n")
    if len(parts) <= 1:
        return text
    terminals = set('.!?:”"…\'’)')
    out: list[str] = []
    buffer = ""
    for part in parts:
        trimmed = part.strip()
        if not trimmed:
            continue
        if trimmed.startswith("# "):
            if buffer:
                out.append(buffer)
                buffer = ""
            out.append(trimmed)
            continue
        buffer = trimmed if not buffer else f"{buffer} {trimmed}"
        if buffer and buffer[-1] in terminals and len(buffer) > 40:
            out.append(buffer)
            buffer = ""
    if buffer:
        out.append(buffer)
    return "\n\n".join(out)


def extract_chapter(html_str: str) -> tuple[str | None, str]:
    m = re.search(r"<h([1-3])[^>]*>([\s\S]*?)</h\1>", html_str, flags=re.I)
    heading = None
    body_html = html_str
    if m:
        cleaned = html_to_plain(m.group(2)).replace("\n", " ").strip()
        if cleaned and len(cleaned) <= 120:
            heading = cleaned
            body_html = html_str.replace(m.group(0), "")
    body = html_to_plain(body_html)
    if heading:
        norm = "".join(heading.lower().split())
        paras = body.split("\n\n")
        if paras and "".join(paras[0].lower().split()) == norm:
            body = "\n\n".join(paras[1:])
    return heading, body


def looks_like_boilerplate(text: str) -> bool:
    head = text[:800].lower()
    signals = [
        "project gutenberg",
        "this ebook is for the use of anyone",
        "you may copy it, give it away or re-use",
        "start of the project gutenberg ebook",
        "end of the project gutenberg ebook",
        "produced by",
        "transcriber's note",
    ]
    return sum(1 for s in signals if s in head) >= 2


def epub_to_text(epub_path: Path) -> tuple[str, dict]:
    with ZipFile(epub_path) as z:
        container = z.read("META-INF/container.xml").decode("utf-8")
        m = re.search(r'full-path=["\'](.+?)["\']', container)
        opf_path = m.group(1)
        opf_data = z.read(opf_path).decode("utf-8")

        meta: dict = {"title": "", "author": "", "language": "en"}
        for tag in ("dc:title", "dc:creator", "dc:language"):
            m2 = re.search(rf"<{tag}[^>]*>([^<]+)</{tag}>", opf_data)
            if m2:
                key = {"dc:title": "title", "dc:creator": "author",
                       "dc:language": "language"}[tag]
                meta[key] = m2.group(1).strip()

        manifest: dict[str, str] = {}
        for m in re.finditer(r"<item\s+([^>]+)/?>", opf_data):
            attrs = dict(re.findall(r"(\w+)=[\"']([^\"']*)[\"']", m.group(1)))
            if "id" in attrs and "href" in attrs:
                manifest[attrs["id"]] = attrs["href"]

        spine: list[str] = []
        for m in re.finditer(r"<itemref\s+idref=[\"']([^\"']+)[\"']", opf_data):
            href = manifest.get(m.group(1))
            if href:
                spine.append(href)

        cover_href = None
        cm = re.search(
            r'<meta[^>]*name=["\']cover["\'][^>]*content=["\']([^"\']+)',
            opf_data,
        )
        if cm:
            cover_href = manifest.get(cm.group(1))

        opf_dir = "/".join(opf_path.split("/")[:-1])
        def resolve(href: str) -> str:
            return f"{opf_dir}/{href}" if opf_dir else href

        cover_data = None
        if cover_href:
            try:
                cover_data = z.read(resolve(cover_href))
            except KeyError:
                cover_data = None

        chapters_text: list[str] = []
        for href in spine:
            try:
                raw = z.read(resolve(href))
            except KeyError:
                continue
            try:
                html_str = raw.decode("utf-8")
            except UnicodeDecodeError:
                html_str = raw.decode("latin-1", errors="replace")
            heading, body = extract_chapter(html_str)
            if len(body.split()) < 20:
                continue
            if looks_like_boilerplate(body):
                continue
            # Only emit a `# Heading` marker if we actually found a real heading
            # in the HTML. Otherwise emit the body as-is — the body's first
            # sentence often serves as a natural opening, and filename-style
            # spine hrefs (`1232-h-1.htm`, hash-prefixed slugs) make terrible
            # chapter titles.
            if heading:
                chapters_text.append(f"# {heading}\n\n{body}")
            else:
                chapters_text.append(body)

        full = "\n\n".join(chapters_text)
        meta["cover_data"] = cover_data
        meta["word_count"] = len(full.split())
    return full, meta


# ---------------------------------------------------------------------------
# Chunker (mirrors Chunker.swift)
# ---------------------------------------------------------------------------

CHAPTER_RE = re.compile(
    r"(?m)^(?:Chapter\s+\d+|CHAPTER\s+[A-Z]+|Part\s+\d+|PART\s+[A-Z]+|\d{1,3}\.|# .+)\s*$"
)


def token_estimate(s: str) -> int:
    return max(1, len(s) // 4)


def split_blocks(text: str) -> list[str]:
    matches = list(CHAPTER_RE.finditer(text))
    if not matches:
        paras = text.split("\n\n")
        if len(paras) <= 1:
            return [text]
        out, buf = [], []
        for p in paras:
            buf.append(p)
            if len(buf) >= 5:
                out.append("\n\n".join(buf))
                buf = []
        if buf:
            out.append("\n\n".join(buf))
        return out
    blocks: list[str] = []
    last = 0
    for m in matches:
        if m.start() > last:
            blocks.append(text[last:m.start()])
        last = m.start()
    blocks.append(text[last:])
    return blocks


def chunk(text: str, max_tokens: int = 80_000, overlap_tokens: int = 4_000) -> list[str]:
    if not text:
        return []
    chars_per_tok = 4
    overlap_chars = overlap_tokens * chars_per_tok
    blocks: list[str] = []
    for raw in split_blocks(text):
        if token_estimate(raw) <= max_tokens:
            blocks.append(raw)
        else:
            i, mc = 0, max_tokens * chars_per_tok
            while i < len(raw):
                blocks.append(raw[i:i + mc])
                i += mc
    out: list[str] = []
    current = ""
    for b in blocks:
        if not current:
            current = b
            continue
        if token_estimate(current) + token_estimate(b) <= max_tokens:
            current += b
        else:
            out.append(current)
            tail = current[-overlap_chars:] if overlap_chars else ""
            current = tail + b
    if current:
        out.append(current)
    return out


# ---------------------------------------------------------------------------
# Anthropic
# ---------------------------------------------------------------------------

class ContentBlockedError(RuntimeError):
    """Anthropic content-filter / bad-request error. Recoverable per chunk."""


def call_claude(api_key: str, model: str, system_blocks: list[dict],
                user_prompt: str, max_tokens: int,
                temperature: float = 0.4,
                estimated_input_tokens: int = 0) -> dict:
    body: dict = {
        "model": model,
        "max_tokens": max_tokens,
        "system": system_blocks,
        "messages": [{"role": "user", "content": user_prompt}],
    }
    # Opus 4.7 deprecates the `temperature` knob in favour of internal sampling.
    if not model.startswith("claude-opus-4-7"):
        body["temperature"] = temperature
    headers = {
        "content-type": "application/json",
        "x-api-key": api_key,
        "anthropic-version": ANTHROPIC_VERSION,
    }
    throttle_for(estimated_input_tokens)
    last_err: Exception | None = None
    for attempt in range(8):
        try:
            r = requests.post(ANTHROPIC_URL, json=body, headers=headers, timeout=900)
        except requests.exceptions.RequestException as e:
            last_err = e
            time.sleep(5 * (attempt + 1))
            continue
        if r.status_code == 429:
            # Honour Anthropic's reset header if present.
            wait = 30
            reset = r.headers.get("anthropic-ratelimit-input-tokens-reset")
            if reset:
                try:
                    # ISO timestamp; compute seconds until then.
                    from datetime import datetime, timezone
                    target = datetime.fromisoformat(reset.replace("Z", "+00:00"))
                    wait = max(2.0, (target - datetime.now(timezone.utc)).total_seconds() + 1)
                except Exception:
                    pass
            retry_after = r.headers.get("retry-after")
            if retry_after:
                try: wait = max(wait, float(retry_after))
                except Exception: pass
            print(f"    [429] rate limited; waiting {wait:.0f}s", flush=True)
            time.sleep(wait)
            continue
        if r.status_code >= 500:
            last_err = RuntimeError(f"HTTP {r.status_code}: {r.text[:200]}")
            time.sleep(5 * (attempt + 1))
            continue
        if r.status_code == 400:
            # Bad-request errors (incl. content-filter blocks) shouldn't kill
            # the whole run — surface them as a recoverable error so the
            # caller can skip this chunk / variant and continue.
            raise ContentBlockedError(f"HTTP 400: {r.text[:300]}")
        if not r.ok:
            raise RuntimeError(f"HTTP {r.status_code}: {r.text[:500]}")
        # Record actual tokens used for the sliding window.
        usage = r.json().get("usage", {})
        actual_in = usage.get("input_tokens", 0) + usage.get("cache_creation_input_tokens", 0)
        record_tokens(actual_in)
        return r.json()
    raise last_err or RuntimeError("retries exhausted")


def transform_chunks(api_key: str, chunks_: list[str], model: str,
                     directive_system: str,
                     target_ratio: float) -> tuple[str, dict]:
    outputs: list[str] = []
    in_tok = out_tok = cached_tok = 0
    for i, c in enumerate(chunks_, 1):
        # Cached-first ordering: chunk text is the cached prefix; the
        # variant directive comes after, so caching hits across variants.
        system = [
            {"type": "text", "text": c, "cache_control": {"type": "ephemeral"}},
            {"type": "text", "text": directive_system + f"\n\nThis is chunk {i} of {len(chunks_)}."},
        ]
        user = "Please transform the passage in the system prompt according to the directives. Output only the rewritten prose."
        out_budget = max(1024, min(16_000, int(token_estimate(c) * target_ratio * 1.4)))
        print(f"    chunk {i}/{len(chunks_)}  in≈{token_estimate(c)//1000}k tok  max_out={out_budget}", flush=True)
        try:
            resp = call_claude(api_key, model, system, user, out_budget,
                               estimated_input_tokens=token_estimate(c))
        except ContentBlockedError as e:
            # Retry once on Haiku 4.5 — different filter behaviour, often
            # passes academic content the bigger models reject.
            print(f"    [content-block] {e}\n    retrying on claude-haiku-4-5", flush=True)
            try:
                resp = call_claude(api_key, "claude-haiku-4-5-20251001",
                                   system, user, out_budget,
                                   estimated_input_tokens=token_estimate(c))
            except Exception as e2:
                # Last resort: leave the chunk verbatim so the variant still
                # has body text and the cost report stays honest.
                print(f"    [skipped] keeping source verbatim: {e2}", flush=True)
                outputs.append(c)
                continue
        text = "".join(b["text"] for b in resp["content"] if b["type"] == "text")
        usage = resp.get("usage", {})
        in_tok += usage.get("input_tokens", 0)
        out_tok += usage.get("output_tokens", 0)
        cached_tok += usage.get("cache_read_input_tokens", 0)
        outputs.append(text)

    if len(outputs) > 1:
        for i in range(len(outputs) - 1):
            left = outputs[i]
            right = outputs[i + 1]
            tail = left[-2000:]
            head = right[:2000]
            sys_seam = [{
                "type": "text",
                "text": ("You are joining two adjacent passages from a transformed book. "
                         "Rewrite the last paragraph of the first passage and the first "
                         "paragraph of the second so they flow continuously, preserving "
                         "every idea from both. Reply as JSON: {\"left\": \"...\", \"right\": \"...\"}."),
            }]
            usr = f"PASSAGE A (end):\n{tail}\n\nPASSAGE B (start):\n{head}"
            resp = call_claude(api_key, model, sys_seam, usr, 2048,
                               temperature=0.3,
                               estimated_input_tokens=2_500)
            text = "".join(b["text"] for b in resp["content"] if b["type"] == "text")
            usage = resp.get("usage", {})
            in_tok += usage.get("input_tokens", 0)
            out_tok += usage.get("output_tokens", 0)
            cached_tok += usage.get("cache_read_input_tokens", 0)
            try:
                j = json.loads(text)
                outputs[i] = left[:-len(tail)] + j["left"]
                outputs[i + 1] = j["right"] + right[len(head):]
            except Exception:
                pass

    merged = "\n\n".join(outputs).strip()
    return merged, {
        "input_tokens": in_tok,
        "output_tokens": out_tok,
        "cache_read_input_tokens": cached_tok,
    }


def usage_cost(usage: dict, model: str) -> float:
    inp, outp = PRICES[model]
    return (
        usage.get("input_tokens", 0) * inp
        + usage.get("cache_read_input_tokens", 0) * inp * 0.10
        + usage.get("output_tokens", 0) * outp
    ) / 1_000_000


# ---------------------------------------------------------------------------
# Books config
# ---------------------------------------------------------------------------

BOOKS = [
    {
        "slug": "republic-plato",
        "epub": DOWNLOADS / "pg1497-images-3.epub",
        "title_override": "The Republic",
        "author_override": "Plato",
        "categories": ["Philosophy"],
        "themes": ["justice", "ideal state", "education", "the soul", "rulers"],
        "variants": [
            {"name": "compressed-25", "kind": "compressed",
             "target_pages": 25, "model": "claude-sonnet-4-6"},
            {"name": "compressed-75", "kind": "compressed",
             "target_pages": 75, "model": "claude-sonnet-4-6"},
            {"name": "restyled-gladwell", "kind": "styled",
             "target_pages": 75, "style": "Malcolm Gladwell",
             "model": "claude-opus-4-7"},
        ],
    },
    {
        "slug": "prince-machiavelli",
        "epub": DOWNLOADS / "pg1232-images-3.epub",
        "title_override": "The Prince",
        "author_override": "Niccolò Machiavelli",
        "categories": ["Philosophy", "Politics"],
        "themes": ["power", "statecraft", "fortune", "virtue", "leadership"],
        "variants": [
            {"name": "compressed-10", "kind": "compressed",
             "target_pages": 10, "model": "claude-sonnet-4-6"},
            {"name": "compressed-30", "kind": "compressed",
             "target_pages": 30, "model": "claude-sonnet-4-6"},
            {"name": "restyled-harari", "kind": "styled",
             "target_pages": 25, "style": "Yuval Noah Harari",
             "model": "claude-opus-4-7"},
        ],
    },
    {
        "slug": "beyond-good-evil-nietzsche",
        "epub": DOWNLOADS / "pg4363-images-3.epub",
        "title_override": "Beyond Good and Evil",
        "author_override": "Friedrich Nietzsche",
        "categories": ["Philosophy"],
        "themes": ["morality", "the will to power", "truth",
                   "religion", "self-overcoming"],
        "variants": [
            {"name": "compressed-20", "kind": "compressed",
             "target_pages": 20, "model": "claude-sonnet-4-6"},
            {"name": "compressed-60", "kind": "compressed",
             "target_pages": 60, "model": "claude-sonnet-4-6"},
            {"name": "restyled-didion", "kind": "styled",
             "target_pages": 50, "style": "Joan Didion",
             "model": "claude-opus-4-7"},
        ],
    },
]


ACADEMIC_PREAMBLE = (
    "The passage above is from a canonical public-domain philosophical work "
    "studied in university curricula. You are producing a faithful academic "
    "summary or restyled version for an educational reading app — the user "
    "owns the source and is studying it. Render the author's argument "
    "accurately even when it engages with controversial historical themes "
    "(power, religion, morality, etc.); attribute ideas to the author rather "
    "than endorsing or condemning them. "
)


def directive(variant: dict, source_pages: int) -> str:
    target = variant["target_pages"]
    ratio = target / max(1, source_pages)
    if variant["kind"] == "compressed":
        return ACADEMIC_PREAMBLE + (
            f"Rewrite the passage above as a faithful compression to about "
            f"{int(ratio * 100)}% of its source length. Output should aim for "
            f"about {target} printed-page-equivalents for the whole book once "
            "every chunk is combined. Preserve the author's voice, the structure, "
            "and every key argument. Output only the rewritten prose — no commentary, "
            "no chunk markers, no preamble. Keep paragraph breaks. Keep `# Heading` "
            "lines that mark chapter starts."
        )
    if variant["kind"] == "styled":
        return ACADEMIC_PREAMBLE + (
            f"Rewrite the passage above in the style of {variant['style']} while "
            "preserving every key idea, argument, and structural beat from the source. "
            f"Match {variant['style']}'s sentence rhythm, vocabulary register, and "
            "rhetorical moves. Compress to about "
            f"{int(ratio * 100)}% of the source length. Output only the rewritten prose. "
            "Keep paragraph breaks. Keep `# Heading` lines that mark chapter starts. "
            "No commentary."
        )
    raise ValueError(variant["kind"])


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(only_slug: str | None = None) -> None:
    api_key = get_key()
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    grand = 0.0
    for book in BOOKS:
        if only_slug and book["slug"] != only_slug:
            continue
        print(f"\n=== {book['title_override']} ({book['slug']}) ===", flush=True)
        out_dir = OUT_ROOT / book["slug"]
        out_dir.mkdir(parents=True, exist_ok=True)

        # Bundle the original EPUB next to the variants.
        if not (out_dir / "original.epub").exists():
            (out_dir / "original.epub").write_bytes(book["epub"].read_bytes())

        # Extract once.
        text, meta_ex = epub_to_text(book["epub"])
        title = book.get("title_override") or meta_ex["title"]
        author = book.get("author_override") or meta_ex["author"]
        source_pages = max(1, meta_ex["word_count"] // 250)
        print(f"  parsed: words={meta_ex['word_count']}, est_pages={source_pages}", flush=True)

        if meta_ex.get("cover_data"):
            (out_dir / "cover.jpg").write_bytes(meta_ex["cover_data"])

        # Use 25K-token chunks for the seeding pipeline so each request fits
        # comfortably under the tier-1 30K input-tokens-per-minute rate limit.
        chunks_ = chunk(text, max_tokens=25_000, overlap_tokens=2_000)
        print(f"  chunks: {len(chunks_)} (capped at 25K tokens for rate-limit fit)", flush=True)

        meta_out: dict = {
            "slug": book["slug"],
            "title": title,
            "author": author,
            "language": meta_ex.get("language", "en"),
            "categories": book["categories"],
            "themes": book["themes"],
            "source_words": meta_ex["word_count"],
            "source_pages_est": source_pages,
            "variants": [],
        }

        for v in book["variants"]:
            out_path = out_dir / f"{v['name']}.txt"
            if out_path.exists():
                print(f"\n  ✓ {v['name']}  already exists — skipping", flush=True)
                meta_out["variants"].append({
                    "file": f"{v['name']}.txt",
                    "kind": v["kind"],
                    "target_pages": v["target_pages"],
                    "style_reference": v.get("style", ""),
                    "model": v["model"],
                    "skipped_existing": True,
                })
                continue

            print(f"\n  → {v['name']}  model={v['model']}  target={v['target_pages']}p", flush=True)
            target_ratio = v["target_pages"] / source_pages
            d = directive(v, source_pages)
            t0 = time.time()
            out_text, usage = transform_chunks(
                api_key, chunks_, v["model"], d, target_ratio
            )
            dt = time.time() - t0
            cost = usage_cost(usage, v["model"])
            grand += cost
            out_path.write_text(out_text, encoding="utf-8")
            print(
                f"    done in {dt:.0f}s  words={len(out_text.split())}  "
                f"in={usage['input_tokens']}  cached_in={usage['cache_read_input_tokens']}  "
                f"out={usage['output_tokens']}  cost=${cost:.3f}",
                flush=True,
            )
            meta_out["variants"].append({
                "file": f"{v['name']}.txt",
                "kind": v["kind"],
                "target_pages": v["target_pages"],
                "style_reference": v.get("style", ""),
                "model": v["model"],
                "input_tokens": usage["input_tokens"],
                "cached_input_tokens": usage["cache_read_input_tokens"],
                "output_tokens": usage["output_tokens"],
                "cost_usd": round(cost, 4),
            })

        (out_dir / "meta.json").write_text(json.dumps(meta_out, indent=2), encoding="utf-8")

    print(f"\n=== total cost: ${grand:.2f} ===", flush=True)


if __name__ == "__main__":
    only = sys.argv[1] if len(sys.argv) > 1 else None
    main(only)
