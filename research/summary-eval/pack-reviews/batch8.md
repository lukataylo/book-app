# Pack Reviews — Batch 8

**Date:** 2026-06-15
**Evaluator:** claude-sonnet-4-6
**Scope:** 10 packs — `summary_short` (primary) and `summary` (flagged where distinct issues arise). Scored against the 6 SKILL criteria from `research/summary-eval/SKILL.md`.
**Prior batch baseline:** `eval-results.md` (batch 7, mean 19.6/30; all 8 summaries carry the meta-close).
**Scoring:** Sub-scores 0–5 on (a) thesis-first hook, (b) concreteness / named real examples, (c) authorial POV & stated limits, (d) voice & sentence-rhythm variety, (e) freedom from AI-tells, (f) close that motivates the **book** (not our longer summary). Total /30.

---

## Verified measurements (`summary_short` only)

Counts are from the text. Em-dash count verified character by character.

| Book | Words (est) | Em-dashes | Em/300w | 3+ item lists | Sentences | Avg len (w) | Shortest sent (w) |
|------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| the-selfish-gene | 305 | **0** | 0.00 | 3 | 11 | 27.7 | 10 |
| the-slight-edge | 260 | **0** | 0.00 | 1 | 13 | 20.0 | 13 |
| the-tipping-point | 280 | **0** | 0.00 | 2 | 10 | 28.0 | **7** |
| the-war-of-art | 275 | **0** | 0.00 | 3 | 12 | 22.9 | 10 |
| thinking-fast-and-slow | 319 | **0** | 0.00 | 3 | 12 | 26.6 | **7** |
| tiny-habits | 270 | **0** | 0.00 | 3 | 13 | 20.8 | 15 |
| ultralearning | 265 | **0** | 0.00 | 2 | 12 | 22.1 | 8 |
| why-we-sleep | 285 | **0** | 0.00 | 2 | 11 | 25.9 | 8 |
| your-money-or-your-life | 280 | **0** | 0.00 | **1** | 12 | 23.3 | **7** |
| zero-to-one | 270 | **0** | 0.00 | 1 | 10 | 27.0 | **22** |

**Batch-level em-dash note:** 0 em-dashes across all 10 summaries. Completely different from batch 7 (mean 4.0/300w, peak 6.10). Em-dash overuse is NOT a defect in this batch.

**Meta-close "The full summary…" formula: present in 10 of 10.** Universal, same as batch 7 (8/8). Every short closes by pointing at our own product.

---

## Scored table

| Book | (a) Hook | (b) Concrete | (c) POV | (d) Rhythm | (e) AI-tells | (f) Close | Total /30 |
|------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| the-tipping-point | 5 | 4 | 4 | 4 | 3 | 2 | **22** |
| your-money-or-your-life | 5 | 3 | 4 | 4 | 4 | 2 | **22** |
| thinking-fast-and-slow | 4 | 2 | 3 | 3 | 4 | 3 | **19** |
| ultralearning | 5 | 3 | 2 | 3 | 4 | 1 | **18** |
| why-we-sleep | 4 | 2 | 4 | 3 | 3 | 2 | **18** |
| the-slight-edge | 4 | 2 | 2 | 3 | 4 | 1 | **16** |
| tiny-habits | 5 | 3 | 2 | 2 | 3 | 1 | **16** |
| zero-to-one | 5 | 2 | 2 | 2 | 4 | 1 | **16** |
| the-selfish-gene | 4 | 2 | 2 | 3 | 3 | 1 | **15** |
| the-war-of-art | 4 | 2 | 2 | 3 | 3 | 1 | **15** |
| **Mean** | **4.5** | **2.5** | **2.7** | **3.0** | **3.5** | **1.5** | **18.1** |

Batch mean: 18.1/30. Lower than batch 7 (19.6/30). Biggest drags: (f) Close (mean 1.5, crushed by meta-close) and (b) Concreteness (mean 2.5, most packs describe ideas without anchoring them in a named scene).

---

## Per-book analysis

---

### the-tipping-point — 22/30 (batch best)

- **(a) 5:** Opens on the Hush Puppies scene with real numbers — *"In 1994 the Hush Puppies brand was nearly dead until a few downtown kids started wearing the shoes precisely because no one else did, and within two years sales multiplied roughly fiftyfold with no marketing spend."* Concrete, named, dated. Immediately into the thesis.
- **(b) 4:** Hush Puppies (1994, fiftyfold), Paul Revere vs. unnamed second rider, the seminary study (running late), Dunbar's 150. Four real examples across three ideas. The short does NOT name Sesame Street or Blue's Clues, only "children's television" — a missed opportunity to add two more anchors.
- **(c) 4:** Explicit friction: *"notes honestly where the book has aged poorly, especially its embrace of broken-windows policing, which later research and real-world costs have called into question."* Rare in this batch.
- **(d) 4:** Best rhythm in the batch. *"He distills the spread into three levers."* = 7 words (sub-8). Range spans 7–44 words. Genuine burst-and-stretch pattern.
- **(e) 3:** Two lists over three items ("ideas, products, behaviors, and even crime" — 4 items; "connectors…enthusiasts…personalities" — 3 items). No inflated signposts. Meta-close present.
- **(f) 2:** *"The full summary develops each lever with its cases and notes honestly where the book has aged poorly, especially its embrace of broken-windows policing, which later research and real-world costs have called into question."* Starts with the meta-close formula. The content (broken-windows note) is genuine, but the opener is still "The full summary develops…" which fails the trailer test.

**AI-tells flagged:**
- Meta-close formula opening
- "ideas, products, behaviors, and even crime" — 4-item list in a single sentence

**Edits:**
1. Name Sesame Street and Blue's Clues: replace *"the relentless testing behind children's television"* with *"the relentless testing behind Sesame Street — where mixed Muppet-and-adult scenes won over expert dogma because preschoolers' wandering attention said so."*
2. Replace meta-close: *"The world, Gladwell insists, is not immovable — it only looks that way to people pushing in the wrong spots. This book is a map of where the right spots tend to hide."*
3. Name William Dawes in the Revere paragraph (he is currently only "a second rider") — naming him costs three words and adds concreteness.

---

### your-money-or-your-life — 22/30 (batch joint-best)

- **(a) 5:** *"Long before the FIRE movement had a name, Vicki Robin and Joe Dominguez built a nine-step program around one unsettling idea: every purchase is paid for in hours of your finite life."* Both authors named, historical anchor (pre-FIRE), thesis in first sentence.
- **(b) 3:** Both authors named, FIRE movement named, jacket example (concrete, specific), wall chart concept, "enough" named. Missing: Dominguez's specific biography (retired from Wall Street at 31) and the Treasury-bond anecdote are in the long summary but not the short.
- **(c) 4:** Two clear limits: *"the specific investment advice has aged unevenly"* and *"None of it is personalized financial advice."* Among the batch's strongest friction. Also editorial: *"a philosophical ambush"* — genuine point of view.
- **(d) 4:** Sub-8 sentence: *"None of it is personalized financial advice."* = 7 words. Also *"Your Money or Your Life is less a budgeting book than a philosophical ambush."* = 16 words. Range 7–45 words. Cleanest rhythm variety in the batch alongside tipping-point.
- **(e) 4:** Only 1 tricolon (*"through clutter, maintenance, and the hours owed to finance them"*). Cleanest list count in batch. No inflated signposts. Meta-close present but its content (investment-advice aging caveat) adds real value.
- **(f) 2:** *"The full summary walks through the nine steps and notes that the specific investment advice has aged unevenly, while the core instrument of pricing purchases in hours has needed no update. None of it is personalized financial advice."* Opens with the meta-close formula. The disclaimer adds substance but doesn't replace the book-motivation function.

**AI-tells flagged:**
- Meta-close formula (the only real flag; this is otherwise the batch's cleanest pack)
- "the quietly devastating one" — interpretive but borderline overwritten

**Edits:**
1. Pull Dominguez's biography into the short: *"Joe Dominguez walked away from Wall Street at 31 and never earned a paycheck again — then built the philosophy around that choice."* One sentence, anchor for the whole thesis.
2. Replace meta-close: *"The book's sharpest instrument needs no update since 1992: price every purchase in hours of your one finite life, and watch what survives the conversion."*
3. Keep *"philosophical ambush"* — it earns its place.

---

### thinking-fast-and-slow — 19/30

*(Note: this pack appeared in batch 7. Score is consistent with eval-results.md: 4+2+3+3+4+3 = 19.)*

- **(a) 4:** Question hook (*"Why do intelligent people make predictable mistakes?"*) then immediate answer. Good but not a scene-hook.
- **(b) 2:** Amos Tversky named; loss aversion's "roughly twice as much" is a real number. But **no signature scene** — no Israeli judges parole study, no Linda the bank teller. *"Mental fatigue and even hunger make people more impulsive"* paraphrases a study without naming it or giving figures.
- **(c) 3:** Competent exposition but **no replication-crisis note** — significant omission given Kahneman's own concessions. Reads as unconditional endorsement.
- **(d) 3:** *"From this foundation come the famous distortions."* = 7 words (sub-8). Two short sentences against long-sentence body. Moderate variety.
- **(e) 4:** 0 em-dashes (cleanest in batch 7 too). Two signpost tells: *"His crucial claim"* and *"the famous distortions."* Meta-close present.
- **(f) 3:** *"The full summary works through each idea in plain language, so you can recognize the machinery of your own thinking while it runs."* The payoff tail (*"recognize the machinery of your own thinking while it runs"*) is genuinely good — the best close-tail in the batch — but it is still inside the meta-close formula.

**AI-tells flagged:**
- *"His crucial claim"* — inflated signpost
- *"the famous distortions"* — hedge/signpost
- Meta-close formula

**Edits:**
1. Insert the Israeli judges scene: *"In one study, Israeli judges granted parole to roughly 65 percent of prisoners seen right after a break and to nearly zero percent seen just before lunch — not because the cases differed, but because the judges did."*
2. Add replication friction: one sentence noting that priming studies in particular have replicated poorly and that Kahneman himself acknowledged this publicly.
3. Replace meta-close: *"Kahneman's honest admission is that knowing about biases barely protects him either. The goal is not immunity — it is recognizing the moments when the fast mind is most likely to be running the wrong program."*

---

### ultralearning — 18/30

- **(a) 5:** Opens on Young's MIT stunt with real specifics: *"Scott Young taught himself the bulk of MIT's computer science curriculum in about a year using free materials, then learned four languages abroad by refusing to speak English."* Named person, named institution, concrete constraint. Immediately into thesis.
- **(b) 3:** MIT project (named, specific). The Paris café example (*"classroom French collapses at a Paris cafe"*) is concrete. *"Memory athletes, polyglots, and self-taught originals"* in the close are generic. Richard Feynman is named in the long summary as the depth-understanding model but absent from the short. No study or specific named figure besides Young.
- **(c) 2:** No stated limit. The long summary says *"least useful for those seeking encouragement rather than a workout plan"* but this for-whom sentence is absent from the short. No friction about where the method strains (interpersonal skills, highly variable feedback environments).
- **(d) 3:** *"The method runs on a few sharp principles."* = 8 words (exactly at threshold, not sub-8). Range approximately 8–42 words. Reasonable but not distinctive.
- **(e) 4:** 0 em-dashes. Two tricolons (*"outcome, informational, and the rare corrective kind"*; *"memory athletes, polyglots, and self-taught originals"*). No inflated signposts. Meta-close present.
- **(f) 1:** *"The full summary expands each principle with his case studies of memory athletes, polyglots, and self-taught originals, plus the tactics that make the approach work."* Pure table-of-contents recap. No book implication, no open question, no motivating payoff.

**AI-tells flagged:**
- Meta-close as pure table of contents
- *"Above all, pull knowledge out"* — directional signpost (minor)

**Edits:**
1. Name Feynman in the short: replace *"he prizes refusing to let confusion slide"* with *"he invokes Richard Feynman — a mind that rebuilt every formula from scratch rather than memorizing it — as the model for what deep understanding actually looks like."*
2. Add a for-whom sentence: *"The method trades comfort for speed; it works best where feedback is real and fast, and strains in fields where performance is hard to measure."*
3. Replace meta-close: *"Young's deepest permission is simple: the walls that most people treat as the boundary of the learnable are not walls — they are only the points where institutional instruction stops and self-design begins."*

---

### why-we-sleep — 18/30

- **(a) 4:** *"After two decades running sleep laboratories, Matthew Walker argues in Why We Sleep that modern humans are chronically and dangerously under-slept."* Thesis in sentence 1. Evolutionary hook in sentence 2. Solid but not a scene-hook — no vivid opening image.
- **(b) 2:** Walker named. *"Microsleeps behind the wheel"* is a named phenomenon. *"A chemical that accumulates while you are awake"* refers to adenosine without naming it. No study named (the natural-killer-cells experiment, the daylight-saving-time data, and the 10-nights-of-6-hours finding are all in the long summary but absent from the short). *"Needs source check"* applies to the book's statistics generally, as the summary correctly notes.
- **(c) 4:** Strong friction: *"His catalogue of the costs of short sleep…is the book's most famous and most contested material."* And *"the direction of his evidence is well supported even where the headline numbers remain disputed."* Among the batch's strongest limit-statements. Disclaimer *"None of this substitutes for personalized medical advice"* adds appropriate caveat.
- **(d) 3:** *"None of this substitutes for personalized medical advice."* = 8 words (borderline). *"His single most important recommendation is regularity, keeping consistent sleep and wake times."* = 13 words. Two 4-item lists create some density. Range approximately 8–52 words.
- **(e) 3:** Two 4-item lists: *"filing memories, regulating emotion, tuning immunity, and clearing the brain's waste"* and *"electric light, alarm clocks, alcohol that sedates rather than restores, and overheated bedrooms"* — both heavy. *"His single most important recommendation"* = inflated signpost. *"the book's most famous and most contested material"* = "most famous" signpost. 0 em-dashes (clean). Meta-close present.
- **(f) 2:** *"The full summary lays out his practical advice and notes honestly that researchers have challenged some of his strongest statistics, so the direction of his evidence is well supported even where the headline numbers remain disputed. None of this substitutes for personalized medical advice."* Starts with meta-close formula; but the content (statistical caveat + disclaimer) adds real value. Scored 2 rather than 1 because it goes beyond table-of-contents recap.

**AI-tells flagged:**
- *"His single most important recommendation"* — inflated signpost
- *"the book's most famous and most contested material"* — inflated signpost
- Two 4-item lists (heavier than any other pack in this batch)

**Edits:**
1. Name adenosine explicitly: *"a chemical called adenosine accumulates while you are awake"* — one word added, removes the vague "a chemical."
2. Insert one numbered finding: *"After ten nights of six hours' sleep, people in the lab performed as badly as if they had skipped a full night — and rated themselves only mildly tired. The deficit hides from the person carrying it."* Pull this from the long summary — it is the most unsettling specific result and belongs in the short.
3. Cut both inflated signposts (*"His single most important"* → *"His core recommendation"*; *"most famous and most contested"* → *"most contested"*). Replace meta-close: *"Walker's most uncomfortable finding is not the statistics but the self-concealment: the less you sleep, the less able you are to gauge how impaired you have become."*

---

### the-slight-edge — 16/30

- **(a) 4:** Opens with Olson's biography (*"made and lost a fortune more than once"*) and moves to the core claim. Not a scene-hook but a competent thesis opener.
- **(b) 2:** No named person, place, study, or real number beyond Olson himself. The pond-plant image is present but the key numbers (*"thirty days," "day twenty-nine," "half covered"*) are absent from the short, stripping the analogy of its impact. Olson's biography is referenced vaguely (*"made and lost a fortune"*) without the specifics in the long summary.
- **(c) 2:** No friction sentence. No stated limit (e.g., the philosophy works less well when the disciplines chosen point in the wrong direction; Olson assumes you know what "up" means). *"The supposed overnight success is almost always a slow climb viewed in time-lapse"* is mild editorial interpretation, not a genuine limit.
- **(d) 3:** *"You already know what to do, so information is not the bottleneck."* = 13 words (nearest to short). No sub-8 sentence. Range approximately 13–48 words. Flatter than the batch's best.
- **(e) 4:** 0 em-dashes. Only 1 tricolon (*"the small, immediate, repeated price of discipline"* — three adjectives, not a structural list). No inflated signposts. Meta-close present.
- **(f) 1:** *"The full summary unpacks each idea with Olson's examples and his unromantic picture of progress as continuous correction."* Table-of-contents recap. No implication, no open question.

**AI-tells flagged:**
- Meta-close as pure recap
- Pond plant without numbers (key analogy defanged)

**Edits:**
1. Add the numbers to the pond image: *"a pond plant that doubles daily smothers the whole surface on day thirty — and on day twenty-nine, an observer sees only open water."* The numbers are what make the image sting.
2. Add a friction sentence: *"The philosophy is most useful when the disciplines you choose actually point toward something you want; small inputs on the wrong curve compound just as relentlessly."*
3. Replace meta-close: *"Olson's wager is not optimism — it is arithmetic. The curve you are on today is the only one that will be visible in ten years."*

---

### tiny-habits — 16/30

- **(a) 5:** *"After two decades running a behavior lab at Stanford, BJ Fogg reached a quietly radical verdict: when you fail to change, the problem is almost never your character, it is your method."* Credentials as anchor, thesis in first sentence, immediately provocative. Strong.
- **(b) 3:** Fogg named, Stanford named, *"flossing one tooth or doing two push-ups"* (specific from the book). *"Celebrating on purpose"* is Fogg's named concept. But no named person who used the system, no study cited by name. The long summary mentions *"Fogg famously rebuilt his own fitness by doing a couple of push-ups after every bathroom trip"* — this is absent from the short and would ground the abstract method in a scene.
- **(c) 2:** No friction or stated limit. The short advocates Fogg's system unconditionally. The long summary includes *"if you are a parent, manager, coach, or designer whose job is changing other people's behavior"* (for-whom), but this is absent from the short.
- **(d) 2:** **Worst rhythm in the batch.** No sentence under 15 words. *"Tiny Habits reframes change as a design discipline rather than a test of willpower."* and *"To loosen unwanted habits he reverses the same three ingredients, starting with the prompt."* — both approximately 15 words. Range approximately 15–46 words. Monotonous medium-length across all 13 sentences.
- **(e) 3:** 0 em-dashes. Three tricolons: *"motivation, ability, and a prompt"* (B=MAP core ingredients); *"tiny survives your worst days, slips past procrastination, and keeps the habit alive while its roots grow"*; *"his troubleshooting sequences, his treatment of aspirations versus behaviors, and detailed guidance on untangling stubborn habits."* Signposts: *"Fogg's most contrarian claim"* and *"The signature technique is radical miniaturization"* — both mild but present. Meta-close.
- **(f) 1:** *"The full summary adds his troubleshooting sequences, his treatment of aspirations versus behaviors, and detailed guidance on untangling stubborn habits."* Pure tricolon table-of-contents recap.

**AI-tells flagged:**
- No sentence under 15 words — structural flatline (worst rhythm in batch)
- *"Fogg's most contrarian claim"* — signpost
- *"The signature technique"* — signpost
- Meta-close as tricolon recap

**Edits:**
1. Add a short sentence after the B=MAP paragraph — *"Prompts fail most often."* (4 words) — plant the rhythm break where it also carries meaning.
2. Add Fogg's own story: *"Fogg rebuilt his own fitness doing two push-ups after every bathroom trip — so small it sounds like a joke, which is precisely the point."*
3. Replace meta-close: *"Fogg's sharpest observation: shame has never designed a lasting habit. His system works by replacing judgment with curiosity about what the design missed."*

---

### zero-to-one — 16/30

- **(a) 5:** *"Most startup advice tells you how to run the race faster; Peter Thiel's Zero to One argues you should refuse to enter the race at all."* First sentence is a clean provocation. Strong.
- **(b) 2:** No named company in the key paragraphs. *"Interchangeable restaurants scraping near-zero margins"* and *"a dominant company that funds moonshots out of its surplus"* are generic — Google is never named. The long summary names PayPal (eBay power sellers), Facebook (one campus), Airbnb (empty bedrooms), Microsoft, and Apple, but the short names none of them. Thiel's interview diagnostic (the unpopular-truth question) is referenced abstractly.
- **(c) 2:** No friction. The long summary notes that the book *"reads as both vindicated and complicated"* and that the monopoly gospel *"has supplied cover for genuine governance failures."* None of this reaches the short. *"Both vindicated and complicated"* is hinted at in the meta-close only.
- **(d) 2:** **Joint-worst rhythm** (with tiny-habits). No sentence under 22 words. *"A valuable company, in his framing, is essentially a heretical belief about the future that turned out to be right."* = 22 words — the closest to short. Range approximately 22–52 words. Complete flatline of medium-long sentences.
- **(e) 4:** 0 em-dashes. Only 1 tricolon (*"every great success did something without precedent, that copying even the best model can never produce the next breakthrough, and that competition…is actually a tax on ambition"*). *"His most notorious claim"* = mild signpost. Meta-close present.
- **(f) 1:** *"The full summary develops each argument with his examples and offers a candid verdict on how the book reads a decade later, both vindicated and complicated."* Pure recap. The *"both vindicated and complicated"* tail is intriguing but buried inside the formula sentence.

**AI-tells flagged:**
- No sentence under 22 words — severe rhythm flatline
- Unnamed companies (Google, PayPal, Facebook, Airbnb) despite being named in the long summary
- *"His most notorious claim"* — signpost
- No friction in the body (only hinted at in meta-close)
- Meta-close formula

**Edits:**
1. Name the contrasting companies: replace *"a dominant company that funds moonshots out of its surplus"* with *"Google, which faced no serious search rival and funded self-driving cars from the surplus."* One named substitution anchors the whole argument.
2. Add one short sentence — anywhere. After *"refuses to enter the race at all"* the semi-colon already does rhythmic work, but: *"Competition bleeds both sides."* (4 words) could precede the monopoly paragraph.
3. Add friction: *"A decade on, the monopoly gospel looks different — the companies Thiel celebrated now face antitrust suits, and a philosophy this favorable to founder power has not always been used responsibly. Worth reading with that in mind."*
4. Replace meta-close: *"Thiel's strangest claim is also his most durable: the world still contains hard but discoverable truths, and most people have quietly stopped looking for them."*

---

### the-selfish-gene — 15/30 (batch joint-worst)

- **(a) 4:** Double question hook (*"Why would a bird endanger itself…or a worker bee labor…"*) before stating the thesis. Vivid opening pair but the thesis arrives as sentence 3, not sentence 1.
- **(b) 2:** Dawkins named (1976). No other real person named. The J.B.S. Haldane joke (*"two brothers or eight cousins"*) is the book's single most quotable concrete anchor — it is the long summary's highlight and absent from the short entirely. William Hamilton (kin selection formalizer) unnamed. The ground squirrel alarm-call scene unnamed. *"Dawkins coined a term for these cultural replicators"* does not name the term *meme* — the short never says the word.
- **(c) 2:** *"the living world snaps into a colder, sharper focus"* — mild interpretive edge. No stated limit (the organism/group-level criticism of the gene's-eye view is in the long summary but absent from the short).
- **(d) 3:** *"From this single move, Dawkins draws a cascade of surprises."* = 10 words (closest to short). Range approximately 10–55 words. One medium-short sentence but no sub-8 burst.
- **(e) 3:** 0 em-dashes. Three tricolons: *"not you, your body, or even your species"*; *"tunes, beliefs, and techniques"*; *"bluffing, retreating, and occasional fighting."* *"His boldest leap"* = mild signpost. Meta-close present.
- **(f) 1:** *"The full summary develops these threads in depth, tracing how the criteria for a winning idea mirror those for a winning gene and why beautiful falsehoods can thrive."* Table-of-contents recap with a decent tail. Still the meta-close formula.

**AI-tells flagged:**
- Missing the word "meme" (the book's most famous coinage)
- Missing Haldane joke — the only specific number in the book's kin-selection argument
- Three tricolons in 305 words
- *"His boldest leap"* signpost
- Meta-close

**Edits:**
1. Name the meme: *"Dawkins coined the word meme for these cultural replicators."* Costs nothing. The book's most famous word should appear.
2. Add Haldane: *"J.B.S. Haldane put the math as a dry joke: he would lay down his life for two brothers or eight cousins."* One sentence gives the kin-selection arithmetic a face.
3. Replace meta-close: *"The gene's-eye view is Dawkins's own reminder that understanding the selfish logic is the first step to acting against it — we are the only survival machines that can override the machinery."*

---

### the-war-of-art — 15/30 (batch joint-worst)

- **(a) 4:** *"Everyone who has tried to write a book, build a business, or keep any serious promise to themselves knows the gap between Tuesday night's vow and Wednesday morning's couch."* Strong reader-identification opening. Pressfield's biography arrives in sentence 2. Thesis (Resistance) arrives in sentence 3 — slightly delayed but vivid.
- **(b) 2:** No scene from the book. Pressfield's 20 years of failed work are referenced in the long summary but the short only says *"nearly two decades stuck on the wrong side of that gap"* without the detail (hauling a typewriter between odd jobs, unpublished) that makes it concrete. No historical or biographical anchor beyond this vague reference. The long summary names no case studies — the book itself uses few — but the short could use Pressfield's specific vocational history.
- **(c) 2:** No stated limit. The long summary carries a genuine caveat: *"Fair warning, and this is my caveat rather than his — the book is pure assertion, zero studies, delivered in a drill sergeant's cadence, and the mystical third act will lose some readers entirely."* This is the sort of friction that separates the long from the short in this pack, and its absence from the short is the single biggest gap.
- **(d) 3:** *"Pressfield catalogues its disguises so you can spot them."* = 10 words. *"Pressfield adds that inspiration follows action rather than preceding it."* = 10 words. Two 10-word sentences provide minor rhythm variation. Range approximately 10–56 words. Not flat but not burstily varied.
- **(e) 3:** 0 em-dashes. Three lists: *"write a book, build a business, or keep any serious promise to themselves"* (tricolon); *"busywork, endless preparation, manufactured personal drama, self-medication, and the loud cynicism of people fleeing their own unattempted work"* (5-item list — the heaviest in the batch); *"shows up on schedule regardless of mood, masters craft as a form of respect, and keeps daylight between self and output"* (tricolon). *"The book's hinge is turning pro"* — "hinge" is a mild architectural signpost. Meta-close.
- **(f) 1:** *"The full summary expands each idea, including his frankly mystical final claim that showing up reliably summons the work's deeper help."* The *"frankly mystical"* qualifier is good framing — it is honest about the book's register. But it is still inside the meta-close formula and leaves the reader nowhere to stand without clicking through.

**AI-tells flagged:**
- 5-item list: *"busywork, endless preparation, manufactured personal drama, self-medication, and the loud cynicism of people fleeing their own unattempted work"* — the longest list in the batch
- No concrete scene from the book (needs source verification: specific Pressfield biographical details)
- Missing the caveat that the book has no evidence base
- Meta-close

**Edits:**
1. Add Pressfield's specific biography: *"He spent nearly two decades hauling a typewriter between odd jobs, writing novels that didn't sell, before finishing The Legend of Bagger Vance."* — needs source check, but if accurate this turns the vague "two decades stuck" into a scene.
2. Add the caveat from the long summary: *"Fair warning: the book is pure assertion and zero studies, delivered in a drill sergeant's cadence. It will lose readers who need evidence. That is part of the design."*
3. Replace meta-close: *"You already know what to do. The question the book keeps returning to is why you are not doing it — and what to call the force that stops you."*

---

## Systematic weaknesses — ranked by (widespread × severity in this batch)

### 1. Meta-close ("The full summary…") — 10/10 — trivially fixable — TOP PRIORITY

Every short ends with a sentence pointing readers at our own longer summary, often as a table-of-contents recap ("develops each lever with its cases," "expands each principle with his case studies," "adds his troubleshooting sequences"). This is identical to batch 7's universal defect. The fix is the same: delete the formula; end on the book's sharpest implication or open question. **The batch8 packs that score 2 on (f)** — tipping-point, your-money-or-your-life, why-we-sleep, thinking-fast-and-slow — do so because their meta-close contains substantive content (a named critique, a disputed-statistics caveat). **The six that score 1** treat it purely as a table of contents. All ten fail the trailer test.

### 2. Concreteness gap — 8/10 packs score ≤3 — high-impact, harder

Only tipping-point (4/5) reaches real concreteness in the short. Seven packs score 2/5. The pattern: the short describes what Dawkins/Olson/Pressfield/Thiel *argues* without anchoring the argument in the scene or person or number that makes it stick. The long summaries generally have the anchors (Haldane joke in selfish-gene, Dominguez's retirement in your-money, Israeli judges in thinking-fast, Jung's tower in deep-work from batch 7). The writing process is pulling the anchor into the long summary and leaving the short abstract. Fix: for each short, identify the single best anchor in the long summary and move it up.

### 3. No friction / unconditional advocacy — 7/10 packs score ≤2 on (c)

Only tipping-point, your-money-or-your-life, and why-we-sleep include a meaningful stated limit or for-whom sentence. The other seven advocate unconditionally. The long summaries are markedly better: war-of-art has *"pure assertion, zero studies"*; ultralearning has *"least useful for those seeking encouragement"*; selfish-gene addresses the group-selection critics. These lines should migrate to the short. One friction sentence per short is the requirement, not a quota.

### 4. Rhythm flatline — worst in zero-to-one and tiny-habits

Zero-to-one has no sentence under 22 words (batch worst). Tiny-habits has none under 15 words. Both need a deliberate sub-8 sentence planted as a rhythm break. The packs with the best scores on (d) — tipping-point and your-money-or-your-life — each have a sentence of 7 words. That single sentence changes the texture of the entire piece.

### 5. Named-scene gap is specifically an anchor-transfer problem

Reviewing both `summary_short` and `summary` fields: the long summaries generally contain the anchors (J.B.S. Haldane, Israeli judges, MIT curriculum details, the daylight-saving data, Dominguez's retirement). The short summaries describe the ideas the anchors illustrate. This is not a research failure — the writer clearly has the book knowledge. It is an editing failure: the anchor stays in the long version as if it is too specific for the short. It is not. One named scene per short is the requirement and it is being systematically omitted.

---

## Common tells across all 10 packs (verified frequencies)

| Rank | Tell | Affected | Notes |
|:---:|---|:---:|---|
| 1 | Meta-close "The full summary…" | **10/10** | Universal; final sentence in every short |
| 2 | Concreteness deficit (no named scene/person/number) | 8/10 | Only tipping-point at 4/5; seven packs at 2/5 |
| 3 | No friction / unconditional advocacy | 7/10 | Three packs have meaningful limits; seven do not |
| 4 | Rhythm flatline (no sub-8 sentence) | 8/10 | Only tipping-point (7w) and your-money (7w) and thinking-fast (7w) achieve sub-8 |
| 5 | Three-or-more-item lists | 10/10 | Present in all; heaviest in war-of-art (3 lists, one 5-item), tiny-habits (3 lists), selfish-gene (3 lists) |
| 6 | Inflated-significance signposts | 6/10 | "His single most important," "His crucial claim," "Fogg's most contrarian claim," "His boldest leap," "the famous distortions," "His most notorious claim" |

**Notably absent from this batch:** em-dash overuse (0 across all 10 — clean). Lexical tells ("delve," "tapestry") also absent. The problems are architectural and substantive, not vocabulary.

---

## Worst → best ranking

| Rank | Book | Score |
|:---:|---|:---:|
| 1 (worst) | the-selfish-gene | 15 |
| 1 (worst) | the-war-of-art | 15 |
| 3 | the-slight-edge | 16 |
| 3 | tiny-habits | 16 |
| 3 | zero-to-one | 16 |
| 6 | ultralearning | 18 |
| 6 | why-we-sleep | 18 |
| 8 | thinking-fast-and-slow | 19 |
| 9 | the-tipping-point | 22 |
| 9 (best) | your-money-or-your-life | 22 |

**Batch mean: 18.1/30** (vs. batch 7 mean 19.6/30).

**What the top two do right that the bottom five do not:**
- the-tipping-point: opens on a named real scene (Hush Puppies, 1994, fiftyfold); has a friction sentence about broken-windows; has a sub-8-word sentence.
- your-money-or-your-life: names both authors and historical context in sentence 1; has two explicit stated limits; has a sub-7-word sentence; has only 1 tricolon.

**What the bottom two are missing:**
- the-selfish-gene: the word "meme," the Haldane joke, any named third party, a friction sentence, a short sentence.
- the-war-of-art: any specific scene, a friction sentence (caveat about the book's evidence-free methodology), a short sentence.

---

*Eval covers `summary_short` as primary; `summary` fields noted where they illuminate gaps in the short. Em-dash and sentence-length counts are manual estimates from text read; word counts are estimates. No pack JSON was modified (read-only per brief).*
