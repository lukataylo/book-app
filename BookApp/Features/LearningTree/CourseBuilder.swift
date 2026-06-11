import Foundation
import SwiftData

// MARK: - Plan value types (pure, Sendable)

/// A learning the planner groups into units. Decoupled from `KeyLearning` so the
/// planner is a pure value-type function with no SwiftData dependency.
struct LearningInput: Sendable, Equatable {
    let id: UUID
    let text: String
    let tags: [String]
    let chapterRef: String
}

/// A planned node before it is materialized into SwiftData. Ordering across the
/// whole course is given by position in `CoursePlan.nodes`.
struct NodePlan: Sendable, Equatable {
    let kind: NodeKind
    let title: String
    let learningIDs: [UUID]
}

/// A themed group of learnings. A unit becomes a run of lesson nodes followed by
/// one checkpoint node.
struct UnitPlan: Sendable, Equatable {
    let title: String
    let learningIDs: [UUID]
}

/// The full plan: the ordered units and the flat, ordered node list the store
/// materializes. Pure data, no SwiftData.
struct CoursePlan: Sendable, Equatable {
    let title: String
    let bookID: UUID?
    let units: [UnitPlan]
    let nodes: [NodePlan]
}

// MARK: - The pure planner

/// Builds a `CoursePlan` from a book's learnings. No SwiftData writes happen
/// here, which keeps the grouping + checkpoint logic unit-testable.
enum CourseBuilder {
    /// Max ideas taught by a single lesson node. Keeps a lesson snackable.
    static let ideasPerLesson = 4

    static func plan(
        title: String,
        bookID: UUID?,
        learnings: [LearningInput]
    ) -> CoursePlan {
        let units = makeUnits(from: learnings)
        var nodes: [NodePlan] = []

        for unit in units {
            // Split a unit's ideas into snackable lesson chunks.
            let chunks = chunk(unit.learningIDs, size: ideasPerLesson)
            let multiLesson = chunks.count > 1
            for (i, chunk) in chunks.enumerated() {
                let lessonTitle = multiLesson ? "\(unit.title) · Part \(i + 1)" : unit.title
                nodes.append(NodePlan(kind: .lesson, title: lessonTitle, learningIDs: chunk))
            }
            // One checkpoint per unit, covering all of the unit's ideas.
            nodes.append(NodePlan(
                kind: .checkpoint,
                title: "\(unit.title) checkpoint",
                learningIDs: unit.learningIDs
            ))
        }

        return CoursePlan(title: title, bookID: bookID, units: units, nodes: nodes)
    }

    // MARK: - Unit grouping

    /// Group by first tag, else by `chapterRef`, else a single "Key ideas" unit.
    /// Order is stable: units appear in the order their first member is seen.
    private static func makeUnits(from learnings: [LearningInput]) -> [UnitPlan] {
        guard !learnings.isEmpty else { return [] }

        let key: (LearningInput) -> String?
        if learnings.contains(where: { !$0.tags.isEmpty }) {
            key = { $0.tags.first }
        } else if learnings.contains(where: { !$0.chapterRef.isEmpty }) {
            key = { $0.chapterRef.isEmpty ? nil : $0.chapterRef }
        } else {
            // No grouping signal at all: a single unit.
            return [UnitPlan(title: "Key ideas", learningIDs: learnings.map(\.id))]
        }

        var order: [String] = []
        var buckets: [String: [UUID]] = [:]
        for learning in learnings {
            let bucket = key(learning) ?? "Key ideas"
            if buckets[bucket] == nil { order.append(bucket) }
            buckets[bucket, default: []].append(learning.id)
        }
        return order.map { UnitPlan(title: $0, learningIDs: buckets[$0] ?? []) }
    }

    private static func chunk(_ ids: [UUID], size: Int) -> [[UUID]] {
        guard size > 0, !ids.isEmpty else { return ids.isEmpty ? [] : [ids] }
        return stride(from: 0, to: ids.count, by: size).map {
            Array(ids[$0 ..< min($0 + size, ids.count)])
        }
    }
}

// MARK: - Progression rules (pure, tested)

/// Unlock + XP logic for a tree. Pure so the rules can be tested without
/// SwiftData and without any clock. The defining property: unlock depends on
/// PRIOR-NODE COMPLETION ONLY, never on time or streak — a user returning after
/// days away loses no progress and faces no penalty.
enum TreeProgression {
    /// XP awarded for clearing a node. Lessons give a small amount; a checkpoint
    /// is the unit's payoff.
    static let lessonXP = 10
    static let checkpointXP = 30

    static func xp(for kind: NodeKind) -> Int {
        switch kind {
        case .lesson:     return lessonXP
        case .checkpoint: return checkpointXP
        }
    }

    /// Whether the node at `index` is unlocked, given completion of each node in
    /// order. The first node is always unlocked; every later node unlocks only
    /// when the immediately preceding node is completed. Time is never an input.
    static func isUnlocked(index: Int, completed: [Bool]) -> Bool {
        guard index > 0 else { return true }
        guard index < completed.count else { return false }
        return completed[index - 1]
    }

    /// Total XP a course should hold given which ordered nodes are completed.
    /// Derived from completion alone, so recomputing after a gap is stable.
    static func totalXP(kinds: [NodeKind], completed: [Bool]) -> Int {
        zip(kinds, completed).reduce(0) { acc, pair in
            pair.1 ? acc + xp(for: pair.0) : acc
        }
    }
}

// MARK: - The SwiftData store

/// Materializes a `CoursePlan` into `Course` / `TreeNode` rows and records
/// node completion. The only SwiftData-touching surface; all decisions about
/// structure come from `CourseBuilder` and unlock decisions from
/// `TreeProgression`, so the logic stays pure and testable.
@MainActor
struct CourseStore {
    let context: ModelContext
    var now: () -> Date = { .now }

    /// Build (and persist) a course from a book's key learnings. Returns nil
    /// when the book has no learnings to teach.
    @discardableResult
    func buildCourse(from book: Book) -> Course? {
        let learnings = (book.keyLearnings ?? []).map {
            LearningInput(id: $0.id, text: $0.text, tags: $0.tags, chapterRef: $0.chapterRef)
        }
        guard !learnings.isEmpty else { return nil }

        let plan = CourseBuilder.plan(
            title: courseTitle(for: book),
            bookID: book.id,
            learnings: learnings
        )
        return materialize(plan)
    }

    /// Insert a plan's `Course` + ordered `TreeNode`s. Pure planning is already
    /// done; this only writes.
    @discardableResult
    func materialize(_ plan: CoursePlan) -> Course {
        let course = Course(title: plan.title, bookID: plan.bookID)
        context.insert(course)
        for (i, node) in plan.nodes.enumerated() {
            let row = TreeNode(
                course: course,
                orderIndex: i,
                title: node.title,
                kind: node.kind,
                learningIDs: node.learningIDs
            )
            context.insert(row)
        }
        try? context.save()
        return course
    }

    /// Mark a node complete and award its XP exactly once. `score` is the
    /// checkpoint percent (0...100); lessons pass 100. Awards XP only on the
    /// first completion so re-running a lesson never inflates the total.
    func complete(node: TreeNode, in course: Course, score: Int = 100) {
        let progress = progressRecord(for: node.id)
        let firstCompletion = !progress.completed

        progress.completed = true
        progress.bestScore = max(progress.bestScore, score)
        if progress.completedAt == nil { progress.completedAt = now() }

        if firstCompletion {
            course.xp += TreeProgression.xp(for: node.kind)
        }
        try? context.save()
    }

    /// Fetch-or-create the progress record for a node.
    func progressRecord(for nodeID: UUID) -> NodeProgress {
        if let existing = fetchProgress(nodeID) { return existing }
        let created = NodeProgress(nodeID: nodeID)
        context.insert(created)
        return created
    }

    /// Map of nodeID -> progress for a whole course, for the detail view.
    func progressMap(for course: Course) -> [UUID: NodeProgress] {
        var map: [UUID: NodeProgress] = [:]
        for node in course.orderedNodes {
            map[node.id] = progressRecord(for: node.id)
        }
        return map
    }

    private func fetchProgress(_ nodeID: UUID) -> NodeProgress? {
        let descriptor = FetchDescriptor<NodeProgress>(
            predicate: #Predicate { $0.nodeID == nodeID }
        )
        return (try? context.fetch(descriptor))?.first
    }

    private func courseTitle(for book: Book) -> String {
        book.title.isEmpty ? "Untitled course" : "The big ideas in \(book.title)"
    }
}
