# 80 Ideas to Make BookApp Actually Useful

*July 2026. Four parallel research passes over this codebase, each applying the
[solo-business-idea-generation skill](../.claude/skills/solo-business-idea-generation/SKILL.md)
(scores are /70 on its Stage 13 rubric: Pain / Timing / Distribution / Monetisation /
Competition / AI-durability / Founder-leverage) through a different lens:*

1. **Reader value & retention** — would a reader miss the app if deleted?
2. **Niche monetisation & B2B** — who pays serious money for this technology?
3. **AI-native & agent-first** — what became possible in the last 24 months?
4. **Distribution, ecosystem & growth** — how does it get discovered and stay used?

## Executive synthesis

The four lenses converge on a handful of themes:

- **The review engine is built but invisible.** `FSRSScheduler`, `MemoryStore`,
  `ReviewLog`, streaks and daily-review notifications all exist in code — the
  redesign doc's "not built yet" list is stale. The cheapest wins (lock-screen
  widget, teach-back grading, quiz checkpoints) just give that loop a surface.
- **The moat is the user's corpus + feedback loop, not the summaries.** Highlights
  import (Kindle/Readwise), camera capture of physical books, and retention-tuned
  generation all deepen the one asset a frontier model can't substitute: years of
  personal reading, recall and plan-completion data in the user's own iCloud.
- **The OS is the distribution channel.** Share Extension, App Intents/Siri,
  widgets, Watch, CarPlay, App Clips — the app should intercept recurring moments
  (finding an article, commuting, glancing at the lock screen) rather than compete
  for open-intent reading time.
- **Agents are a second customer.** A local MCP server over the library
  (`search_library`, `get_highlights`, `what_do_I_believe_about`) makes every
  Claude session a consumer of the user's reading — the purest agent-first play.
- **The Act pipeline is the B2B product.** Book→scheduled, verifiable behaviour
  is what coaches, franchisors, L&D, sales enablement and accessibility channels
  will pay £299–£25k/yr for. The accountability workflow, channel certification
  and audit trail survive the AI-substitution test; the summary alone doesn't.

## Pay-focused shortlist

The strongest willingness-to-pay ideas across all four lenses, ranked. Pattern:
nobody pays for summaries — they pay for **accountability surfaces** (did my
franchisee/client/rep actually do it), **channel certification** (grant
assessors, compliance regimes), or **confidentiality posture** (no-backend +
BYO-key). Those are what "just ask ChatGPT" can't substitute.

| # | Idea | Who pays | What they're paying for | Price | Score |
|---|------|----------|------------------------|-------|-------|
| 1 | **ReadAccess** — dyslexia/ADHD reading accommodation | UK government (Access to Work / DSA grants), not the user | Certified assistive tool: word-synced TTS, RSVP pacing, compression, plain-prose restyle | £299/licence | 62/70 |
| 2 | **FranchiseFirst14** — ops manual → franchisee onboarding | Franchisors (5–500 units) | Audit trail that unit 47 completed onboarding; brand consistency | £2,990/yr + £49/franchisee | 59/70 |
| 3 | **CoachAssign** — assigned books clients actually do | Executive coaches (60k+ ICF members) | Visibility into client follow-through between sessions; retainer retention | £79/mo or £999/yr | 58/70 |
| 4 | **SermonForge** — theology books → sermon material | Pastors / churches | Weekly Sunday deadline relief; proven four-figure WTP niche (Logos) | £199/yr pastor, £599/yr church | 57/70 |
| 5 | **CramShift** — own textbook → exam countdown plan | USMLE/bar/CFA candidates | Passing vs. a $1,000+ retake; they already pay $500–$3,000 for prep | £149/exam campaign | 56/70 |
| 6 | **BoardroomBrief** — firm reading programs, zero data leaves the estate | L&D at law firms, banks, consultancies | The CISO-passable deployment (on-device + firm's own API key) that getAbstract can't offer | £5k–£25k/yr per firm | 56/70 |
| 7 | **QuotaReader** — sales book → daily rep drills | Sales enablement leads | Manager-visible reinforcement after every kickoff book assignment | £49/rep/yr, 20-seat min | 55/70 |
| 8 | **CompanionKit** — branded companion app per book | Non-fiction authors (via launch agencies) | A shipped launch asset; authors already spend $2k–$20k on launches | £2,500 setup + £99/mo | 55/70 |
| 9 | **CPD ReadLog** — reading → compliant CPD records | UK solicitors/accountants | Regulatory deadline relief; reading telemetry as evidence | £149/yr | 54/70 |
| 10 | **ScoutCoverage** — manuscript coverage overnight | Film/TV story departments | Replaces $80–$150/report human readers; confidentiality via no-backend | £79/report or £999/mo | 52/70 |
| 11 | **PackWorks** — license the 80 legally-QA'd summary packs | App builders, coaching platforms, newsletters | The clean-room editorial/legal regime, not the summaries themselves | £999/yr + £99/title | 52/70 |
| 12 | **GhostVoice** — expand interviews into voice-true chapters | Ghostwriters ($25k–$80k/manuscript) | Their production bottleneck + NDA-safe BYO-key privacy | £1,499/yr | 50/70 |

Consumer-side paid features (in-app, lower ticket, zero sales effort):
**Goal Decks** (L1#10, 51/70) as the obvious Plus-tier feature; **Lapse Repair**
(L1#9, 52/70) as a credit-metered transform; **CompsCrusher** (L2#10, 53/70)
at £149 per qualifying exam.

**Consensus first builds** (cheap, compounding, repeatedly flagged across lenses):
lock-screen/home widget for due cards (L1#1, L4#5), Share Extension import
(L4#1, L1#14), teach-back grading (L1#2), Kindle/Readwise highlights import
(L1#3, L4#4), shareable card images (L4#3), MCP library server (L3#1).

---

## Lens 1 — Reader Value & Retention

Context: the SRS engine already exists in code (`FSRSScheduler`, `MemoryStore`, `ReviewSession`/`ReviewLog` with an unused `score` field, `StreakState`, `NotificationScheduler.scheduleDailyReview`, `ReadingStats`) — the redesign doc's "not built yet" list is stale. These ideas therefore build on a live review loop, not a hypothetical one.

**Build first: #1, #2, #3.** #1 is the cheapest habit lever with the highest daily-touch payoff (the review loop exists; it just has no ambient surface). #2 is the single most differentiated retention feature — it turns review from recognition into recall, the field for it (`ReviewLog.score`) is already in the schema, and it runs free on-device. #3 changes the app's category: it stops being "an app for books I read here" and becomes "the place all my reading gets remembered" — that's the proprietary-personal-data moat that survives the AI-substitution test.

### 1. **Lock-Screen Memory — "Your next idea is always one glance away."**
A WidgetKit lock-screen/home widget + daily push showing today's due-card count and one full-bleed "Idea of the Day" card, deep-linking straight into `ReviewSessionView`. This is the missing habit surface: the FSRS queue, notification scheduler and gradient card design all exist, but the loop currently only fires if the user remembers to open the app — the widget makes the app the reminder. Roughly a week of work (a widget extension + an App Group snapshot of `MemoryStore.dueToday`), and it's the feature whose absence users literally cannot see, so churn looks like "I forgot," not "I chose to leave." **Score: 57/70**

### 2. **Teach-Back — "Prove you know it, in your own words."**
Instead of flip-and-grade flashcards, the user explains a due idea aloud or in text; the on-device Foundation Model scores fidelity against the card body and points out what was missed (Feynman technique as a product). Active recall with generation is the strongest known retention intervention, and it makes review feel like earned mastery rather than Anki drudgery — the schema already anticipates it (`ReviewLog.score: Int = -1`, teach-back hook in `MemoryStore.grade`), and `LLMRouter` gives it a free local path with zero marginal cost. No summary competitor (Blinkist, Headway, Deepstash) does this; it's the "one obvious promise" that justifies the Remember tab's existence. **Score: 57/70**

### 3. **Everything You Read, Remembered — Kindle highlights + camera capture → SRS decks.**
A share-sheet/file importer for `My Clippings.txt` and Readwise-style exports, plus VisionKit live-text camera capture for physical books, each highlight becoming a `KeyLearning` auto-enrolled via the existing `MemoryStore.enroll` path with an LLM cleanup pass. Most of a serious reader's reading happens *outside* this app; capturing it makes BookApp the system of record for their intellectual life — the classic Readwise wedge, and the one asset (years of personal highlights + review history) a frontier model can never substitute. Import pipeline, card models, and enrollment all exist; this is mostly parsing plus a share extension, and "import Kindle highlights" is a high-intent pull search term. **Score: 58/70**

### 4. **Previously On… — "Never re-read a chapter to remember where you were."**
When a book hasn't been opened in 3+ days, the reader opens with a 20-second recap of everything up to the current `ReadingProgress` locator — generated on-device from the text before the locator, with one tap to dismiss. Re-entry friction is the silent killer of book abandonment (the median reader abandons because resuming feels like work, not because the book is bad); this converts stale books back into active ones, directly moving retention. It's a small composition of existing parts: `ReadingProgress`, `Chunker`, `PromptTemplates`, `LLMRouter`. **Score: 55/70**

### 5. **Recall-Before-You-Act — the Remember and Act loops interleaved.**
On day N of a book's 14-day plan, the morning notification quizzes the specific card that underpins that day's `ActionItem` ("Before today's 2-minute-rule practice: what makes a habit attractive?"), and checking off the step grades the card. This fuses the app's two retention engines into one daily moment — knowledge reviewed at the moment of use is retained dramatically better, and it makes plans feel intelligent rather than generic. Pure orchestration: `ActionItem.dayOffset` + `KnowledgeCard` + `MemoryStore` + `NotificationScheduler` already exist; the work is a linking field and scheduling logic. **Score: 54/70**

### 6. **Review While You Drive — hands-free audio spaced repetition.**
The TTS engine reads each due card's title, pauses for the user to recall, reads the body, and takes a voice or steering-wheel-friendly grade ("got it" / "missed it") via `SFSpeechRecognizer` — a commute-length review session with zero screen time. It unlocks a second daily habit slot (car, gym, dishes) that no flashcard competitor occupies, and it reuses the word-highlighting TTS stack that is otherwise underemployed on cards. Sells the audio story ("your books, and your memory of them, on tape"). **Score: 53/70**

### 7. **Idea Threads — "Watch your books argue with each other."**
When a user saves a card, an on-device pass checks it against their existing saved cards and occasionally mints a *connection card* ("Deep Work's focus blocks vs. Flow's autotelic state — same mechanism, different frame"), building a personal cross-book knowledge graph over time. This is the compounding asset: after 10 books the app knows things about the user's reading that no fresh ChatGPT session can, which is exactly the proprietary-feedback-loop durability the framework demands. Builds on `detectedThemes`, `categoryTags`, and `KnowledgeCard`; connections enter the same review queue. **Score: 53/70**

### 8. **Checkpoint Quizzes — retrieval practice, not re-reading.**
Auto-generated cloze deletions and 3-option MCQs from each book's card deck, surfaced as a "boss quiz" when a book is finished and again at 1 week and 1 month. Testing effect beats passive review; it also gives finishing a book a satisfying end-state and gives lapsed books a re-engagement hook ("Your Sapiens checkpoint is ready — still got it?"). Generation is a `PromptTemplates` addition over existing `KnowledgeCard` bodies; results log into `ReviewLog`. **Score: 52/70**

### 9. **Lapse Repair — when you keep forgetting an idea, the book comes back to teach it.**
When a card hits N "Again" grades, the app auto-generates an expanded mini-chapter on just that idea (the elastic-expand engine pointed at one card instead of a whole book), offers it as a 3-minute read, then reschedules. This turns the app's core differentiator — elastic length — into a retention feature instead of a novelty, and it's the honest answer to "flashcards don't work when you never understood the idea." `BookVariant` expansion + `FSRSScheduler.lapses` already exist; this is a trigger and a prompt. **Score: 52/70**

### 10. **Goal Decks — "I want to get better at negotiation" becomes a 30-day curriculum.**
User states a goal; the app assembles a cross-book deck and interleaved plan from the 80-title catalog (Never Split the Difference + Influence + NVC cards, sequenced), with checkpoint quizzes between books. Goals are stickier than titles — they give the catalog a reason to be traversed rather than sampled, and they're the pivot plan's "custom tree" made cheap because curation happens over *existing* pack content, not new generation. **Score: 51/70**

### 11. **Memory Health — a retention dashboard, not a streak counter.**
A per-book and global view of your forgetting curve: retention rate from `ReviewSession.retention`, ideas at risk this week, strongest/weakest books — the code's own comment says retention is the headline metric, so make it the headline *screen*. Honest numbers ("you retain 84% of Atomic Habits") create the loss-aversion pull that streaks fake, and they're screenshot-shareable proof the app works. All data already exists in `ReviewLog`/`ReviewSession`/`ReadingStats`; this is a SwiftUI Charts screen. **Score: 51/70**

### 12. **The Sunday Letter — a weekly synthesis of what you read, saved, and retained.**
Every Sunday the on-device model writes a short editorial letter from the week's `ReviewLog`, new saves, and reading sessions — "this week you kept circling incentives; here's the through-line" — delivered as a notification and a beautifully typeset in-app page. Weekly reflection is a proven retention ritual (Strava/Spotify recaps) and it *demonstrates* knowledge compounding instead of asserting it; zero marginal cost on Foundation Models. **Score: 50/70**

### 13. **Evidence Journal — every completed plan step asks one line: "what changed?"**
Checking off an `ActionItem` optionally captures a one-sentence reflection; reflections accrue into a per-book "evidence timeline" and the best ones become review cards in the user's own words. Self-generated content is the stickiest content — deleting the app now means deleting proof of your own behaviour change, which is the strongest possible answer to "would you miss it?" A text field on an existing model plus a timeline view. **Score: 50/70**

### 14. **Import Anything — articles, newsletters, and PDFs become decks too.**
A share extension accepting URLs/PDFs/text that runs the existing import → `KnowledgeCardEngine` → enroll pipeline, so a great essay gets the same Remember treatment as a book. Books are a weekly moment; articles are a daily one — this multiplies the recurring trigger frequency the framework prizes, and the parser + card engine already handle the hard parts. Watch scope: keep it cards-only (no full reader chrome) to avoid becoming a read-it-later also-ran. **Score: 49/70**

### 15. **Read Together — shared decks and duo review via CloudKit sharing.**
Share a book's deck with a friend or book club; both review the same cards, see each other's retention, and nudge on lapse. It's the only idea on this list with a network effect (the framework's scarcest asset), and `CKShare` over the existing private-DB models keeps the no-backend promise intact. Higher build risk (SwiftData + CKShare is fiddly), which is why it isn't top-3 despite the strategic value. **Score: 49/70**

### 16. **The Forgetting Demo — onboarding that proves the problem in 48 hours.**
New users finish their first 15-minute summary, take a 5-question quiz (score: high), then get one notification two days later with the same quiz — the score drop *is* the sales pitch for the Remember loop, and it converts skeptics into daily reviewers better than any copy. Pure orchestration of idea #8's quiz engine plus `NotificationScheduler`; it's an activation feature that pays retention dividends forever. **Score: 48/70**

### 17. **Mnemonic Forge — every card gets a hook your brain can't drop.**
One tap on any struggling card generates a vivid image-story, acronym, or absurd association on-device ("Ulysses contract: picture yourself duct-taped to a mast labelled 'no phone before noon'"), stored on the card and shown before the answer. Mnemonics measurably cut lapse rates and make review delightful; it's a small `PromptTemplates` addition, and it deepens the moat of idea #2's teach-back loop. **Score: 47/70**

### 18. **Wrist Reps — a Watch complication for one-card reviews.**
A watchOS app showing due count as a complication and serving single-card recall (tap to reveal, crown to grade) — five-second review moments dozens of times a day. It extends idea #1's ambient-surface logic to the highest-frequency screen the user owns; scope it to card review only (no reading) so it stays a two-week build over a shared `MemoryStore` snapshot. **Score: 46/70**

### 19. **Where Did I Read That? — cited recall across everything you've saved.**
Natural-language search over highlights, cards, and learnings that answers with the exact passage, book, and locator ("the bit about naive realism — Thinking Fast and Slow, your highlight, ch. 3") rather than a chat response. It's genuinely useful mid-conversation and mid-writing, and it gets stronger as the personal corpus grows — but it flirts with the "chat with your notes" veto, so it must stay a citation-first search field, not an assistant. Embedding index over existing `Annotation`/`KeyLearning` text, on-device. **Score: 46/70**

### 20. **Your Year in Ideas — a shareable annual (and quarterly) wrapped.**
Auto-generated recap: books finished, ideas retained (real retention %, from `ReviewLog`), your top theme, your most-lapsed idea, your evidence-journal highlights — rendered as share-card images. Almost pure distribution (Spotify Wrapped's mechanic) with a retention kicker ("don't break the year"), built entirely from data the app already records; low daily-use value is why it ranks last, but it's the cheapest organic-growth asset on the list. **Score: 45/70**

---

## Lens 2 — Niche Monetisation & B2B

*Built on BookApp's actual assets: the elastic-length engine (`BookVariant` compress/expand), book→card pipeline (`KnowledgeCardEngine`), book→14-day-plan pipeline (`ActionPlanEngine` + write-only Calendar/Reminders export), on-device TTS with word highlighting, RSVP speed-reader, the clean-room summary content-ops process with mechanical legal tests (`SummaryPackTests`), and the no-backend/BYO-key privacy architecture.*

**Top 3 flagged: #1, #2, #3.**

### 1. ⭐ ReadAccess — "The reading accommodation that lets dyslexic and ADHD professionals keep up with any document their job throws at them." — **62/70**
Customer: dyslexic/ADHD employees and students whose assistive software is paid for by the UK's Access to Work grants and Disabled Students' Allowance — the government, not the user, writes the cheque, and assessors *must* recommend named tools. BookApp already ships the whole accommodation stack (word-synced TTS, RSVP pacing, elastic compression to a manageable length, restyle-to-plainer-prose), where incumbents like ClaroRead and Read&Write sell far cruder tools at £150–£400/licence through this exact channel. Price £299/licence (one invoice per assessment); distribution is becoming an approved supplier and briefing the ~500 DSA/AtW needs assessors who prescribe software daily. AI alone fails the channel test: assessors recommend certified, supported products with invoices and training, not "use ChatGPT" — the regulatory position and channel relationship are the moat.

### 2. ⭐ FranchiseFirst14 — "Turn your operations manual into a 14-day new-franchisee onboarding that lands in their Calendar." — **59/70**
Customer: franchisors (5–500 units) whose 200-page ops manuals go unread, causing brand-damaging inconsistency they already pay Trainual/Whale £1,000s a year to fix badly. The existing pipeline is a near-exact fit: import PDF → cards per procedure → 14-day checkable plan exported to the franchisee's own Calendar/Reminders, with completion visible to the franchisor. Price £2,990/yr per franchisor plus £49 per new franchisee (a true recurring moment: *every new signing*); distribution via franchise consultants, the BFA/IFA expo circuit, and franchise-broker referral fees. Generic AI can summarise a manual but can't be the accountable system-of-record for "did unit 47 complete food-safety onboarding" — the workflow, audit trail and franchisor dashboard are the product.

### 3. ⭐ CoachAssign — "Assign a book; your client actually does it — and you see every step they complete." — **58/70**
Customer: executive and leadership coaches (ICF has 60k+ members) who assign books between sessions and have zero visibility into whether clients read or applied anything — the gap that makes retainers churn. White-label the loop: coach picks a title, client gets the 15-minute Big Ideas edition, card deck, and a 14-day plan mapped onto their real calendar; coach gets a completion view to open the next session with. £79/mo per coach (unlimited clients) or £999/yr; distribution through ICF chapters, coach-training academies (they resell tools to graduates), and LinkedIn where coaches already perform. ChatGPT can summarise a book for a client, but it can't give the *coach* an accountability surface across clients — the two-sided workflow and coach community are the moat, and the analogues (CoachAccountable, Quenza, TrueCoach) prove coaches pay for exactly this shape.

### 4. SermonForge — "Every theology book becomes sermon-ready illustrations, small-group cards and a congregation follow-through plan." — **57/70**
Customer: pastors, who read more assigned non-fiction per week than almost any profession, face a hard weekly recurring deadline (Sunday), and demonstrably pay four figures for reading tools (Logos Bible Software) — an extreme-WTP tiny niche the skill explicitly hunts for. Book→cards becomes book→sermon illustrations and discussion questions; the 14-day plan becomes the congregation's application plan; the summary catalog becomes a pastoral reading library. £199/yr per pastor, £599/yr per church with small-group packs; distribution via pastor Facebook groups, denominational conferences, and Logos-adjacent podcasts. AI substitution is blunted by curated theological QA (the clean-room editorial process repointed), a denominationally-vetted catalog, and church-wide distribution of packs — trust is the scarce asset here.

### 5. CramShift — "Import your own exam textbook; get a countdown study plan and card decks calibrated to your test date." — **56/70**
Customer: USMLE, bar, CFA and actuarial candidates, who already spend $500–$3,000 on UWorld/Barbri/Schweser and maintain giant Anki decks by hand. The BYO-content architecture is the legal unlock: the *candidate* imports their licensed First Aid/Barbri PDF, and the pipeline turns it into cards plus a plan that back-schedules from their exam date into Calendar — no content licensing needed, unlike every incumbent. £149 per exam campaign (priced against a $1,000 retake, not a subscription); distribution is pull-based: r/medicalschool, r/CFA, the Anki add-on ecosystem, and "convert textbook to flashcards" search intent. Raw ChatGPT chokes on 800-page PDFs and won't maintain a scheduled, exam-anchored system across 12 weeks; the chunking pipeline, scheduling engine and per-exam templates are the workflow moat.

### 6. BoardroomBrief — "Your firm's assigned reading, on every employee's phone, with nothing ever touching a vendor server." — **56/70**
Customer: L&D leads at law firms, consultancies and banks running leadership reading programs, currently paying getAbstract/Blinkist Business $10–30/seat/yr for summaries nobody applies — and whose security teams veto most AI tools. Two differentiators incumbents can't match: the Act layer (each assigned title becomes a tracked 14-day application plan) and the no-backend architecture (on-device models + the firm's own enterprise Anthropic key, so confidential annotation never leaves the estate). £5,000–£25,000/yr per firm; distribution via L&D communities (CIPD, LinkedIn), HR-tech marketplaces, and the CISO-friendly pitch that wins deals getAbstract loses. The moat is the deployment posture plus the legally-QA'd clean-room catalog — assets a chatbot doesn't have.

### 7. QuotaReader — "Turn the sales book your VP just assigned into daily drills your reps actually run — with manager visibility." — **55/70**
Customer: sales enablement leads who assign Challenger/Gap Selling/SPIN to the whole team every kickoff (a reliable annual recurring moment) and watch nothing change. Cards become objection-handling drills, the 14-day plan becomes call-prep micro-actions exported into rep calendars, and managers see completion beside pipeline reviews. £49/rep/yr with a 20-seat minimum, sold in kickoff season; distribution via sales-enablement Slack communities, the SES conference, and partnerships with the methodology training houses themselves (they need reinforcement tooling — analogues: SalesHood, Mindtickle's reinforcement modules). AI alone can summarise the book; it can't be the manager-visible reinforcement system woven into the team's CRM cadence.

### 8. CompanionKit — "A branded companion app for your book — cards, audio and a 30-day reader plan — live before launch day." — **55/70**
Customer: non-fiction authors, who spend $2k–$20k on launch assets and know a companion app drives reviews and back-of-room sales (James Clear's habit app, Atomic Habits' cheat sheets are the proven pattern). The whole pipeline is the factory: author's own manuscript (clean rights) → branded card deck, action plan, TTS audio edition and elastic short version as a lead magnet. £2,500 setup + £99/mo hosting per title, sold through book-launch agencies, ghostwriting firms and publishing consultants who bundle it into launch packages. AI can't substitute because the deliverable is a *shipped, branded, App-Store-present artifact* with the author's blessing — operational execution and the agency channel are the business.

### 9. CPD ReadLog — "Every hour you read becomes a compliant, reflective CPD record — written for you, verified by your reading." — **54/70**
Customer: UK solicitors and accountants under outcome-based CPD regimes (SRA's "reflect and record" requirement) who genuinely read for work but face an annual scramble to reconstruct reflective statements — a classic "it only takes 15 minutes" loop attached to a regulatory deadline. The app already measures real reading (position, time, highlights); add generated reflective statements per title mapped to the SRA competence framework, exportable as the annual record. £149/yr per professional; distribution via pull ("SRA CPD record template" search), Law Society local groups, and firm-level deals. AI alone can't attest *that you actually read it* — the on-device reading telemetry is proprietary evidence a chatbot cannot fabricate credibly.

### 10. CompsCrusher — "Your 120-book qualifying-exam list, compressed to a schedulable 90-day mastery plan." — **53/70**
Customer: PhD students facing comprehensive/qualifying exams — a tiny, findable niche with acute, deadline-bound pain (fail twice, leave the program) and a documented workaround of frantic note-sharing Google Docs. Import the reading list; elastic compression produces tiered summaries (skim/standard/deep per book's importance), cards feed daily review, and the plan back-schedules to the exam date. £149 one-off per exam (students pay for GRE prep at this level; supervisors sometimes expense it); distribution via r/PhD, GradCafe, department mailing lists and "comprehensive exam study plan" search. Durability comes from the multi-book campaign workflow and scheduling — one-shot chat can summarise a book but won't orchestrate 120 of them against a date.

### 11. ScoutCoverage — "Full-manuscript film/TV coverage in 20 consistent pages, overnight, for every submission." — **52/70**
Customer: production-company story departments and book-to-screen scouts who pay human readers $80–$150 per coverage report and still drown in submissions — a hidden API where customers already believe they're buying a document, not a person. The compression engine repointed: manuscript in, standardised coverage out (logline, synopsis at chosen depth, comps, adaptability notes), with the elastic control letting an exec expand any act to full detail. £79/report or £999/mo unlimited for prodcos; distribution via scout newsletters, the AFM/Berlinale market circuit, and literary-scout LinkedIn. Confidential manuscripts make the no-backend/BYO-key posture a real selling point agencies' legal teams care about — that plus format trust beats raw Claude.

### 12. PackWorks — "License 80 legally-QA'd book-summary packs — summaries, card decks and action plans — as drop-in JSON." — **52/70**
Customer: newsletter operators, coaching platforms, corporate-wellness apps and white-label app builders who want a Blinkist-style content layer but can't fund the editorial/legal pipeline. The asset is already built and mechanically tested (`SummaryPacks/*.json` + `SummaryPackTests` + the two-agent editorial/legal review process); sell it as a content API plus a per-title generation service for custom catalogs. £999/yr base licence + £99/title custom; distribution via IndieHackers, app-agency networks and "book summary API" search (pull with near-zero competition). The moat is exactly what the AI-substitution test demands: proprietary, legally-reviewed data — anyone can generate summaries, but shipping them commercially requires the QA/attribution regime this repo has productised.

### 13. Encore — "Your keynote doesn't end at applause: every attendee leaves with your 14-day implementation plan on their phone." — **51/70**
Customer: keynote speakers and corporate trainers (most have a book) whose clients increasingly demand proof of behaviour change after the talk. White-label: attendees scan a QR, get the speaker's branded card deck and a 14-day plan exported to their own calendars; the speaker sells the follow-through to the client as a premium line item. £999/yr per speaker + £2/attendee; distribution via speaker bureaus (they take a cut and push it into every booking) and NSA/PSA speaker associations. The recurring moment is every booking; the bureau channel and the branded artifact are what generic AI can't replicate.

### 14. Exec90 — "Every new executive's first-90-days reading list, turned into a week-by-week plan their coach can see." — **51/70**
Customer: onboarding/transition coaching firms and CHROs who hand new VPs "The First 90 Days" plus 4 industry books during the highest-stakes recurring moment in corporate life (executive failure costs 2–3x salary, so budgets are pre-approved). Bundle curated summary editions, cards, and a plan interleaved with the exec's actual calendar; sell to the coaching firm, not the exec. £499 per onboarding seat, sold in packs of 10; distribution through executive-search firms (they gift it post-placement as retention insurance) and transition-coaching boutiques. Analogous to how Michael Watkins' own Genesis licenses First-90-Days tooling — proof of B2B willingness to pay; the coach-visible workflow beats a chatbot summary.

### 15. Backlist Studio — "Wake up your backlist: a companion card deck and reader plan for every title, generated from the books you own outright." — **50/70**
Customer: mid-size publishers sitting on thousands of backlist titles with zero marketing budget, where a 2% sales lift on owned IP is pure margin. Because the publisher *owns the rights*, the pipeline runs unconstrained: official summaries, decks, plans and TTS-drafted audio editions as retailer-page extras and newsletter content. £5,000 pilot (50 titles) then £199/title; distribution via publishing trade press (The Bookseller), London/Frankfurt book fair meetings, and independent-publisher associations. Slow sales cycles cap the score, but the analogues (publisher-services firms like Bookwire, Supadu) show the channel exists and AI-alone fails on rights-safe production discipline at catalog scale.

### 16. GhostVoice — "Expand a 5-page interview into a 50-page draft that still sounds like your client." — **50/70**
Customer: ghostwriters and book coaches charging $25k–$80k per manuscript, whose bottleneck is precisely what the expand + restyle engines do: growing sparse interview material into chapters while preserving a specific person's voice. Sell it as a private studio (BYO API key keeps client material off any vendor server — an NDA-critical feature): voice-profile per client, chapter-level expansion, consistency checks across the manuscript. £1,499/yr; distribution via the Gathering of the Ghosts conference, AAG (ghostwriters' association) and ghostwriting agencies. AI substitution risk is the ceiling here — they can prompt Claude — so the defensible layer is the voice-profile persistence, manuscript-scale consistency tooling, and confidentiality posture.

### 17. ClubKit Pro — "Run a workplace book club that HR will fund: facilitator guide, card decks and completion stats per cohort." — **50/70**
Customer: the operators of corporate book clubs — ERG leads, culture teams, and agencies like PBC Guru (which charges companies $1k+/club/quarter, proving the budget). Each title generates a facilitator kit: session-by-session discussion guides from the card deck, elastic pre-reads for members short on time, and a completion view that justifies the budget to HR. £299/club/quarter self-serve or white-labelled to book-club agencies at £999/mo; distribution via HR/People-ops communities and the agencies themselves. The recurring moment (every quarterly title) and the facilitator workflow are what a one-off ChatGPT summary can't sustain.

### 18. AdviserShelf — "Gift clients a book they'll actually finish — with your firm's branding on every card." — **49/70**
Customer: financial advisers, who already spend heavily on client-engagement content (Snappy Kraken et al. at $200–$500/mo) and habitually gift titles like *The Psychology of Money*. White-label the summary edition + card deck + a "money habits" 14-day plan under the adviser's brand, delivered to clients as a touchpoint that generates conversation and referrals. £129/mo per adviser; distribution via adviser marketing communities (XYPN, Kitces) and compliance-approved content marketplaces. Compliance review (FINRA/FCA financial-promotion rules) is the tax and the moat: pre-approved, attributed, legally-QA'd packs are exactly what an adviser can't get from raw ChatGPT.

### 19. CoursePress — "Your book, restructured into a cohort course curriculum — modules, exercises and a student action plan — in a day." — **49/70**
Customer: experts turning a published book into a paid cohort course (the Maven/Kajabi economy), currently paying instructional designers $3k–$10k or stalling for months. The pipeline maps cleanly: chapters → modules, cards → lesson exercises, the 14-day plan → the student practice track, elastic expansion fills thin sections. £299/book self-serve, £1,499 with editorial polish; distribution via creator-economy communities, Maven's instructor pipeline, and "turn my book into a course" search intent. AI substitution pressure is real, so the durable layer is the packaged output formats (LMS-ready exports) and partnerships with course platforms that recommend it at the exact recurring moment (every new instructor).

### 20. SlushCompress — "Every query-pile manuscript, reduced to a consistent 3-page verdict memo before your Monday meeting." — **48/70**
Customer: literary agencies and acquisition editors triaging hundreds of submissions monthly with unpaid interns — an expensive human loop hidden behind "we'll get to it". Standardised compression memos (premise, voice sample analysis, comps, market note) at chosen depth, run under the agency's own key so unpublished manuscripts never touch a third-party server. £299/mo per agency; distribution via Publishers Marketplace, agent Twitter/Bluesky, and AALA channels. Scores lowest because agents are notoriously low-budget and culturally AI-averse — the pain is real but the willingness-to-pay is the weakest of the twenty; included as the gateway wedge to the higher-value ScoutCoverage market (#11).

**Cross-cutting note for the top 3:** all three monetise assets the codebase uniquely already has — #1 sells the *reading surface itself* through a government-funded procurement channel; #2 and #3 sell the *Act pipeline* (book→scheduled, verifiable behaviour) to buyers whose economics depend on other people finishing what they were assigned. None survive as "ask ChatGPT instead" because the product in each case is the accountability workflow, the channel certification, or the audit trail — not the summary.

---

## Lens 3 — AI-Native & Agent-First

*What became possible in the last 24 months — on-device inference at zero marginal cost, whole-book context windows, MCP agent-to-agent workflows, human-grade voice, production multimodal, structured outputs — mapped onto BookApp's existing surface: `LLMRouter` (Apple FM → MLX → Claude), the map-reduce `Chunker`, FSRS `ReviewLog`s, `TeachBackGrader`, `ActionItem` completion state, and a corpus of books + highlights + cards living in the user's own iCloud. Top 3 flagged ⭐.*

### 1. ⭐ **"Your library, served to Claude" — a local MCP server that exposes your reading corpus, cards, and highlights to any agent.**
The structural change is MCP as the lingua franca for agent-to-agent workflows: agents now *consume* knowledge sources, and a personal library with locators, key learnings, and plan-completion state is exactly the proprietary context they lack. Ship an on-device (or iCloud-Drive-backed, since variants are already plaintext files in `BookApp/<bookID>/`) MCP server with tools like `search_library`, `get_highlights(book)`, `get_saved_cards(topic)`, `what_do_I_believe_about(x)` — Claude Desktop, Claude Code, and future agents become customers of your reading, citing *your* annotated editions rather than generic training data. Survives Stage 11 because the moat is the corpus itself (Stage 17: exclusive data pipeline + integrations), and it gets strictly more valuable as agents proliferate — Stage 12's "the buyer becomes another AI" literally. **Score: 62/70**

### 2. ⭐ **"Photograph any page, any shelf — it's in your library in 10 seconds."**
Vision models crossed production quality: a phone photo of a physical book page, a shelf, or a bookstore table can now be OCR'd, identified, and structured reliably. Extend `ImportService` with a camera path — shelf photo → structured output of every spine → one-tap "add to Read list" with Big Ideas editions matched from the catalog; page photo → highlight capture that becomes an `Annotation` + `KnowledgeCard` with the physical book as source. This bridges the 95% of reading that happens on paper into the app's Remember/Act loop, and the physical-world integration (Stage 17) is something a chat window can't replicate — the value is the *pipeline into your existing corpus*, not the OCR. **Score: 59/70**

### 3. ⭐ **"The app that learns what you actually retain — and rewrites your books to match."**
BookApp already owns a feedback loop no frontier model has: `ReviewLog` (per-card FSRS grades), `TeachBackGrader` scores, `ActionItem` completion rates, and reading-position telemetry. Close the loop — on-device Apple FM (free inference) periodically mines which card *kinds*, chapter styles, and summary lengths *you* retain, then biases `PromptTemplates` and the compression ratio per user ("you retain Mental Models at 84% but Habits at 41%; compressing denser and generating more model-type cards"). This is Stage 17's "proprietary feedback loop" in its purest form: the personalization corpus lives in your private CloudKit, can't be exported to a competitor, and every model improvement makes the mining better. **Score: 58/70**

### 4. **"Talk to the author on your commute" — hands-free voice conversations grounded in the exact book you're reading.**
Human-grade voice models (and Apple's on-device speech stack) turned TTS from narration into dialogue; long context means the *whole book* sits in the prompt (already prompt-cached via `cache_control: ephemeral`, so follow-up turns cost ~10%). Upgrade the TTS feature from playback to a Socratic mode: pause the audiobook, ask "wait, how does this square with chapter 2?", get an answer in the book's own frame, resume. Survives substitution because the session is grounded in your variant, your position (`ReadingProgress.locator`), and your prior highlights — context a raw chatbot doesn't have. **Score: 55/70**

### 5. **"Every new book is read against everything you've already read."**
Whole books fit in context now, and the map-reduce `Chunker` already exists — so on import, run a cross-corpus pass: "Kahneman contradicts the Atomic Habits card you saved in March; here's the tension card." Synthesis cards (`kind: .connection`) linking new chapters to existing saved `KnowledgeCard`s turn a pile of summaries into a personal knowledge graph. AI-substitution-proof because the input is the user's private saved-card history; the graph compounds with every import (network effect within one user's data). **Score: 55/70**

### 6. **"Your 14-day plan, supervised by an agent that checks in."**
Structured outputs + scheduled agent runs mean the Act loop no longer ends at Calendar export. An in-app coach agent reads `ActionItem` completion state nightly (all local — SwiftData), notices day-4 stalls, and uses on-device FM to regenerate the *remaining* plan around what actually happened ("you skipped both morning sessions; here's the evening-shifted version"). Plan-adherence data becomes the proprietary training signal for better plans (Stage 17 feedback loop); a generic assistant can generate a plan but can't observe your completion history. **Score: 54/70**

### 7. **"Ask for a book that doesn't exist yet" — on-demand Big Ideas editions generated to your spec.**
Long context + Opus-class long-form quality make clean-room synthesis editions generatable on request, not just pre-seeded via `SummaryPackLoader`. User asks "the big ideas of *Thinking in Systems*, 20 pages, styled for an engineer" — the pipeline (existing map-reduce + style-transfer templates) produces a catalog-quality edition with attribution, cached for the next requester. The catalog becomes a demand-driven data pipeline the app owns; frontier models can summarize, but they don't own the legally-vetted format, the card/plan derivations, or the distribution. **Score: 53/70**

### 8. **"Weekly 10-minute podcast of what you read, highlighted, and forgot."**
Voice models became human, and the raw material — this week's `Annotation`s, lapsed FSRS cards, plan progress — is already structured in SwiftData. Generate a two-voice weekly recap script on-device, render with premium system voices (or user's Claude key for script quality), delivered as a private podcast episode in the Files-app folder. NotebookLM proved demand; BookApp's version is grounded in *your* week of data, not one uploaded document, so it survives substitution via the proprietary weekly pipeline. **Score: 52/70**

### 9. **"Your cards answer before you search" — a Spotlight/Siri/App Intents layer over your knowledge deck.**
App Intents + on-device models let the OS itself become the client: "Siri, what did that negotiation book say about anchoring?" resolves against your saved `KnowledgeCard`s and `KeyLearning`s without opening the app. This is agent-first at the OS level — Apple Intelligence becomes the buyer of your structured cards. Zero marginal inference cost, deepens lock-in to the corpus, and rides every Siri improvement (more valuable as models improve). **Score: 51/70**

### 10. **"Import anything with words in it."**
Multimodal parsing means the `BookParser` chain (EPUB/PDF/MOBI-stub) can grow a universal fallback: scanned PDFs, photographed handouts, web-article share-sheet captures, even audio (lecture → transcript → book-like object). Every artifact enters the same Read/Remember/Act pipeline and iCloud layout. The moat isn't the OCR (commodity) — it's that everything lands in one FSRS-scheduled, plan-generating corpus. **Score: 50/70**

### 11. **"Teach-back gets ears" — spoken teach-back grading with on-device speech + FM.**
On-device speech recognition plus Apple FM makes the existing `TeachBackGrader` voice-native: explain the card aloud while walking; local model grades fidelity against the card and logs the score to `ReviewLog`. No cloud call, no privacy cost, and the spoken-explanation transcripts become another private retention signal feeding idea #3. Small feature, but it converts the app's most defensible loop (retention data) into a daily habit surface. **Score: 50/70**

### 12. **"An agent negotiates your reading queue with your calendar."**
Agents can now plan across tools: a queue agent reads your (write-only today — would need opt-in read) calendar density, commute patterns, and current `ReadingProgress`, then assigns each queued book a *format*: "Tuesday: 22-min compressed audio of ch. 3–4; Saturday: full-text deep session." Uses existing variants + TTS + RSVP as the actuator set. Survives substitution because the scheduling policy is trained on your completion telemetry, not generic advice. **Score: 49/70**

### 13. **"Two books argue; you moderate."**
Long context fits *two* whole books, so generate structured debates: Deep Work vs. anti-hustle titles, rendered as a card deck of claims/rebuttals with locators into both sources, optionally voiced as a two-speaker audio dialogue. Novel content form that only exists because of context-window growth; grounded in the user's owned variants so outputs cite pages they can jump to. Weaker moat (a chatbot can approximate it) but strong engagement and it feeds the connection-graph in #5. **Score: 47/70**

### 14. **"Your reading corpus as a writing copilot."**
Expose the library to the user's *other* work: a share-sheet/keyboard extension where drafting an email or doc lets on-device FM pull the three most relevant saved cards ("you're writing about pricing — your Hormozi cards say…"). The corpus becomes ambient infrastructure across the OS rather than an app you remember to open. Substitution-proof via the private card store; distribution-native via share sheet. **Score: 47/70**

### 15. **"Book club of one, agent of many" — publish a redacted card pack as an MCP-consumable artifact for friends' agents.**
Agent-to-agent sharing: export a chosen deck (cards + attributions, never book text — the license already forbids content redistribution) as a signed pack another BookApp user's library *or agent* can subscribe to. Creates the app's first network effect (Stage 17): decks improve as reviewers' FSRS data flags which cards actually stick. Moderate legal care needed, but cards-as-original-prose are the clean-room unit the catalog already established. **Score: 46/70**

### 16. **"Point the camera at a bookstore table; get verdicts from your own values."**
Multimodal + the corpus: shelf photo → title identification → for each, an on-device brief scored against your `detectedThemes`, saved cards, and past DNF (abandonment) telemetry — "80% overlap with three books you've read; skip" or "fills your negotiation gap; buy." Purchase-moment utility a generic model can't give because it doesn't know what you've read and retained. **Score: 46/70**

### 17. **"Every highlight becomes a testable claim, monitored over time."**
Structured outputs turn `Annotation`s into typed claims (prediction / statistic / recommendation); a periodic background agent re-evaluates time-sensitive ones ("this 2019 stat has since reversed — card updated with a correction note"). Continuous monitoring (Stage 11's explicit moat category) over a private claim base; the app becomes a living errata layer on your library rather than a static archive. Needs a network fetch path (today the only network call is Anthropic), so scope creep risk. **Score: 45/70**

### 18. **"Compression that knows what you already know."**
Personalized elastic length: before compressing a new book, prepend a profile distilled (on-device) from your saved cards — the model skips re-explaining concepts you've mastered and dwells on gaps, yielding a 12-page edition *for you* instead of a 20-page edition for everyone. Pure prompt-engineering on the existing `TransformationEngine`, cost-neutral via prompt caching, and the personalization input is unexportable private data. **Score: 45/70**

### 19. **"Read the graph, not the shelf" — an auto-built visual map of your intellectual territory.**
On-device embedding/clustering of all cards and themes renders a zoomable map: dense clusters (read enough), frontier edges (adjacent unknowns), with tap-through to generate a Big Ideas edition (#7) for any gap node. Turns the corpus into a navigation instrument and a native demand-generator for the catalog. Visualization itself is commodity; the underlying private graph is not. **Score: 43/70**

### 20. **"Hand your agent a reading brief; wake up to a curriculum."**
Computer-use / research agents can now assemble source lists: user states a goal ("get competent at pricing strategy in 3 weeks"), a cloud agent (user's own key) proposes a sequence of catalog editions + imports, pre-generates the compressed variants, card decks, and a merged 21-day `ActionItem` plan across books. The app orchestrates rather than performs — but the output lands in owned infrastructure (FSRS, planner, calendar export) that a chat transcript can't operationalize. Riskiest substitution profile of the twenty; the moat is entirely in the downstream loop. **Score: 42/70**

**Top 3 rationale:** #1 (MCP library server) is the purest Stage 12 play — agents as customers of data only this app holds, near-zero build cost given variants are already plaintext in iCloud Drive. #2 (camera import) is the physical-world integration that widens the data moat to all reading, not just digital. #3 (retention-tuned generation) is the deepest Stage 17 asset: a per-user feedback loop — FSRS grades → prompt bias → better retention → more grades — that compounds privately and appreciates with every model generation.

---

## Lens 4 — Distribution, Ecosystem & Growth

*Ranked best-first. Top 3 flagged ⭐.*

### 1. ⭐ Share Extension: "Send anything to BookApp" (52/70)
**Any article, PDF, newsletter, or web page becomes a summary, a card deck, and a 14-day plan — from the share sheet of every other app.**
This is the single highest-leverage distribution surface: the app stops competing for open-intent ("I'll go read now") and instead intercepts the recurring moment users already have dozens of times a week — *finding* something worth reading in Safari, Mail, Substack, or Slack. Architecturally it's cheap: the import pipeline (EPUB/PDF parsing → `Book` → `LLMRouter` → `KnowledgeCardEngine`/`ActionPlanEngine`) already exists; a Share Extension just needs an App Group handoff file (the `WidgetSnapshot` pattern, reused) plus an HTML-to-text readability pass. It also unlocks App Store keywords ("read later," "article summarizer") with far higher search volume than "epub reader," and turns every browsing session into a re-engagement trigger.

### 2. ⭐ App Intents + Siri: "Hey Siri, quiz me" / "Play my book" (50/70)
**First-class App Intents make BookApp scriptable, Siri-visible, and Spotlight-indexed — every catalog title and saved card becomes an OS-level entity.**
Ship `AppIntents` for: start review session, play current book (TTS), show today's plan step, add a card, "summarize my clipboard." Payoff is threefold: (a) Spotlight/Siri Suggestions surface "The Big Ideas in Atomic Habits" when the user types "atomic habits" *on their phone* — free, permanent discovery; (b) Shortcuts-gallery automations ("quiz me when my morning alarm stops," "play my book when CarPlay connects") create recurring moments the app doesn't have to earn; (c) with Apple Intelligence, intents make BookApp a target for system-level assistant actions — a timing bet (Stage 1) most reading apps haven't made. Pure Swift, no backend, ~days of work per intent given the engines exist.

### 3. ⭐ Shareable card images — one idea per card, iMessage/Instagram-native (49/70)
**Every knowledge card exports as a beautiful, watermarked image — the atomic unit of book-nerd social currency.**
The cards are already full-bleed, gradient-coded, and designed to be screenshot-worthy; add `ImageRenderer` export with book attribution + "made with BookApp" + App Store link (QR or App Clip link). This is the Deepstash/Readwise growth loop: people *love* posting one-idea-per-image quotes to Instagram, X, and group chats, and each share is an ad drawn by the user. Legal posture is strong because cards are the app's own clean-room prose with attribution (reinforce the "Independent summary" caption per `docs/content-legal-review.md`). Feasible in a week (`ShareCoordinator.swift` already exists for learnings); the recurring moment is every swipe session.

### 4. Kindle highlights + Readwise import (47/70)
**Paste your `My Clippings.txt` or Readwise export and every highlight you've ever made becomes cards, learnings, and review material.**
"Kindle highlights export" is a heavily-searched pull query (Stage 8) with a devoted audience that already gathers on r/kindle, r/ObsidianMD, and Readwise's community. Import is a text/CSV parser feeding the existing `KeyLearning`/`KnowledgeCard` models — no legal issue since it's the user's own annotations of books they own. It instantly seeds a new user's Saved tab with years of personal content (cold-start solved, switching cost created), and it's the strongest wedge against Readwise Reader for users who want on-device/no-subscription.

### 5. Interactive lock-screen & Home-Screen widget: "Today's card" (46/70)
**A daily knowledge card on the lock screen — tap to grade recall, swipe into review — the Duolingo streak surface without opening the app.**
The widget target and App Group snapshot plumbing exist (`BookAppWidget/`, `WidgetSnapshot.swift`); extend the JSON payload with the due card of the day and add `accessoryRectangular`/`accessoryInline` families plus interactive `Button(intent:)` for "Got it / Show me." This converts the planned SRS system into a 5-second recurring moment users see 80+ times a day on their lock screen. Retention feature first, but retention *is* distribution on the App Store (rankings weight engagement).

### 6. Web companion: "The Big Ideas in [Book]" pages for SEO pull (45/70)
**A static site publishing a teaser slice of each of the 80 summaries — capturing "summary of Atomic Habits"-class search volume and funneling to the app.**
"Summary of X" is textbook Stage 8 pull; Blinkist built its funnel on it. The 80 `SummaryPacks/*.json` files are the CMS — a static-site generator turns each into a page with 3 free cards + first section + App Store smart banner. Constraints from `docs/content-legal-review.md` apply and are manageable: publish *partial* teasers (weaker market-substitution exposure than the full in-app summary), carry the canonical "independent summary, not affiliated" disclaimer above the fold, keep the buy-the-book link, and route through counsel first. Marginal cost near zero; compounds monthly. Docked points for legal review dependency and for softening the "no web presence" simplicity.

### 7. CarPlay + enhanced background audio: the commute channel (44/70)
**Every summary is a 15-minute drive — BookApp becomes a CarPlay audio app and owns the commute.**
TTS with word-highlighting and lock-screen controls already work; adding the CarPlay audio-app entitlement and a `CPListTemplate` of "continue listening / 15-min big ideas" makes the daily commute a recurring consumption moment competitors gate behind subscriptions (Blinkist audio is paid; this is free, on-device). CarPlay's app catalog is small — being *in it* is discovery. Risk: CarPlay audio entitlement approval and making synthesized voices feel premium (Personal Voice / premium system voices mitigate).

### 8. Book-club decks: share a deck + reading plan via link (44/70)
**One tap turns any title into a book-club kit — the deck and the 14-day plan shared as a file any group chat can open.**
Export a `.bookclub` document (JSON of cards + plan, no summary text → clean legal posture) shared through iMessage/AirDrop; recipients without the app hit the App Store via a universal-link landing page. Book clubs are a natural K-factor >1 unit: one member adopts, ten install to follow the same 14-day plan, and the plan's daily steps give the whole group a synchronized recurring moment. Needs no backend if the payload travels as a file/CloudKit share. This is the app's most plausible word-of-mouth engine given zero ad budget.

### 9. Apple Watch app: review reps + listening remote (42/70)
**Grade three flashcards from your wrist while the kettle boils — the smallest possible daily learning rep.**
A watchOS target showing due cards (tap-to-grade), the current plan step, and TTS playback controls. Cards' one-idea-per-screen format is unusually watch-native. Creates micro-moments (queue, elevator, walk) that anchor the streak, and Watch presence is an App Store editorial differentiator ("Full Apple ecosystem" story: iPhone, iPad, Watch, widgets, CarPlay). Moderate effort: needs a trimmed SwiftData/App Group sync path, but read-mostly data keeps it simple.

### 10. App Store optimization overhaul: rename around the job (42/70)
**Stop selling "BookApp — Read, Listen, Adapt"; sell "Big Ideas — Book Summaries & Action Plans."**
The current name/keywords (`AppStore/listing.md`) target "epub reader" — a crowded, low-intent field — while the redesigned product's job is summaries + retention, where search intent ("book summaries," "blinkist alternative," "non-fiction in 15 minutes," "book action plan") is richer and the free/no-subscription angle is a killer differentiator in reviews. Includes: subtitle carrying "summaries," screenshot order led by cards + plans (not the empty library), and In-App Events for new catalog drops. Zero code; the highest ROI-per-hour item on this list, but capped because ASO alone doesn't create a loop.

### 11. Monthly catalog drops as an event: "10 new Big Ideas every month" (41/70)
**Turn summary-pack releases into a recurring content calendar — push notification, In-App Event card on the App Store, themed collections.**
The `SummaryPackLoader` is already idempotent-per-slug and loads update-shipped packs for existing users, so monthly drops are pure content ops. Each drop is: an App Store In-App Event (free featuring surface), a "New this month" shelf, a notification, and a social post of the collection's best card. Converts a static 80-title catalog into a live channel with a built-in reason to return monthly — the Netflix cadence applied to summaries.

### 12. Goodreads / StoryGraph shelf import (40/70)
**Import your "read" and "want-to-read" shelves — BookApp instantly maps them to catalog summaries and builds your review deck from books you already finished.**
Goodreads CSV export is a well-known artifact users actively search how to use ("goodreads export" — pull). Matching shelf titles against the 80-pack catalog personalizes onboarding ("You've read 12 of these — want the cards to make them stick?") and creates the killer retention pitch: *remember the books you already read*. CSV parsing + fuzzy title match, one week of work; also generates a "we should add X" demand signal for catalog planning. StoryGraph's community (r/thestorygraph) is small, vocal, and underserved — a Stage 3 niche.

### 13. "Idea of the Day" push + widget as public feed (39/70)
**One great idea from a great book, every morning at 8am — the app's own daily editorial voice.**
A rotating daily card from the 945-card catalog, surfaced simultaneously as a notification, the widget, and a shareable image. This is the recurring moment that habit apps live on (Imprint/Motivation-quotes DNA) and it feeds idea #3's share loop with fresh daily ammunition. Local notifications + a deterministic date-seeded pick means zero backend. Scores lower alone than in combination — it's the drumbeat that makes widgets and shares fire daily.

### 14. App Clip: play one card deck instantly from a QR/link (38/70)
**A shared card links to an App Clip that plays the whole deck in-place — no install wall between "my friend sent me this" and "this is delightful."**
Every shared card image (#3) and book-club kit (#8) carries a link that opens a <10MB App Clip rendering that title's deck with a persistent "Get the full app" affordance. App Clips are underused, demo beautifully, and remove the single biggest drop-off in mobile K-factor loops (the install). Feasible: bundle only the deck renderer + one pack fetched from the same static host as idea #6. Depends on ideas 3/6/8 existing, hence mid-rank.

### 15. Open-source the summary-pack format + community pack registry (37/70)
**Publish the pack JSON schema and validator; let anyone author, share, and sideload "Big Ideas" packs for books, courses, or internal docs.**
A Stage 15 open-source play: the schema (`SummaryPacks/<slug>.json` + `SummaryPackTests` validation rules) becomes a public spec on GitHub, with a CLI validator and a community index repo. Developers and educators gather on GitHub (Stage 6); packs made for niche audiences (theology reading groups, MBA syllabi, company onboarding docs) become distribution the founder never authors. Sideloaded packs are user content — cleaner legally than shipping them. Costs: curation/moderation stance needed, and it feeds competitors the format; hence not top-tier.

### 16. Reading-year "Wrapped" — shareable annual/quarterly stats card (36/70)
**"You read 23 books' worth of big ideas, kept 148 cards, completed 4 plans" — a Spotify-Wrapped moment for learning.**
`ReadingStats.swift` already tracks activity; render an annual (and quarterly, for more moments) share card with `ImageRenderer`. Wrapped-style artifacts reliably spike social sharing and App Store installs in December — a predictable, calendar-anchored growth event a solo founder can schedule. Low effort, but inherently episodic (a few spikes a year, not a loop), so mid-pack.

### 17. Calendar/Reminders as a Trojan surface: branded plan exports (35/70)
**Every exported plan step carries a deep link back — "Day 6: 2-min habit stack · Open in BookApp" — so the user's own calendar becomes a re-engagement channel.**
`PlannerService` already writes events/reminders; adding a `bookapp://plan/<id>` URL and a consistent "BookApp · The Big Ideas in X" naming makes 8–10 daily calendar hits per active plan into taps back into the app — and makes plans *visible to anyone the user shares a calendar with* (mild ambient exposure). Nearly free to build; scores modestly because reach is bounded by existing users' calendars.

### 18. "Turn this newsletter into a deck" — email-in pipeline via Shortcuts (34/70)
**A published Shortcut ("Deck This") that grabs the current Mail/Safari selection and hands it to BookApp's importer — distributed through the Shortcuts Gallery and r/shortcuts.**
Rather than a mail backend (violates no-backend ethos), ship curated Shortcuts built on the App Intents from idea #2 and publish them via iCloud links in the Shortcuts community, r/shortcuts, and MacStories — a genuine Stage 6 watering hole of exactly the automation-literate readers who evangelize apps. Zero marginal engineering beyond #2; capped score because the audience is enthusiast-sized.

### 19. StoreKit-triggered review prompts at "earned moments" + referral card back (33/70)
**Ask for a rating exactly when the user completes a 14-day plan or a 7-day review streak — the two moments of maximum earned goodwill.**
Ratings volume/velocity is the strongest App Store ranking input a free app controls. Wire `requestReview` to plan-completion and streak milestones (never on launch), and pair the completion screen with a pre-composed share card ("I finished the Atomic Habits plan"). Trivial to build; low ceiling alone, but it multiplies every other idea's install traffic, so it earns a place.

### 20. Mac Catalyst / native macOS build: second store, same code (31/70)
**Ship the existing SwiftUI + SwiftData app to the Mac App Store — a second storefront, desk-hours usage, and the "reads everywhere you work" story.**
The listing already promises Mac sync via CloudKit; a Catalyst/native macOS target makes it real, adds the Mac App Store's far-less-crowded Books category as a discovery channel, and captures the desk context where people actually process highlights and plan their day. Meaningful port effort (reader layout, menus, keyboard) for a solo dev and the Mac Books market is small — worthwhile, but last among twenty.

**Top 3 rationale:** #1 (Share Extension) converts the whole OS into the app's intake funnel and multiplies content supply; #2 (App Intents/Siri) buys permanent OS-level discovery plus automation-driven recurring moments at low cost; #3 (shareable cards) is the only idea where existing users *manufacture* new users daily — and #14's App Clip and #19's review prompts compound it. Common thread: the architecture (App Group snapshot, pack loader, LLM router, ShareCoordinator, existing engines) means every top-10 idea is days-to-weeks of solo work, not a platform rebuild.
