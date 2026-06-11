import SwiftUI
import SwiftData

/// The daily review loop: a capped queue of due Memories, one card at a time,
/// four grade buttons. Built to feel calm — it shows "N today" and a quiet
/// "more waiting", never a backlog avalanche (spec §3). Insight, cloze, and
/// teach-back cards all review here (spec §2).
struct MemoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<KeyLearning> { $0.isScheduled && !$0.isSuspended })
    private var scheduled: [KeyLearning]
    @Query(filter: #Predicate<KeyLearning> { $0.isScheduled && $0.isSuspended })
    private var suspended: [KeyLearning]
    @Query private var streakStates: [StreakState]

    @State private var queue: [KeyLearning] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var session: ReviewSession?
    @State private var showingSuspended = false

    // Teach-back review state, reset per card.
    @State private var explanation = ""
    @State private var isGrading = false
    @State private var teachBackResult: TeachBackGrader.Result?
    @State private var gradingFailed = false

    private var dailyLimit: Int { streakStates.first?.dailyLimit ?? 20 }

    private var store: MemoryStore { MemoryStore(context: modelContext) }

    var body: some View {
        NavigationStack {
            Group {
                if let card = currentCard {
                    reviewCard(card)
                } else {
                    caughtUp
                }
            }
            .padding(Theme.Spacing.m)
            .navigationTitle("Memories")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSuspended = true
                    } label: {
                        Image(systemName: suspended.isEmpty ? "tray" : "tray.full")
                    }
                    .accessibilityLabel("Suspended cards")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let session, session.cardsReviewed > 0 {
                        Text(progressLabel(session))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingSuspended) {
                SuspendedCardsView()
            }
        }
        .onAppear(perform: rebuild)
    }

    // MARK: - Card

    @ViewBuilder
    private func reviewCard(_ card: KeyLearning) -> some View {
        VStack(spacing: Theme.Spacing.l) {
            header
            streakHeader
            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.m) {
                if !card.chapterRef.isEmpty || card.book != nil {
                    Text([card.book?.title, card.chapterRef.isEmpty ? nil : card.chapterRef]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(card.promptText)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if card.cardKind == .teachBack {
                    teachBackBody(card)
                } else if revealed, card.cardKind == .cloze, !card.back.isEmpty {
                    Divider()
                    Text(card.back)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.l)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.l))

            Spacer(minLength: 0)
            controls(for: card)
        }
    }

    // MARK: - Teach-back

    @ViewBuilder
    private func teachBackBody(_ card: KeyLearning) -> some View {
        if let result = teachBackResult {
            Divider()
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack {
                    Text("Score")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(result.score)")
                        .font(.title3.weight(.semibold))
                }
                if !result.feedback.isEmpty {
                    Text(result.feedback)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !result.missedPoints.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Worth revisiting")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        ForEach(result.missedPoints, id: \.self) { point in
                            Label(point, systemImage: "circle")
                                .font(.caption)
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Divider()
            TextField("Explain this in your own words", text: $explanation, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.plain)
                .disabled(isGrading)
            if gradingFailed {
                Text("Couldn't grade that automatically. Grade it yourself below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func controls(for card: KeyLearning) -> some View {
        switch card.cardKind {
        case .teachBack:
            teachBackControls(card)
        case .insight, .microLesson:
            gradeButtons(for: card)
        case .cloze:
            if revealed {
                gradeButtons(for: card)
            } else {
                showAnswerButton
            }
        }
    }

    @ViewBuilder
    private func teachBackControls(_ card: KeyLearning) -> some View {
        // After auto-grading succeeds the result view advances itself. We only
        // show manual buttons when the LLM grade failed (graceful fallback).
        if teachBackResult != nil {
            EmptyView()
        } else if gradingFailed {
            gradeButtons(for: card)
        } else {
            Button {
                submitTeachBack(card)
            } label: {
                Group {
                    if isGrading {
                        ProgressView()
                    } else {
                        Text("Check my explanation")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Palette.accent)
            .disabled(isGrading || explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var showAnswerButton: some View {
        Button {
            revealed = true
        } label: {
            Text("Show answer")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.s)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.Palette.accent)
    }

    private func gradeButtons(for card: KeyLearning) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(ReviewGrade.allCases, id: \.self) { grade in
                Button {
                    apply(grade, to: card)
                } label: {
                    Text(grade.displayName)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.s)
                }
                .buttonStyle(.bordered)
                .tint(tint(for: grade))
            }
        }
    }

    private var header: some View {
        HStack {
            Text("\(remainingToday) to review")
                .font(.headline)
            Spacer()
            if waiting > 0 {
                Label("\(waiting) waiting", systemImage: "tray.full")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A gentle, invitational streak line — never guilt copy, never gates
    /// anything (spec §3d). Surfaces session retention once it exists.
    @ViewBuilder
    private var streakHeader: some View {
        let streak = streakStates.first?.currentStreak ?? 0
        HStack(spacing: Theme.Spacing.xs) {
            if streak >= 2 {
                Text("🔥 \(streak)-day streak")
                    .font(.caption.weight(.medium))
            } else {
                Text("Today's review")
                    .font(.caption.weight(.medium))
            }
            Spacer()
            if let session, let retention = session.retention {
                Text("\(Int(retention * 100))% recalled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.secondary)
    }

    private var caughtUp: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("All caught up")
                .font(.title2.weight(.semibold))
            if let session, session.cardsReviewed > 0, let retention = session.retention {
                Text("Reviewed \(session.cardsReviewed) · \(Int(retention * 100))% recalled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if waiting > 0 {
                Text("\(waiting) more will come due over the next few days.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Save insights from a summary to start building memory.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - State

    private var currentCard: KeyLearning? {
        guard index < queue.count else { return nil }
        return queue[index]
    }

    private var remainingToday: Int { max(0, queue.count - index) }

    private var projections: [ReviewQueue.Item] {
        scheduled.map {
            ReviewQueue.Item(id: $0.id, dueAt: $0.dueAt, isScheduled: $0.isScheduled, isSuspended: $0.isSuspended, starred: $0.starred)
        }
    }

    /// Due cards held back beyond today's cap — reactive to the live query so
    /// it updates as cards are graded out of the deck.
    private var waiting: Int { ReviewQueue.waiting(from: projections, dailyLimit: dailyLimit) }

    private func rebuild() {
        ensureStreakState()
        if session == nil { session = startSession() }
        let byID = Dictionary(uniqueKeysWithValues: scheduled.map { ($0.id, $0) })
        queue = ReviewQueue.dailyQueue(from: projections, dailyLimit: dailyLimit).compactMap { byID[$0.id] }
        index = 0
        resetCardState()
    }

    // MARK: - Grading

    private func submitTeachBack(_ card: KeyLearning) {
        let idea = card.promptText
        let text = explanation
        isGrading = true
        gradingFailed = false
        Task {
            do {
                let result = try await TeachBackGrader().grade(idea: idea, explanation: text)
                isGrading = false
                teachBackResult = result
                card.lastExplanation = text
                // Auto-apply the mapped grade, then advance after the user sees
                // the feedback. We advance immediately and let the result view
                // render on the just-graded card before moving on.
                apply(result.grade, to: card, teachBackScore: result.score, advance: false)
                // Brief beat so the feedback is visible, then move on.
                try? await Task.sleep(for: .seconds(1.6))
                advance()
            } catch {
                isGrading = false
                gradingFailed = true
            }
        }
    }

    private func apply(_ grade: ReviewGrade, to card: KeyLearning, teachBackScore: Int = -1, advance shouldAdvance: Bool = true) {
        let session = session ?? startSession()
        self.session = session
        store.grade(card, grade, session: session, teachBackScore: teachBackScore)
        streakStates.first?.registerActivity(on: Calendar.current.startOfDay(for: .now))
        try? modelContext.save()
        if shouldAdvance { advance() }
    }

    private func advance() {
        index += 1
        resetCardState()
    }

    private func resetCardState() {
        revealed = false
        explanation = ""
        isGrading = false
        teachBackResult = nil
        gradingFailed = false
    }

    private func startSession() -> ReviewSession {
        let s = ReviewSession()
        modelContext.insert(s)
        return s
    }

    private func ensureStreakState() {
        guard streakStates.isEmpty else { return }
        modelContext.insert(StreakState())
        try? modelContext.save()
    }

    private func progressLabel(_ session: ReviewSession) -> String {
        guard let retention = session.retention else { return "" }
        return "\(session.cardsReviewed) · \(Int(retention * 100))%"
    }

    private func tint(for grade: ReviewGrade) -> Color {
        switch grade {
        case .again: return .red
        case .hard:  return .orange
        case .good:  return .blue
        case .easy:  return .green
        }
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        MemoriesView().modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
