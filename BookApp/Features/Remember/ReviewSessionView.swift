import SwiftUI
import SwiftData

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

    @State private var queue: [KeyLearning] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var session: ReviewSession?
    @State private var loaded = false

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
            } else {
                Button {
                    withAnimation(.snappy) { revealed = true }
                } label: {
                    Text("Show idea")
                        .font(.system(.headline))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Palette.textPrimary)
            }
        }
        .padding(Theme.Spacing.l)
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

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.7))
            Text("Nothing due right now")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Add the ideas you've saved to your review schedule and they'll come back at the right moment.")
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                enrollSavedIdeas()
            } label: {
                Text("Add my saved ideas")
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
        let due = store.dueToday(dailyLimit: dailyLimit)
        let s = ReviewSession()
        modelContext.insert(s)
        session = s
        queue = due
        index = 0
        revealed = false
        loaded = true
    }

    private func submit(_ card: KeyLearning, _ grade: ReviewGrade) {
        guard let session else { return }
        MemoryStore(context: modelContext).grade(card, grade, session: session)
        withAnimation(.snappy) {
            revealed = false
            index += 1
        }
        if index >= queue.count {
            session.endedAt = .now
            try? modelContext.save()
        }
    }

    /// Opt every saved-but-unscheduled idea into the deck, due now, so a first
    /// review can begin immediately. Idempotent — already-scheduled ideas are
    /// skipped by ``MemoryStore/saveAsMemory(_:kind:)``.
    private func enrollSavedIdeas() {
        let descriptor = FetchDescriptor<KeyLearning>(
            predicate: #Predicate { !$0.isScheduled }
        )
        let unscheduled = (try? modelContext.fetch(descriptor)) ?? []
        let store = MemoryStore(context: modelContext)
        for learning in unscheduled { store.saveAsMemory(learning) }
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
