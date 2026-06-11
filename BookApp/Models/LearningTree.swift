import Foundation
import SwiftData

/// A node in a learning tree is either a lesson (teaches a few key ideas) or a
/// checkpoint (a quiz over the unit's ideas). Raw-string backed with a computed
/// accessor, mirroring `BookVariant.kind`.
enum NodeKind: String, Codable, CaseIterable, Sendable {
    case lesson
    case checkpoint

    var displayName: String {
        switch self {
        case .lesson:     return "Lesson"
        case .checkpoint: return "Checkpoint"
        }
    }
}

/// A course is a Duolingo-style tree built from one book's key learnings.
/// `xp` accrues as the user clears nodes. Retention is the win condition, so
/// nothing here gates on time or streaks (see PLAN.md §4.3 / §7).
@Model
final class Course {
    var id: UUID = UUID()
    var title: String = ""
    /// Source book, when the course was built from one. Optional so a curated
    /// multi-book collection can exist later without a single owning book.
    var bookID: UUID?
    var createdAt: Date = Date.now
    var xp: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \TreeNode.course)
    var nodes: [TreeNode]? = []

    init(
        id: UUID = UUID(),
        title: String = "",
        bookID: UUID? = nil,
        xp: Int = 0
    ) {
        self.id = id
        self.title = title
        self.bookID = bookID
        self.xp = xp
        self.createdAt = .now
    }

    /// Nodes in display order. SwiftData relationships are unordered, so we sort
    /// by the persisted `orderIndex`.
    var orderedNodes: [TreeNode] {
        (nodes ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }
}

/// One step in the tree. A lesson teaches `learningIDs`; a checkpoint tests them.
@Model
final class TreeNode {
    var id: UUID = UUID()
    var course: Course?
    var orderIndex: Int = 0
    var title: String = ""
    var kindRaw: String = NodeKind.lesson.rawValue
    /// `KeyLearning.id`s this node teaches or tests.
    var learningIDs: [UUID] = []

    init(
        id: UUID = UUID(),
        course: Course? = nil,
        orderIndex: Int = 0,
        title: String = "",
        kind: NodeKind = .lesson,
        learningIDs: [UUID] = []
    ) {
        self.id = id
        self.course = course
        self.orderIndex = orderIndex
        self.title = title
        self.kindRaw = kind.rawValue
        self.learningIDs = learningIDs
    }

    var kind: NodeKind {
        get { NodeKind(rawValue: kindRaw) ?? .lesson }
        set { kindRaw = newValue.rawValue }
    }
}

/// Per-node completion state. Kept as a separate record (not a flag on the node)
/// so progress can stay user-private and the tree structure stays shareable
/// later. Keyed by `nodeID` rather than a relation to keep it CloudKit-simple.
@Model
final class NodeProgress {
    var id: UUID = UUID()
    var nodeID: UUID = UUID()
    var completed: Bool = false
    /// Best checkpoint score (percent 0...100); 0 for lessons / unattempted.
    var bestScore: Int = 0
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        nodeID: UUID = UUID(),
        completed: Bool = false,
        bestScore: Int = 0,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.nodeID = nodeID
        self.completed = completed
        self.bestScore = bestScore
        self.completedAt = completedAt
    }
}
