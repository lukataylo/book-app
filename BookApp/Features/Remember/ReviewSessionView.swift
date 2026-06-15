import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Spaced-repetition review loop for the Remember tab. Drives the FSRS engine
/// (``MemoryStore``) over the day's due ``KeyLearning`` memories: show the
/// prompt, reveal the idea, grade recall. Retention — not streak — is the
/// headline metric (memory-system spec §4.2), so the end card leads with it.
///
/// This is the one place branch 2's scheduler surfaces in the UI: no separate
/// "Memories" tab — review lives inside Remember, next to the card decks.
struct ReviewSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// How many cards a single sitting is capped at. Held back cards roll over
    /// to the next day so a session is never a wall.
    var dailyLimit: Int = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var queue: [KeyLearning] = []
    /// How many times each card has been re-queued after an `again` this
    /// session, so a stubborn card can't loop the session forever.
    @State private var requeueCount: [UUID: Int] = [:]
    @State private var index = 0
    @State private var revealed = false
    @State private var session: ReviewSession?
    @State private var loaded = false
    /// Result of the last "Add my saved cards" tap, for empty-state feedback.
    @State private var lastEnrollResult: Int?
    // Teach-back: the user explains the idea and the model grades recall.
    @State private var teachingBack = false
    @State private var teachBackText = ""
    @State private var grading = false
    @State private var teachBackFeedback: String?

    var body: some View {
        ZStack {
            Theme.Palette.appBackground.ignoresSafeArea()
            content
        }
        .navigationTitle("Daily Review")
        .navigationBarTitleDisplayMode(.inline)
        .task { if !loaded { start() } }
    }

    @ViewBuilder
    private var content: some View {
        if !loaded {
            ProgressView()
        } else if queue.isEmpty {
            emptyState
        } else if index >= queue.count {
            summary
        } else {
            reviewing(queue[index])
        }
    }

    // MARK: - Reviewing

    private func reviewing(_ card: KeyLearning) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            progressBar
            Spacer(minLength: 0)
            cardFace(card)
            Spacer(minLength: 0)
            if revealed {
                gradeButtons(card)
            } else if teachingBack {
                teachBackInput(card)
            } else {
                VStack(spacing: Theme.Spacing.s) {
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy) { revealed = true }
                    } label: {
                        Text("Show idea")
                            .font(.system(.headline))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Palette.textPrimary)
                    // Teach-back is the strongest recall test: explain the
                    // idea and the model grades whether you got it. If no model
                    // is reachable, grading fails gracefully back to self-grade.
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy) { teachingBack = true }
                    } label: {
                        Label("Teach it back", systemImage: "text.bubble")
                            .font(.system(.subheadline, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.Palette.textPrimary)
                }
            }
        }
        .padding(Theme.Spacing.l)
    }

    private func teachBackInput(_ card: KeyLearning) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            TextField("Explain this idea in your own words…", text: $teachBackText, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
            if let feedback = teachBackFeedback {
                Text(feedback)
                    .font(.system(.caption))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            HStack(spacing: Theme.Spacing.s) {
                Button("Cancel") {
                    teachingBack = false
                    teachBackText = ""
                    teachBackFeedback = nil
                }
                .buttonStyle(.bordered)
                Button {
                    Task { await gradeTeachBack(card) }
                } label: {
                    Group {
                        if grading { ProgressView() } else { Text("Check my answer") }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Palette.textPrimary)
                .disabled(grading || teachBackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var progressBar: some View {
        VStack(spacing: 4) {
            ProgressView(value: Double(index), total: Double(max(queue.count, 1)))
                .tint(Theme.Palette.textPrimary)
            Text("\(index + 1) of \(queue.count)")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .monospacedDigit()
        }
    }

    private func cardFace(_ card: KeyLearning) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if let title = card.book?.title, !title.isEmpty {
                Text(title)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            Text(card.promptText)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.leading)
            if revealed && !card.back.isEmpty && card.back != card.promptText {
                Divider().background(Theme.Palette.divider)
                Text(card.back)
                    .font(.system(.body))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.l)
        .glassCard(cornerRadius: Theme.Radius.l)
    }

    private func gradeButtons(_ card: KeyLearning) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(ReviewGrade.allCases, id: \.self) { grade in
                Button {
                    submit(card, grade)
                } label: {
                    Text(grade.displayName)
                        .font(.system(.subheadline, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(tint(for: grade))
            }
        }
    }

    private func tint(for grade: ReviewGrade) -> Color {
        switch grade {
        case .again: return .red
        case .hard:  return .orange
        case .good:  return .green
        case .easy:  return .blue
        }
    }

    // MARK: - States

    private var summary: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.green)
            Text("Review complete")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            if let retention = session?.retention {
                Text("\(Int((retention * 100).rounded()))% recalled")
                    .font(.system(.headline))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Text("\(session?.cardsReviewed ?? 0) cards reviewed today.")
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Palette.textSecondary)
            Button("Done") { dismiss() }
                .font(.system(.headline))
                .buttonStyle(.borderedProminent)
                .tint(Theme.Palette.textPrimary)
                .padding(.top, Theme.Spacing.s)
        }
        .padding(Theme.Spacing.xl)
    }

    private var emptyTitle: String {
        if let n = lastEnrollResult { return n > 0 ? "All caught up" : "No saved cards yet" }
        return "Nothing due right now"
    }

    private var emptyMessage: String {
        switch lastEnrollResult {
        case .some(0):
            return "Save cards you want to keep from any deck in the Remember tab, then add them here to review."
        case .some(let n):
            return "Added \(n) card\(n == 1 ? "" : "s") to your review schedule — they'll come back at the right moment. Check back tomorrow."
        default:
            return "Save cards from a deck, then add them to your review schedule and they'll come back right before you'd forget."
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.7))
            Text(emptyTitle)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(emptyMessage)
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                enrollSavedIdeas()
            } label: {
                Text("Add my saved cards")
                    .font(.system(.headline))
                    .padding(.vertical, 12)
                    .padding(.horizontal, Theme.Spacing.l)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Palette.textPrimary)
            .padding(.top, Theme.Spacing.s)
        }
        .padding(Theme.Spacing.xl)
    }

    // MARK: - Engine

    private func start() {
        let store = MemoryStore(context: modelContext)
        let limit = store.streakState().dailyLimit
        // Re-space a returning user's overdue backlog before building the queue.
        store.meterOverdueCards(dailyLimit: limit)
        queue = store.dueToday(dailyLimit: limit)
        index = 0
        revealed = false
        session = nil // created lazily on the first grade
        loaded = true
    }

    private func submit(_ card: KeyLearning, _ grade: ReviewGrade, teachBackScore: Int = -1) {
        let store = MemoryStore(context: modelContext)
        let session = activeSession(store)
        store.grade(card, grade, session: session, teachBackScore: teachBackScore)
        // The scheduler relearns a failed card in ~10 minutes; re-queue it so
        // that relearn step actually happens this session instead of waiting
        // until tomorrow. It re-appears after the remaining due cards.
        // Re-queue a failed card so its 10-min relearn step happens this
        // session — but cap it so a card you genuinely can't recall can't trap
        // the session in a loop (after this it's left for tomorrow / leeched).
        if grade == .again, requeueCount[card.id, default: 0] < 2 {
            requeueCount[card.id, default: 0] += 1
            queue.append(card)
        }
        haptic(for: grade)
        withAnimation(reduceMotion ? nil : .snappy) {
            revealed = false
            teachingBack = false
            teachBackText = ""
            teachBackFeedback = nil
            index += 1
        }
        if index >= queue.count {
            session.endedAt = .now
            store.registerStreakActivity()
            try? modelContext.save()
        }
    }

    /// Grade a typed explanation with the model, then advance with the mapped
    /// recall grade. Falls back to manual self-grading if no model answers.
    private func gradeTeachBack(_ card: KeyLearning) async {
        grading = true
        defer { grading = false }
        let idea = card.back.isEmpty ? card.text : card.back
        do {
            let result = try await TeachBackGrader().grade(idea: idea, explanation: teachBackText)
            submit(card, result.grade, teachBackScore: result.score)
        } catch {
            teachBackFeedback = "Couldn't grade that automatically — tap Show idea and grade yourself."
            withAnimation(reduceMotion ? nil : .snappy) {
                teachingBack = false
                revealed = true
            }
        }
    }

    /// Created lazily on the first grade so empty / abandoned visits don't
    /// litter the store with zero-card sessions.
    private func activeSession(_ store: MemoryStore) -> ReviewSession {
        if let session { return session }
        let s = ReviewSession()
        modelContext.insert(s)
        session = s
        return s
    }

    private func haptic(for grade: ReviewGrade) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: grade == .again ? .rigid : .soft)
        generator.impactOccurred()
        #endif
    }

    /// Enroll the knowledge cards the user has saved across the catalog, each
    /// as a recall card (title prompts, body answers). Idempotent.
    private func enrollSavedIdeas() {
        let added = MemoryStore(context: modelContext).enrollSavedCards()
        lastEnrollResult = added
        start()
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        NavigationStack { ReviewSessionView() }
            .modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
