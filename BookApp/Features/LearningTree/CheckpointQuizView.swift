import SwiftUI
import SwiftData

/// A checkpoint quiz over one unit's ideas. Each idea is shown as a recall
/// prompt: the user thinks, reveals the idea, then self-grades right / wrong.
/// The score writes `NodeProgress` and awards the node's XP on first clear.
/// Self-graded recall keeps this honest about retention (PLAN.md §4.3) without
/// needing an LLM in the loop.
struct CheckpointQuizView: View {
    let node: TreeNode
    @Bindable var course: Course

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var learnings: [KeyLearning]

    @State private var index = 0
    @State private var revealed = false
    @State private var correctCount = 0
    @State private var finished = false
    @State private var recorded = false

    private var store: CourseStore { CourseStore(context: modelContext) }

    private var ideas: [KeyLearning] {
        let byID = Dictionary(learnings.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return node.learningIDs.compactMap { byID[$0] }
    }

    var body: some View {
        NavigationStack {
            Group {
                if finished || ideas.isEmpty {
                    resultView
                } else {
                    quizCard
                }
            }
            .padding(Theme.Spacing.m)
            .background(Theme.Palette.appBackground.ignoresSafeArea())
            .navigationTitle(node.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Quiz card

    @ViewBuilder
    private var quizCard: some View {
        let idea = ideas[index]
        VStack(spacing: Theme.Spacing.l) {
            HStack {
                Text("\(index + 1) of \(ideas.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Text("Checkpoint")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
            }

            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.m) {
                Text(revealed ? "The idea" : "Can you recall this idea?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .textCase(.uppercase)
                if revealed {
                    Text(idea.text)
                        .font(.system(size: 19, design: .serif))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(prompt(for: idea))
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.l)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.l))

            Spacer(minLength: 0)

            if revealed {
                gradeButtons
            } else {
                Button {
                    revealed = true
                } label: {
                    Text("Show the idea")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.s + 2)
                        .background(Theme.Palette.accent)
                        .foregroundStyle(Theme.Palette.appBackground)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var gradeButtons: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button {
                advance(correct: false)
            } label: {
                gradeLabel("Missed it", systemImage: "xmark", tint: .red)
            }
            Button {
                advance(correct: true)
            } label: {
                gradeLabel("Got it", systemImage: "checkmark", tint: .green)
            }
        }
    }

    private func gradeLabel(_ title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s + 2)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
    }

    // MARK: - Result

    private var resultView: some View {
        let total = max(ideas.count, 1)
        let score = Int((Double(correctCount) / Double(total)) * 100)
        return VStack(spacing: Theme.Spacing.m) {
            Spacer()
            Image(systemName: "flag.checkered")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Palette.accent)
            Text("Checkpoint cleared")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("\(correctCount) of \(ideas.count) recalled · \(score)%")
                .font(.system(size: 15))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("Anything you missed is worth a second look. No penalty, no rush.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.s + 2)
                    .background(Theme.Palette.accent)
                    .foregroundStyle(Theme.Palette.appBackground)
                    .clipShape(Capsule())
            }
        }
        .onAppear(perform: recordResultOnce)
    }

    // MARK: - Logic

    /// Recall prompt for an idea. Cloze/Q&A cards already carry a prompt; an
    /// insight reuses its chapter/source as the cue so the answer isn't given
    /// away in the question.
    private func prompt(for idea: KeyLearning) -> String {
        if !idea.front.isEmpty { return idea.front }
        if !idea.chapterRef.isEmpty {
            return "Recall the key idea from \(idea.chapterRef)."
        }
        return "Recall the next key idea from this unit."
    }

    private func advance(correct: Bool) {
        if correct { correctCount += 1 }
        revealed = false
        if index + 1 < ideas.count {
            index += 1
        } else {
            finished = true
        }
    }

    /// Write progress + award XP. Completing a checkpoint marks it done; XP is
    /// awarded once by `CourseStore`. Best score is preserved across retakes.
    private func recordResultOnce() {
        guard !recorded else { return }
        recorded = true
        let total = max(ideas.count, 1)
        let score = Int((Double(correctCount) / Double(total)) * 100)
        store.complete(node: node, in: course, score: score)
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        CheckpointQuizView(node: TreeNode(title: "Unit checkpoint", kind: .checkpoint), course: Course(title: "Sample"))
            .modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
