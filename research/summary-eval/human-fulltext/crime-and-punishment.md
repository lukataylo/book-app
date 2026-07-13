# Crime and Punishment — Human-Written Mid-Book Plot Sources
**Book:** Crime and Punishment (Преступление и наказание)
**Author:** Fyodor Dostoevsky
**Year:** 1866 (serialized in *The Russian Messenger*); public domain (author died 1881)

**Why this file exists / how it differs from the rest of the benchmark set:** every other book in
this eval (`human/`, `human-fulltext/`) is nonfiction — habit science, history, psychology. Those
books don't have a "plot" that can be dropped; a nonfiction summarizer that skips chapter 4 just
skips a topic. This file is the **one fiction, plot-driven example**. A summarizer that "forgets
the middle" of a novel produces a checkable, unambiguous failure: a named character or thread
(Svidrigailov, the Marmeladovs, Porfiry's interrogations) simply never appears, even though it
consumes ~40% of the book's page count (Parts 3–5 of 6 + epilogue). That makes *Crime and
Punishment* the sharpest instrument in the set for testing whether a chunked map-reduce pipeline
retains mid-document material or collapses toward the famous bookends (the axe murder in Part 1;
confession/Siberia/redemption in Part 6 + Epilogue).

**Legal note:** the novel itself is public domain, so quoting Dostoevsky's own prose would be
safe — but the deliverable here is HUMAN-WRITTEN SUMMARY/ANALYSIS prose, which is what a
summarizer eval actually needs to be compared against. Wikipedia's plot section is CC BY-SA, so it
is quoted generously below (nearly in full for Parts 3–5) with attribution and a link, consistent
with the license. The study-guide sources (SparkNotes, GradeSaver) are commercially copyrighted;
only short (1–3 sentence) attributed excerpts are taken from each, never bulk copy.

---

## Source 1: Wikipedia — "Crime and Punishment," Plot section (Parts 3, 4, 5)

**URL:** https://en.wikipedia.org/wiki/Crime_and_Punishment
**License:** CC BY-SA 4.0 (quoted generously per license, with attribution)
**Parts covered:** All six parts + epilogue; excerpted here for Parts 3–5, the middle stretch.

**Representative mid-book excerpt (Part 3 — Porfiry's first interrogation):**

> "At Raskolnikov's behest, Razumikhin takes him to see the detective Porfiry Petrovich, who is
> investigating the murders. Raskolnikov immediately senses that Porfiry knows that he is the
> murderer. Porfiry... adopts an ironic tone during the conversation. He expresses extreme
> curiosity about an article that Raskolnikov wrote some months ago called 'On Crime,' in which he
> suggests that certain rare individuals—the benefactors and geniuses of mankind—have a right to
> 'step across' legal or moral boundaries if those boundaries are an obstruction to the success of
> their idea."

**Representative mid-book excerpt (Part 4 — Svidrigailov's arrival and Luzhin's exposure):**

> "Svidrigailov indulges in an amiable but disjointed monologue... He claims to no longer have any
> romantic interest in Dunya, but wants to stop her from marrying Luzhin, and offers her ten
> thousand roubles... The meeting with Luzhin that evening begins with talk of Svidrigailov—his
> depraved character, his presence in Petersburg, the unexpected death of his wife and the 3000
> rubles left to Dunya... when Raskolnikov draws attention to the slander in his letter, Luzhin
> becomes reckless, exposing his true character. Dunya tells him to leave and never come back."

**Representative mid-book excerpt (Part 5 — the money-planting scheme and Katerina Ivanovna's death):**

> "Everyone is surprised by the sudden and portentous appearance of Luzhin. He sternly announces
> that a 100-ruble banknote disappeared from his apartment at the precise time that he was being
> visited by Sonya... a folded 100-ruble note does indeed fly out of one of the pockets... But
> Luzhin's roommate Lebezyatnikov arrives, and angrily asserts that he saw Luzhin surreptitiously
> slip the money into Sonya's pocket... They find Katerina Ivanovna surrounded by people in the
> street, completely insane, trying to force the terrified children to perform for money, and near
> death from her illness... where, distraught and raving, she dies. To Raskolnikov's surprise,
> Svidrigailov suddenly appears and informs him that he will be using the ten thousand rubles
> intended for Dunya to make the funeral arrangements... Svidrigailov has been residing next door
> to Sonya, and overheard every word of the murder confession."

**Observations — how it keeps Svidrigailov / Marmeladovs / Porfiry legible simultaneously:**
- **One paragraph = one scene = one thread.** Wikipedia never interleaves threads within a
  paragraph; each paragraph is scoped to a single scene (the Porfiry visit, the Svidrigailov
  monologue, the family confrontation with Luzhin), so a reader tracking "what happened to
  Svidrigailov" can scan paragraph-by-paragraph without the thread getting lost in the others.
- **Every reappearance re-anchors the character's status, not just their name.** Svidrigailov
  isn't just named again in Part 5 — the text restates *why* he matters each time ("the ten
  thousand rubles intended for Dunya," "has been residing next door to Sonya") so a reader who
  skipped ahead can still reconstruct the thread's state without rereading Part 4.
  This is the single biggest tell distinguishing human synopsis from a lossy summarizer: state is
  carried forward explicitly, not assumed.
  - **Consequences are stated, not just events.** The Luzhin money-planting isn't reported as an
  isolated incident; the text immediately gives its causal payoff ("Luzhin is discredited, but
  Sonya is traumatized") in the same breath, so the thread's throughline (Luzhin's motive: revenge
  on Raskolnikov via Sonya's reputation) survives compression.
- **No thread is resolved early to simplify the telling.** Svidrigailov's money offer to Dunya
  (Part 4) is left dangling ("refuses the money on her behalf") and only pays off two Parts later
  — Wikipedia tolerates that open loop rather than collapsing or pre-resolving it, which is exactly
  what a map-reduce summarizer under length pressure tends to do (resolve early / drop the
  follow-through).

---

## Source 2: SparkNotes — Crime and Punishment, Part III: Chapters IV–VI

**URL:** https://www.sparknotes.com/lit/crime/section7/
**Parts covered:** Part III, Chapters IV–VI (Porfiry's "On Crime" interrogation; the artisan who
calls Raskolnikov "murderer"; Svidrigailov's first appearance).

**Representative mid-book excerpt (attributed, short):**

> "Porfiry mentions an article that Raskolnikov had written, 'On Crime'... In the article, he
> argued that certain men were above the general run of humanity, and, as such, they have a right
> to commit murder. ... Porfiry asks him if he saw any painters at work in the building on his
> last visit to Alyona's, two days before the crime. Raskolnikov recognizes the trap, recalling
> that there were painters there on the day of the murder but not two days before, and says no."
> (SparkNotes, "Crime and Punishment Part III: Chapters IV–VI Summary")

**Observations:**
- SparkNotes narrows to a single scene per page (one chapter cluster) rather than trying to
  cover all of Part 3 in one sweep — the granularity itself is a coverage strategy: it forces the
  study-guide format to give Porfiry's interrogation its own dedicated space rather than
  compressing it into a single "Raskolnikov visits the police" sentence, which is the failure mode
  a chunked summarizer risks if Porfiry's three separate interrogations (Parts 3, 4, 6) get folded
  into one generic beat.
- The trap detail (painters seen "two days before" vs. "on the day of the murder") is preserved
  as a *specific, falsifiable fact* rather than a vague "Porfiry tries to trick him" — this
  specificity is a strong human-summary signal; AI summarizers tend to flatten interrogation
  scenes into "Porfiry suspects him" without retaining the mechanism of the trap.

---

## Source 3: GradeSaver — Crime and Punishment, Part Four, Chapters 1–6

**URL:** https://www.gradesaver.com/crime-and-punishment/study-guide/summary-part-four-chapters-1-6
**Parts covered:** Part IV (Svidrigailov's visit and 10,000-ruble offer; the Luzhin/Dunya
confrontation; Raskolnikov's visit to Sonya; Mikolka's false confession).

**Representative mid-book excerpt (attributed, short):**

> "Svidrigailov tells him that he is there for two reasons: because he has been interested in
> meeting Rodya, and because he would like his help in a matter regarding Dunya... He is prepared
> to offer her 10,000 roubles to break it off... Dunya, enraged, tells him to get out." (GradeSaver,
> "Crime and Punishment Part Four, Chapters 1-6 Summary and Analysis")

**Observations:**
- GradeSaver keeps Svidrigailov's *stated motive* ("two reasons") legible as a numbered structure
  even in prose — it resists the temptation to summarize his visit as one sentence of vague
  menace, instead preserving the two distinct claims he makes (curiosity about Raskolnikov, help
  with Dunya) because both claims matter later (the first for the Raskolnikov-Svidrigailov double,
  the second for the blackmail plot in Part 6).
- Because this page is scoped to exactly one Part, it can afford to give Luzhin's exposure its own
  paragraph distinct from Svidrigailov's — the chaptering itself functions as a thread-separator,
  which a summarizer without explicit chapter/part boundaries in its context window may not
  replicate.

---

## Source 4: GradeSaver — Crime and Punishment, Part Five, Chapters 1–5

**URL:** https://www.gradesaver.com/crime-and-punishment/study-guide/summary-part-five-chapters-1-5
**Parts covered:** Part V (the Marmeladov funeral dinner; Luzhin's accusation against Sonya;
Lebezyatnikov's revelation; Katerina Ivanovna's death).

**Representative mid-book excerpt (attributed, short):**

> "Luzhin tells Sonya that he has lost a 100-rouble bill, and that its disappearance coincided with
> her visit... He had seen him slip the bill into Sonya's pocket as she was leaving... She is
> bleeding, not because of an external wound but because she is in the last stages of her
> consumption." (GradeSaver, "Crime and Punishment Part Five, Chapters 1-5 Summary and Analysis")

**Observations:**
- Even in three short excerpted sentences, three separate sub-threads are legible: Luzhin's
  scheme, Lebezyatnikov's counter-testimony, and Katerina Ivanovna's independent medical decline —
  GradeSaver doesn't merge Katerina's death into "the family was ruined by the scandal"; it keeps
  the *cause* (consumption, not the scandal itself) distinct from the social humiliation that
  precipitates her final breakdown. That causal precision is exactly the kind of mid-book detail
  a summarizer tends to lose when it treats the Marmeladov tragedy as one undifferentiated
  "misery" beat.
- The chapter-scoped structure again does the labeling work implicitly: because this page is
  Part V Chapters 1–5 only, the money-planting scheme and Katerina's death are guaranteed screen
  time proportional to their actual weight in the text, rather than being compressed relative to
  the (shorter, but more famous) murder scene in Part 1.

---

## Source 5: SparkNotes — Crime and Punishment, Part V: Chapters I–IV

**URL:** https://www.sparknotes.com/lit/crime/section10/
**Parts covered:** Part V, Chapters I–IV (the confession to Sonya).

**Representative mid-book excerpt (attributed, short):**

> "He confesses the murders to her... 'I was ambitious to become another Napoleon; that was why I
> committed a murder.' Sonya tells him that he must confess his sins publicly for God to give him
> peace... She gives him a pendant cross to wear, similar to the one that she wears, saying that
> they will both bear their crosses." (SparkNotes, "Crime and Punishment Part V: Chapters I–IV
> Summary & Analysis")

**Observations:**
- This excerpt shows the confession to Sonya (mid-book, Part 5) treated with the same narrative
  weight as the *final* confession to the police (Part 6/Epilogue) — SparkNotes gives the private,
  mid-book confession its own scene summary with direct quotation of Raskolnikov's stated motive
  ("another Napoleon"), rather than treating it as a mere preview of the "real" ending. A
  summarizer fixated on the famous bookends risks compressing this into "he eventually confesses,"
  erasing the fact that the *emotional* climax (confession to a person who loves him) and the
  *legal* climax (confession to the state) are two distinct events 100+ pages apart.
- The cross-exchange detail is retained even in a short excerpt because it pays off directly in
  the Epilogue (Sonya follows him to Siberia) — a durable human-summary habit is carrying forward
  small concrete objects (the cross, the 3,000 rubles Svidrigailov later gives Sonya) as
  continuity anchors between mid-book and ending.

---

## Synthesis: What a human writer does differently when covering the middle of a plot-driven book

1. **Explicit thread-labeling by character/proper noun, every reappearance.** Every source above
   re-names "Svidrigailov," "Luzhin," "Katerina Ivanovna," and "Porfiry" at each reappearance
   rather than relying on pronouns or vague references ("the suitor," "the investigator") — this
   keeps parallel threads disambiguated even when a reader (or summarizer) has been away from a
   thread for several paragraphs. A useful coverage signal for the eval: **count of distinct named
   characters that reappear with updated status **after** their introduction** — a summary that
   introduces Svidrigailov once in Part 4 and never mentions him again until the Epilogue's
   aftermath has "forgotten the middle."

2. **Chronological/structural anchors (Part/Chapter numbers) instead of vague temporal markers.**
   Every human source scopes itself to a specific Part or chapter range rather than saying "later
   in the book" or "eventually" — this is what prevents multiple mid-book events (Porfiry's three
   separate interrogations; Svidrigailov's two separate financial offers) from collapsing into one
   generic beat. A summarizer without hard chunk/part boundaries in its map step tends to lose this
   anchoring.

3. **Causal payoffs are stated adjacent to the event, not deferred or dropped.** Human sources
   don't just report "Luzhin plants money in Sonya's pocket" — they immediately state the motive
   (revenge on Raskolnikov, an attempt to split him from his family) and the consequence (Luzhin
   discredited, family evicted). A lossy summarizer often preserves the *event* of a mid-book scene
   but drops its *causal function* in the larger plot, producing a summary that lists things that
   happened without explaining why they mattered.

4. **Open loops are tolerated, not prematurely resolved.** Svidrigailov's 10,000-ruble offer is
   introduced in Part 4 and explicitly left unresolved ("refuses... on her behalf") for two more
   Parts before it pays off. Human summarizers are comfortable leaving a thread open across a large
   textual gap because they've read (or are working from a synopsis of) the whole book; a
   chunk-by-chunk map-reduce summarizer, by contrast, often either resolves a thread too early
   (inventing closure within the chunk it appears in) or drops it once its originating chunk is out
   of the context window.

5. **Concrete objects and small physical details serve as continuity anchors across long spans.**
   The pendant cross, the 100-ruble note, the 10,000/3,000-ruble sums, the axe, Lizaveta's Gospels
   — human summaries keep these small props consistent and reference them again at reappearance
   (the cross given in Part 5 is the cross Raskolnikov wears to confess in Part 6; the 10,000
   rubles offered in Part 4 becomes the money Svidrigailov spends on the Marmeladov children and
   Sonya's travel funds in Part 5–6). Their disappearance or renaming between mentions is a cheap,
   checkable proxy for "the summarizer lost track of the middle."
