import SwiftUI
import SwiftData

/// The node map for one course: a vertical path of lessons and checkpoints,
/// each shown as locked / unlocked / completed. Unlock is gated only on the
/// prior node's completion (TreeProgression), never on time or a streak.
struct CourseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var course: Course

    // Live query so completing a node re-renders lock states immediately.
    @Query private var allProgress: [NodeProgress]

    @State private var activeLesson: TreeNode?
    @State private var activeCheckpoint: TreeNode?

    private var store: CourseStore { CourseStore(context: modelContext) }

    var body: some View {
        let nodes = course.orderedNodes
        let progressByNode = progressMap()
        let completed = nodes.map { progressByNode[$0.id]?.completed ?? false }

        ScrollView {
            VStack(spacing: Theme.Spacing.s) {
                xpHeader
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    let unlocked = TreeProgression.isUnlocked(index: index, completed: completed)
                    let isDone = completed[index]
                    nodeRow(
                        node: node,
                        unlocked: unlocked,
                        completed: isDone,
                        score: progressByNode[node.id]?.bestScore ?? 0
                    )
                    if index < nodes.count - 1 {
                        connector(active: isDone)
                    }
                }
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.Palette.appBackground.ignoresSafeArea())
        .navigationTitle(course.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeLesson) { node in
            LessonView(node: node) {
                store.complete(node: node, in: course, score: 100)
                activeLesson = nil
            }
        }
        .sheet(item: $activeCheckpoint) { node in
            CheckpointQuizView(node: node, course: course)
        }
    }

    // MARK: - Header

    private var xpHeader: some View {
        HStack {
            Label("\(course.xp) XP", systemImage: "star.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            Text("At your own pace")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.bottom, Theme.Spacing.s)
    }

    // MARK: - Node row

    @ViewBuilder
    private func nodeRow(node: TreeNode, unlocked: Bool, completed: Bool, score: Int) -> some View {
        Button {
            open(node)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                nodeIcon(node: node, unlocked: unlocked, completed: completed)
                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(unlocked ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                        .lineLimit(2)
                    Text(subtitle(node: node, unlocked: unlocked, completed: completed, score: score))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
                if unlocked, !completed {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.l))
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .opacity(unlocked ? 1 : 0.55)
    }

    private func nodeIcon(node: TreeNode, unlocked: Bool, completed: Bool) -> some View {
        let symbol: String
        let tint: Color
        if completed {
            symbol = "checkmark.circle.fill"
            tint = .green
        } else if !unlocked {
            symbol = "lock.fill"
            tint = Theme.Palette.textSecondary
        } else if node.kind == .checkpoint {
            symbol = "flag.checkered"
            tint = Theme.Palette.accent
        } else {
            symbol = "book.fill"
            tint = Theme.Palette.accent
        }
        return Image(systemName: symbol)
            .font(.system(size: 22))
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(Theme.Palette.appBackground, in: Circle())
    }

    private func subtitle(node: TreeNode, unlocked: Bool, completed: Bool, score: Int) -> String {
        let count = node.learningIDs.count
        let ideas = "\(count) idea\(count == 1 ? "" : "s")"
        if completed {
            if node.kind == .checkpoint { return "Cleared · \(score)%" }
            return "Done"
        }
        if !unlocked { return "Complete the step above to unlock" }
        switch node.kind {
        case .lesson:     return "\(node.kind.displayName) · \(ideas)"
        case .checkpoint: return "\(node.kind.displayName) · quiz over \(ideas)"
        }
    }

    @ViewBuilder
    private func connector(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.green.opacity(0.5) : Theme.Palette.divider)
            .frame(width: 3, height: 18)
            .padding(.leading, Theme.Spacing.l + 20)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func open(_ node: TreeNode) {
        switch node.kind {
        case .lesson:     activeLesson = node
        case .checkpoint: activeCheckpoint = node
        }
    }

    private func progressMap() -> [UUID: NodeProgress] {
        var map: [UUID: NodeProgress] = [:]
        for p in allProgress { map[p.nodeID] = p }
        return map
    }
}

/// MVP lesson: show the node's ideas as cards, then a "Got it" button that marks
/// it complete. No grading — a lesson is exposure, the checkpoint is the recall
/// test.
private struct LessonView: View {
    let node: TreeNode
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var learnings: [KeyLearning]

    private var ideas: [KeyLearning] {
        // Preserve the node's idea order rather than the query order.
        let byID = Dictionary(learnings.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return node.learningIDs.compactMap { byID[$0] }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    ForEach(Array(ideas.enumerated()), id: \.element.id) { i, idea in
                        ideaCard(index: i, idea: idea)
                    }
                }
                .padding(Theme.Spacing.m)
            }
            .background(Theme.Palette.appBackground.ignoresSafeArea())
            .navigationTitle(node.title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onComplete()
                } label: {
                    Text("Got it")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.s + 2)
                        .background(Theme.Palette.accent)
                        .foregroundStyle(Theme.Palette.appBackground)
                        .clipShape(Capsule())
                }
                .padding(Theme.Spacing.m)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func ideaCard(index: Int, idea: KeyLearning) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Idea \(index + 1)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .textCase(.uppercase)
            Text(idea.text)
                .font(.system(size: 17, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !idea.chapterRef.isEmpty {
                Text(idea.chapterRef)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.l)
        .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.l))
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        NavigationStack {
            CourseDetailView(course: Course(title: "Sample course"))
        }
        .modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
