# Harness Demo — Crime and Punishment

A worked example proving out [`scripts/mid-book-eval.py`](../../../scripts/mid-book-eval.py)
end to end, using two hand-written candidate summaries to show the harness actually
discriminates a "forgot the middle" failure from a summary that preserves it.

## Methodology note (read this before trusting the numbers)

This sandbox has no Anthropic API key configured, so the harness's two LLM-backed steps
(`facts`, `score`) could not be run as live HTTP calls here. To still validate the harness
for real rather than only on paper:

1. **Source text is real and public domain.** Crime and Punishment (Dostoevsky, d. 1881) was
   downloaded in full from Project Gutenberg (`pg2554.txt`) and run through the harness's actual
   `split_thirds()` — first/middle/last thirds came out to 413,145 / 364,825 / 357,138 characters,
   and the middle third's first line was, correctly, `PART III / CHAPTER I` — right where the
   `human-fulltext/crime-and-punishment.md` benchmark says the dropped threads (Svidrigailov,
   Porfiry, Luzhin's frame-up) live.
2. **`facts.json` facts are text-grounded, not invented.** Each was pulled from real excerpts
   sampled at the midpoint of its third (verified against the downloaded text) or cross-checked
   against the already-researched `human-fulltext/crime-and-punishment.md` for the rouble figures.
3. **`recall-*.json` scoring was done by Claude directly** (acting as the judge the `score`
   subcommand would otherwise call over the API), applying the same 0/0.5/1 rubric the harness's
   prompt specifies.
4. **The gap computation and report table are real code, not arithmetic done by hand** — see the
   actual terminal output below, produced by running:
   `python3 scripts/mid-book-eval.py report research/summary-eval/mid-book-eval-demo/recall-naive.json`
   (and the `-good.json` counterpart).

Once a real `ANTHROPIC_API_KEY` (or macOS Keychain entry) is available, steps 2–3 should be
re-run live via `mid-book-eval.py facts` / `score` — this demo validates the harness's logic and
plumbing, not that live model output will reproduce these exact numbers.

## The two candidate summaries

- [`naive-ai-summary.md`](./naive-ai-summary.md) — deliberately written in the classic
  lost-in-the-middle shape: explicit, specific coverage of the opening (murder, Marmeladov,
  the mother's letter) and the ending (confession, Siberia, the epilogue dream), but the entire
  middle collapses into one vague paragraph ("a series of increasingly tense encounters...
  old acquaintances resurface, family tensions escalate") with zero named entities.
- [`good-summary.md`](./good-summary.md) — covers the same opening and ending, but gives the
  middle its own paragraph naming the three parallel threads (Svidrigailov's ghost/wall-listening,
  Porfiry's interrogation, Luzhin's frame-up of Sonya) with the specific figures (100, 10,000,
  3,000 roubles) that make them checkable.

## Real output

```
############ NAIVE (beginning/end-heavy) SUMMARY ############
Third     N facts   Recall
first     5         0.70
middle    5         0.10
last      5         0.60

positional_recall_gap = 0.15  (threshold 0.7)
VERDICT: FAIL — summary likely forgot the middle
exit=1

############ GOOD (thread-preserving) SUMMARY ############
Third     N facts   Recall
first     5         1.00
middle    5         1.00
last      5         1.00

positional_recall_gap = 1.00  (threshold 0.7)
VERDICT: PASS
exit=0
```

Note the naive summary's bookends aren't even perfect (0.70 / 0.60 — the police-summons detail
and the Svidrigailov ordeal in the mother's letter got smoothed away too) — but the middle craters
to 0.10, an order of magnitude below either bookend. That's the exact signature
`mid-book-fidelity.md` predicts: positional bias doesn't wait for the middle to be the *only*
casualty, it's just the worst one, consistently.

## Reproducing this

```
python3 scripts/mid-book-eval.py report research/summary-eval/mid-book-eval-demo/recall-naive.json
python3 scripts/mid-book-eval.py report research/summary-eval/mid-book-eval-demo/recall-good.json
```

To run the full live pipeline against a new book/summary pair (requires `ANTHROPIC_API_KEY` or
the Keychain entry `seed-transform.py` uses):

```
python3 scripts/mid-book-eval.py run path/to/book.txt path/to/summary.md --out-dir out/
```
