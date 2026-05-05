#!/usr/bin/env python3
"""seed-learnings.py — generate the bundled key-learnings for BookApp.

For each book in BookApp/Resources/SeedBooks/<slug>/, extracts ~40K chars
of the EPUB body, calls Claude Sonnet 4.6 with the same prompt the app's
`ExtractionEngine` uses, and saves 8-12 key learnings as `learnings.json`.

`SeedBooksLoader` reads the file on first launch and creates `KeyLearning`
rows linked to each Book.

Cost: ~$0.05 per book on Sonnet 4.6 (10K input × $3/M + 1K output × $15/M).

Run:  python3 scripts/seed-learnings.py [optional-slug]
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

# Reuse the EPUB extractor + Claude call helpers from the sibling script.
import importlib.machinery
seed = importlib.machinery.SourceFileLoader(
    "seed_transform", str(Path(__file__).resolve().parent / "seed-transform.py")
).load_module()


SYSTEM_PROMPT = (
    "Extract 10 key learnings from the book provided.\n"
    "Each learning is one or two crisp sentences capturing an idea the reader "
    "should retain.\n"
    "Reply as JSON array: [{\"text\": \"...\", \"chapter\": \"...\"}, ...]\n"
    "Prefer concrete, actionable points over high-level platitudes. "
    "JSON only — no commentary, no preamble."
)


def main(only: str | None = None) -> None:
    api_key = seed.get_key()
    grand_cost = 0.0

    for book in seed.BOOKS:
        if only and book["slug"] != only:
            continue
        out_dir = seed.OUT_ROOT / book["slug"]
        out_path = out_dir / "learnings.json"
        if out_path.exists():
            print(f"✓ {book['slug']}  learnings already exist — skipping", flush=True)
            continue
        if not (out_dir / "original.epub").exists():
            print(f"⨯ {book['slug']}  no original.epub — skipping", flush=True)
            continue

        print(f"\n=== {book['title_override']} ===", flush=True)
        text, _ = seed.epub_to_text(out_dir / "original.epub")
        sample = text[:40_000]
        print(f"  sample: {len(sample)} chars (~{seed.token_estimate(sample)} tokens)", flush=True)

        system_blocks = [
            {"type": "text", "text": SYSTEM_PROMPT},
        ]
        user = (
            f"Title: {book['title_override']}\n"
            f"Author: {book['author_override']}\n\n"
            f"Book content:\n{sample}"
        )

        try:
            resp = seed.call_claude(
                api_key=api_key,
                model="claude-sonnet-4-6",
                system_blocks=system_blocks,
                user_prompt=user,
                max_tokens=2_000,
                temperature=0.3,
                estimated_input_tokens=seed.token_estimate(sample) + 200,
            )
        except Exception as e:
            print(f"  ⨯ generation failed: {e}", flush=True)
            continue

        text_out = "".join(b["text"] for b in resp["content"] if b["type"] == "text")
        usage = resp.get("usage", {})
        cost = seed.usage_cost(usage, "claude-sonnet-4-6")
        grand_cost += cost

        # Be lenient with the model: strip code-fence wrapping if present.
        cleaned = text_out.strip()
        if cleaned.startswith("```"):
            cleaned = cleaned.split("```", 2)[1]
            if cleaned.startswith("json"):
                cleaned = cleaned[4:]
            cleaned = cleaned.strip().rstrip("`").strip()
        try:
            items = json.loads(cleaned)
            assert isinstance(items, list)
        except Exception as e:
            print(f"  ⨯ couldn't parse JSON: {e}", flush=True)
            (out_dir / "learnings-raw.txt").write_text(text_out, encoding="utf-8")
            continue

        # Normalise: keep only `text` and `chapter` keys.
        normalised = []
        for it in items:
            if not isinstance(it, dict): continue
            text_v = it.get("text") or it.get("learning") or ""
            chap_v = it.get("chapter") or it.get("section") or ""
            if isinstance(text_v, str) and text_v.strip():
                normalised.append({
                    "text": text_v.strip(),
                    "chapter": chap_v.strip() if isinstance(chap_v, str) else "",
                })

        out_path.write_text(json.dumps(normalised, indent=2), encoding="utf-8")
        print(f"  ✓ wrote {len(normalised)} learnings  cost=${cost:.3f}", flush=True)

    print(f"\n=== total cost: ${grand_cost:.3f} ===", flush=True)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
