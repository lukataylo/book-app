# AI-Generated Prose: Tell-Tale Signs and How to Avoid Them

A reference for detecting and eliminating AI-sounding language in nonfiction/explanatory writing, specifically book summaries. Compiled from editor writeups, style guides, and peer-reviewed detection research.

---

## 1. Lexical Tells

### 1.1 The Core Word-List

A 2025 *Science Advances* study examined 15+ million PubMed abstracts (2010–2024) and identified "focal words" that spiked abruptly after ChatGPT's release, with at least 13.5% of 2024 biomedical abstracts showing LLM fingerprints—up to 40% in some journals.[^1] The highest-signal offenders, with approximate frequency multipliers vs. pre-2022 baselines:

| Word / phrase | Signal strength |
|---|---|
| `delve` / `delves` / `delving` | ~28× above baseline[^1] |
| `vibrant tapestry` | ~17,000× above baseline[^2] |
| `in the ever-evolving` | ~11,000× above baseline[^2] |
| `intricate nature` | ~6,000× above baseline[^2] |
| `serves as a testament` | ~4,000× above baseline[^2] |
| `important to note` / `it's worth noting` | ~3,000× above baseline[^2] |
| `underscore` / `underscores` | very high |
| `meticulous` / `meticulously` | very high |
| `pivotal` | very high |
| `realm` | very high |
| `landscape` (metaphorical) | very high |
| `robust` | very high |
| `seamless` / `seamlessly` | very high |
| `transformative` | very high |
| `groundbreaking` | very high |
| `navigate` / `navigate the complexities` | very high |
| `boasts` | very high |
| `crucial` | high |
| `comprehensive` | high |
| `foster` / `fostering` | high |
| `elevate` | high |
| `showcase` / `showcasing` | high |
| `leverage` / `harness` / `unlock` | high |
| `align` / `aligns with` | high |
| `illuminate` | high |
| `garnered` | high |
| `nuanced` | high |

**Concrete examples of the problem:**

- "This book *delves* into the *intricate* relationship between memory and identity, *underscoring* the *pivotal* role that trauma plays in shaping the human psyche." — Every italicized word is a flag.
- "In *today's fast-paced world*, navigating the *complexities* of modern leadership has become *crucial*." — Three flags in eighteen words.
- "The author *meticulously* weaves a *tapestry* of evidence, *showcasing* the *transformative* power of small habits." — Four flags.

### 1.2 How Flags Cluster

The tells are not just individual words—they appear in dense clusters. A practiced reader recognizes the *texture*: a single sentence will contain two or three of these words simultaneously. Pangram Labs documented that if a word or phrase appears more than 3× more frequently in AI output than in natural human writing, it reliably flags machine-generated content.[^2] When three or four such words appear in one sentence, the probability of AI origin approaches certainty.

### 1.3 Model-Specific Vocabulary

- **ChatGPT / GPT-4-series:** heavy on `delve`, `robust`, `pivotal`, `certainly!`, `absolutely!`
- **Claude:** heavier on `notably`, `it's worth noting`, longer clausal sentences, more hedging
- **Gemini:** verbose flatness, `impressively`, `let me know`[^3]

---

## 2. Structural Tells

### 2.1 Formulaic Openings and Closings

AI defaults to a five-paragraph essay shape regardless of the topic—introduction, three body sections, recap—and applies it at every scale.[^4]

**Opening formulas to avoid:**
- "In today's fast-paced world, [topic] has become more important than ever."
- "In an era defined by [buzzword], [author] offers a compelling exploration of..."
- "At its core, this book is about..."
- "When it comes to [topic], [author] [verb phrase]..."

**Closing formulas to avoid:**
- Starting the final paragraph with "Overall," "In conclusion," "In summary," or "Ultimately"
- A conclusion that merely repeats the introduction in slightly different words
- An aphoristic pull-quote sentence designed to feel wise: "At the end of the day, the real discovery is ourselves."

### 2.2 The "Not Just X, It's Y" Cadence

The Wikipedia AI-writing signals guide and multiple editor analyses identify the negated contrast as the single most diagnostic rhetorical move in AI text.[^4][^5]

**Patterns:**
- "It's not just X — it's Y."
- "This isn't about X. It's about Y."
- "Not only does [author] X, but also Y."
- "Not X. Not Y. Just Z."
- "The result? Devastating." (self-answered rhetorical question)

**Why it sounds AI:** These constructions mimic insight by framing a restatement as a revelation. The second half of the sentence is not actually more profound than the first—it's just the same idea restated with inflated language.

**Example:** "This book isn't just about productivity — it's about reclaiming your life." vs. the human alternative of simply saying *what the book argues*.

### 2.3 Tricolon Overuse (Rule of Three Everywhere)

LLMs default to triplets because three is the statistical average across training data. The rule of three appears as:[^4][^6]

- "adjective, adjective, adjective" — "Fast, intuitive, and transformative"
- "short phrase, short phrase, and short phrase" — "Dream big. Start small. Scale fast."
- Parallel sentence anaphora — "They could expose… They could offer… They could provide…"
- Section headings that always come in threes
- Three examples always cited, never two or four

**Signal:** If every paragraph ends with a three-item list or every argument is supported by exactly three examples, the tricolon is mechanical, not rhetorical.

### 2.4 Uniform Paragraph and Sentence Lengths

Human writing "bursts"—short sentences interrupt long ones; paragraph lengths vary by function. AI prose maintains a metronomic 14–22 word sentence average with low variance.[^4]

**Flags:**
- Every paragraph is 3–5 sentences long
- Sentence lengths are visually similar across paragraphs
- No single-sentence paragraphs for emphasis; no long flowing 40-word sentences
- "Burstiness" score close to zero (a formal measure used by detectors)

### 2.5 Over-Signposting

AI treats every transition as an opportunity to announce structure:

- "Firstly… Secondly… Finally…"
- "Let's explore…" / "Let's unpack…" / "Let's break this down…"
- "It's important to note that…"
- "That being said…"
- "Moreover," / "Furthermore," / "Additionally," used mechanically every paragraph
- Section summaries at the end of every section that restate what was just said ("In this chapter, we explored…")

**The tell:** No human essayist actually writes "Let's explore" to their reader. The phrase is a model performing helpfulness.

### 2.6 Hedging Stacking

AI layers multiple qualifiers before any claim to avoid being wrong:

> "While this may vary depending on context, generally speaking, in most cases, it's worth noting that this approach can often be considered…"

One hedge may be appropriate. Three or four consecutive hedges signal a model optimizing for inoffensiveness.

### 2.7 Listicle-ification of Prose

- Bullet points appear inside what should be flowing paragraphs
- Every argument is broken into a `**Bold term:** explanation sentence` structure
- Numbered lists appear where no genuine enumeration exists
- Em-dashed inline definitions everywhere

**Signal:** If the piece would look identical in a PowerPoint deck and an essay, it's listicle-in-a-trench-coat.

### 2.8 Symmetrical Balanced Sentences

AI produces artificially balanced clauses because symmetry is statistically rewarded in its training data:

> "Products impress; platforms empower. Products solve problems; platforms create worlds."

Human writers produce asymmetric arguments. If every sentence balances X against Y with the same grammatical weight, the balance is mechanical.

### 2.9 Em-Dash Overuse

The em dash has become a widely recognized AI signature.[^7][^8] AI uses it:
- To attach qualifying segments that belong in commas or parentheses
- At rates of 3–5 per 500 words (vs. 0–1 in most human nonfiction)
- Consistently for the same function, never for dramatic interruption

**Rule of thumb:** One em dash per 300–500 words is human. Three or more per paragraph is almost always AI.

---

## 3. Substance Tells

### 3.1 Vagueness and Generality Instead of Specifics

AI is trained to give answers that fit the widest possible range of prompts. The result is prose that could apply to hundreds of books on the same topic.[^6]

**Flags:**
- No named people (other than the author)
- No specific dates, dollar amounts, percentages, or places
- No named studies, papers, or historical events
- Hypothetical examples ("Imagine a world where…" / "Think of it like a highway…") instead of real ones
- "Researchers argue" / "experts say" / "studies show" with no actual attribution

**Concrete example of the failure:**
> "The author argues that small changes compound over time to produce significant results, illustrating this with numerous examples from business, sports, and everyday life."

That sentence describes approximately forty books. It contains no information specific to *this* book.

**What a human writer does instead:**
> "Clear's argument hinges on a 1% daily improvement calculation he borrows from British Cycling's Dave Brailsford—after a decade, that compounds to 37× improvement. It's a tidy metaphor that sidesteps the awkward question of what counts as 1% in non-athletic domains."

### 3.2 Summary-of-a-Summary Blandness

Book summaries generated by AI tend to describe *that* an argument is made, not *what* the argument is or *why* it matters:

- "The author makes a compelling case for the importance of habit formation."
- "This thought-provoking book challenges conventional wisdom."
- "The key insight is that small changes lead to big results."

These are content-free. They could be generated from a back-cover blurb without reading the book.

**The fix:** State the specific claim, the specific evidence or example used, and a specific implication or counterargument.

### 3.3 No Authorial Voice or Point of View

AI writes to please rather than to argue. The result:[^4][^9]

- No opinion on whether the book's argument is correct
- No friction—weaknesses are mentioned only to be immediately balanced by strengths
- False balance/"both-sides" hedging: "While some may argue X, others contend Y" with no resolution
- Overly positive by default (RLHF optimized for likability)
- No specificity about *who* would find the book useful and *who* would not

**Diagnostic question:** Does the summary have a point of view that could be disagreed with? If not, it has no authorial voice.

### 3.4 Restating the Prompt / Framing Preamble

AI often begins by paraphrasing the question asked before answering it:

> "This book summary covers [Book Title] by [Author], exploring the key themes and central arguments…"

No human editor would write this. A real summary opens *in medias res* with something about the book.

### 3.5 Inflated Significance Claims

AI attaches grandiose framing to ordinary subjects:[^4]

- Minor points become "pivotal moments in the history of…"
- A chapter's anecdote becomes a "profound exploration of the human condition"
- An author's practical advice becomes "a revolutionary paradigm shift"
- Every book "challenges us to rethink everything we thought we knew"

The "serves as a testament" construction is the most compressed form: "This book serves as a testament to the enduring power of human resilience." It asserts significance without demonstrating it.

### 3.6 Conclusions That Only Recap

AI conclusions are particularly formulaic: they restate the book's argument, restate the summary's argument, and close with a universal statement. They add no information not already present in the body.

**Red flag:** If you could read the introduction and conclusion of a summary and feel you have the full picture, the conclusion is a recap.

---

## 4. Punctuation and Formatting Tells

### 4.1 Em-Dash Density

See §2.9. Three or more em dashes per 500 words is a primary signal; they consistently attach explanatory clauses rather than marking dramatic breaks or interruptions.[^7][^8]

### 4.2 Title-Case Headers

AI defaults to Title Case For Every Header Word. Human editors and style guides (AP, Chicago, MLA) use sentence case for subheadings in most contexts. An AI-generated document will have:
- Every H2 and H3 in full Title Case
- Bold-stemmed bullets: `**Key Insight:** explanation sentence.`
- Nested headers for content that doesn't need them

### 4.3 Bold-Everything Emphasis

Mechanical bolding of terms throughout body copy—not limited to the first use or technical definitions, but scattered throughout for visual interest—is a hallmark of AI formatting. Humans use bold sparingly (once, for a defined term) or not at all in flowing prose.

### 4.4 Zero Contractions, No Fragments

AI writes with near-perfect grammar: no contractions (`it's` → `it is`), no sentence fragments, no sentences beginning with `And` or `But`, consistent Oxford commas, zero typos. Human writing contains all of these.[^6]

**Counterintuitive:** Grammatically perfect prose that reads stiffly is often AI. Human experts use fragments for emphasis. Real writers start sentences with conjunctions.

### 4.5 Curly-Quote / Straight-Quote Inconsistency

AI models sometimes mix typographic ("curly") and ASCII ("straight") quotation marks within the same document—a tell of text assembled from multiple generation passes or contexts.[^4]

### 4.6 Emoji in Structural Positions

Using emoji as section markers (✅, 🔑, 💡) in place of proper typography is an AI tell. Human editors use them rarely, never structurally.

### 4.7 Markdown Formatting in Plain-Text Contexts

If a summary delivered as plain prose contains `**bold**`, `*italics*`, `## headers`, or `- bullet` syntax, the text was generated without appropriate post-processing. Humans write for the medium.

---

## 5. Quick-Reference Checklist

Scan any summary for these flags. Three or more in a 200-word passage = likely AI-generated or heavily AI-influenced.

### Lexical

- [ ] Contains `delve`, `delves`, `delving`
- [ ] Contains `tapestry`, `vibrant tapestry`, `rich tapestry`
- [ ] Contains `testament` / `serves as a testament`
- [ ] Contains `realm` (metaphorical)
- [ ] Contains `landscape` (metaphorical)
- [ ] Contains `navigate the complexities` / `navigating`
- [ ] Contains `pivotal` (especially "pivotal role" or "pivotal moment")
- [ ] Contains `underscore` / `underscores`
- [ ] Contains `meticulous` / `meticulously`
- [ ] Contains `robust` (especially "robust framework")
- [ ] Contains `transformative` / `groundbreaking` / `revolutionary`
- [ ] Contains `foster` / `fostering`
- [ ] Contains `in today's fast-paced world` / `in an ever-evolving landscape`
- [ ] Contains `it's worth noting` / `important to note` / `notably`
- [ ] Contains `showcase` / `showcasing`
- [ ] Contains `leverage` / `harness` / `unlock` (metaphorical)
- [ ] Contains `boasts` (used to attribute a positive quality)
- [ ] Contains `crucial` / `paramount` / `essential` used as filler intensifiers
- [ ] Contains `comprehensive` / `nuanced` / `innovative` without specifics behind them
- [ ] Three or more of the above words cluster in one sentence or paragraph

### Structural

- [ ] Opens with a genre-frame sentence ("This book explores…", "In today's world…")
- [ ] Contains "It's not just X, it's Y" or "Not only X, but also Y"
- [ ] Contains self-answered rhetorical question ("The result? Transformation.")
- [ ] Rule-of-three triplets appear in most paragraphs
- [ ] All paragraphs are visually the same length (3–5 sentences each)
- [ ] Sentence lengths have low variance — no very short or very long sentences
- [ ] Contains "Firstly… Secondly… Finally…" or equivalent signposting
- [ ] Contains "Let's explore" / "Let's unpack" / "Let's break this down"
- [ ] Conclusion starts with "Overall," "In conclusion," "In summary," or "Ultimately"
- [ ] Conclusion restates what was already said without adding new synthesis
- [ ] Multiple consecutive hedge-qualifiers before a single claim
- [ ] Lists appear where prose would be natural; every section has a bullet list

### Substance

- [ ] No specific named individuals, dates, dollar amounts, or places from the book
- [ ] Describes *that* an argument exists, not *what* the argument is
- [ ] Could apply to a dozen books in the same genre without changing a word
- [ ] No stated opinion on whether the book's claims are correct
- [ ] Weaknesses mentioned only as a "balanced" gesture, immediately softened
- [ ] Uses hypothetical examples instead of real ones from the text
- [ ] "Researchers argue" / "experts say" / "studies show" with no attribution
- [ ] Every assessment is positive or mildly positive — no friction
- [ ] Closes with a universal human-condition statement

### Punctuation / Format

- [ ] Em-dash count exceeds 1 per 200 words
- [ ] All section headers in Title Case
- [ ] Bold text scattered throughout body copy, not limited to first-use terms
- [ ] No contractions anywhere in the text
- [ ] No sentence fragments used for emphasis
- [ ] Mixed curly/straight quotation marks
- [ ] Emoji used as structure markers
- [ ] Markdown syntax visible in rendered output

---

## 6. Rewrite Heuristics

### H1 — Replace Abstraction with a Specific Detail

**Problem:** "The author illustrates this with compelling examples from history."  
**Fix:** Name the example. Name the person, place, year, number.  
**After:** "Clear's central case study is British Cycling's marginal gains program under Dave Brailsford: staff cleaned bikes with surgical alcohol to save seconds; white bedsheets were packed to spot dust in hotels."

Rule: Every paragraph must have at least one noun a reader could look up.

### H2 — Vary Sentence Length Deliberately

**Problem:** Every sentence runs 16–20 words. The rhythm is a flatline.  
**Fix:** After a long sentence, write a short one. Three words can constitute a sentence. Then let the next sentence run longer, accumulating clauses, before cutting again.  
**After:** "Kahneman spent forty years studying how people reason. They don't, mostly. They confabulate, and fast."

Target: At least one sentence under 8 words and one over 30 words per 200-word passage.

### H3 — Cut Signposting Phrases

**Problem:** "It's important to note that…" / "That being said…" / "Let's explore…"  
**Fix:** Delete the phrase. If the sentence needs it to make sense, restructure.  
**Before:** "It's worth noting that the author's background in psychology informs his approach."  
**After:** "The author is a psychologist, and it shows: his examples lean on decision-theory research, not motivational anecdote."

### H4 — Replace "Not Just X, It's Y" with a Claim

**Problem:** "This book isn't just about habits — it's about identity."  
**Fix:** State the actual relationship between the two ideas.  
**After:** "Clear argues that habits work because they change your self-image; the behavior change is a byproduct, not the goal."

### H5 — Give the Summary a Point of View

**Problem:** Neutral recitation of what the book says with no assessment.  
**Fix:** Take a position — useful for whom, stronger in what way, weaker in what way.  
**After:** "The compounding-habits framework is most convincing in athletics and least convincing in creative work, where the 1% improvement metric has no obvious unit."

This doesn't require being negative. It requires being specific about your assessment.

### H6 — Kill the Generic Intensifiers

**Problem:** `crucial`, `pivotal`, `transformative`, `comprehensive`, `nuanced` appear as hollow decoration.  
**Fix:** Remove them. If the sentence collapses without the adjective, the noun was doing no work either — rewrite the noun phrase.  
**Before:** "This crucial insight transforms how we think about nuanced behavioral change."  
**After:** "If the habit loop is right, willpower campaigns are misdirected: you change the cue and routine, not the desire."

### H7 — Thin the Em Dashes

**Problem:** Em dashes used for every parenthetical.  
**Fix:** Default to commas for parentheticals, parentheses for true asides. Reserve the em dash for one genuine interruption or reversal per piece.  
**Before:** "The author — a former chess prodigy — argues — somewhat surprisingly — that rules matter more than creativity."  
**After:** "The author, a former chess prodigy, argues that rules matter more than creativity — which is surprising given his background."

### H8 — Add a Concrete Anecdote or Named Example

**Problem:** Summary is entirely abstract or paraphrastic.  
**Fix:** Find one scene, one exchange, one named person from the book and put it in the summary.  
**Signal:** If a reader who has read the book would not recognize a single detail from the summary, the summary has no specificity.

### H9 — Open In Medias Res

**Problem:** Opening sentence frames the topic ("This book is about…") instead of entering it.  
**Fix:** Open with something from the book — a claim, a scene, a statistic, a question the book poses.  
**Before:** "In 'Thinking, Fast and Slow', Daniel Kahneman explores the two systems of thought that drive human decision-making."  
**After:** "Most people believe they are rational most of the time. Kahneman's forty years of research suggests they are wrong most of the time and don't know it."

### H10 — Write the Conclusion as a New Thought, Not a Recap

**Problem:** Final paragraph repeats the summary's opening.  
**Fix:** End on the one implication, limitation, or open question that wasn't addressed earlier. Make the reader feel the summary added something.

---

## Sources

[^1]: Kobak et al., "Delving into LLM-assisted writing in biomedical publications through excess vocabulary," *Science Advances*, 2025. Examined 15M+ PubMed abstracts; documented 21 focal words with post-ChatGPT frequency spikes. https://www.science.org/doi/10.1126/sciadv.adt3813 — https://arxiv.org/abs/2406.07016

[^2]: Pangram Labs, "Walking Through AI's Overused Phrases," 2024. Frequency multipliers drawn from their corpus comparison. https://www.pangram.com/blog/walking-through-ai-phrases — https://www.pangram.com/blog/comprehensive-guide-to-spotting-ai-writing-patterns

[^3]: Walter Writes AI, "Most Common ChatGPT Words to Avoid in 2026," citing AI Ethics Institute 2025 study (10,000 output corpus). https://walterwrites.ai/most-common-chatgpt-words-to-avoid/ — https://willfrancis.com/how-to-stop-claude-writing-like-an-ai/

[^4]: Wikipedia editorial guide, "Wikipedia:Signs of AI Writing," continuously updated by editors flagging AI-generated article submissions. https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing

[^5]: ossama.is / GitHub, "AI Writing Tropes to Avoid," practitioner reference list. https://gist.github.com/ossa-ma/f3baa9d25154c33095e22272c631f5a1 — https://matthewvollmer.substack.com/p/i-asked-the-machine-to-tell-on-itself

[^6]: Hastewire, "Uncover Linguistic Patterns of AI Writing: Key Tells" — cites 20% higher repetition rate and 15% lower lexical diversity in AI journalism vs. human journalism. https://hastewire.com/blog/uncover-linguistic-patterns-of-ai-writing-key-tells

[^7]: Brent Csutoras, "The Em Dash Dilemma: How a Punctuation Mark Became AI's Stubborn Signature," *Medium*, 2024. https://medium.com/@brentcsutoras/the-em-dash-dilemma-how-a-punctuation-mark-became-ais-stubborn-signature-684fbcc9f559

[^8]: ProofreaderPro.ai, "The Em Dash — Why AI Spams It," with practical removal advice. https://proofreaderpro.ai/blog/remove-em-dashes-from-academic-writing

[^9]: Junia AI editorial analysis, "LLM Default Voice: Why AI Writing Sounds the Same in 2026." https://www.junia.ai/blog/llm-default-voice-ai-writing

---

## Summary of Highest-Signal Tells (5-Line Version)

1. **Lexical clusters:** Multiple focal words (`delve`, `tapestry`, `underscore`, `pivotal`, `transformative`, `boasts`) in the same sentence or paragraph — individually suspicious, together nearly conclusive.
2. **"It's not just X, it's Y":** The negated-contrast construction is the single most diagnostic rhetorical move; it mimics insight by restating an idea with inflated vocabulary.
3. **No specifics:** A summary with no named people, dates, dollar amounts, or concrete scenes from the book is almost certainly AI-generated or AI-paraphrased.
4. **Uniform rhythm and signposting:** Metronomic sentence lengths, "It's worth noting," "Let's explore," rule-of-three in every paragraph, and a conclusion that opens with "In summary" and recaps verbatim.
5. **No point of view:** AI summarizes *that* an argument is made, never *whether* it's right, never *for whom* it works—this absence of friction is the deepest substance tell.
