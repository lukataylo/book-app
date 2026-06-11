import Testing
import Foundation
@testable import BookApp

struct LearningTreeTests {

    // MARK: - Helpers

    private func learning(_ text: String, tags: [String] = [], chapterRef: String = "") -> LearningInput {
        LearningInput(id: UUID(), text: text, tags: tags, chapterRef: chapterRef)
    }

    // MARK: - CourseBuilder.plan grouping

    @Test
    func groupsByFirstTagIntoUnits() {
        let learnings = [
            learning("a", tags: ["Habits"]),
            learning("b", tags: ["Habits"]),
            learning("c", tags: ["Focus"]),
            learning("d", tags: ["Focus"]),
        ]
        let plan = CourseBuilder.plan(title: "T", bookID: nil, learnings: learnings)
        #expect(plan.units.count == 2)
        #expect(plan.units.map(\.title) == ["Habits", "Focus"])
        #expect(plan.units[0].learningIDs == [learnings[0].id, learnings[1].id])
    }

    @Test
    func fallsBackToChapterRefWhenNoTags() {
        let learnings = [
            learning("a", chapterRef: "Ch 1"),
            learning("b", chapterRef: "Ch 2"),
        ]
        let plan = CourseBuilder.plan(title: "T", bookID: nil, learnings: learnings)
        #expect(plan.units.map(\.title) == ["Ch 1", "Ch 2"])
    }

    @Test
    func singleKeyIdeasUnitWhenNoTagsOrChapters() {
        let learnings = [learning("a"), learning("b"), learning("c")]
        let plan = CourseBuilder.plan(title: "T", bookID: nil, learnings: learnings)
        #expect(plan.units.count == 1)
        #expect(plan.units.first?.title == "Key ideas")
    }

    @Test
    func emptyLearningsProduceEmptyPlan() {
        let plan = CourseBuilder.plan(title: "T", bookID: nil, learnings: [])
        #expect(plan.units.isEmpty)
        #expect(plan.nodes.isEmpty)
    }

    // MARK: - Checkpoint insertion

    @Test
    func insertsOneCheckpointPerUnitAfterItsLessons() {
        let learnings = [
            learning("a", tags: ["U1"]),
            learning("b", tags: ["U1"]),
            learning("c", tags: ["U2"]),
        ]
        let plan = CourseBuilder.plan(title: "T", bookID: nil, learnings: learnings)
        let kinds = plan.nodes.map(\.kind)
        // U1: one lesson (2 ideas <= chunk size) + checkpoint; U2: lesson + checkpoint.
        #expect(kinds == [.lesson, .checkpoint, .lesson, .checkpoint])
        // Each checkpoint covers its whole unit's ideas.
        let checkpoints = plan.nodes.filter { $0.kind == .checkpoint }
        #expect(checkpoints[0].learningIDs == [learnings[0].id, learnings[1].id])
        #expect(checkpoints[1].learningIDs == [learnings[2].id])
    }

    @Test
    func splitsLargeUnitsIntoMultipleLessonsThenOneCheckpoint() {
        // 9 ideas in one tagged unit, chunk size 4 -> 3 lesson nodes + 1 checkpoint.
        let learnings = (0..<9).map { learning("idea \($0)", tags: ["Big"]) }
        let plan = CourseBuilder.plan(title: "T", bookID: nil, learnings: learnings)
        let kinds = plan.nodes.map(\.kind)
        #expect(kinds == [.lesson, .lesson, .lesson, .checkpoint])
        // The checkpoint still covers every idea in the unit.
        #expect(plan.nodes.last?.learningIDs.count == 9)
    }

    // MARK: - Progression: unlock logic

    @Test
    func firstNodeIsAlwaysUnlocked() {
        #expect(TreeProgression.isUnlocked(index: 0, completed: [false, false, false]))
    }

    @Test
    func nextNodeLockedUntilPriorCompleted() {
        let completed = [false, false, false]
        #expect(TreeProgression.isUnlocked(index: 1, completed: completed) == false)
        // Complete node 0 -> node 1 unlocks, node 2 still locked.
        let afterFirst = [true, false, false]
        #expect(TreeProgression.isUnlocked(index: 1, completed: afterFirst))
        #expect(TreeProgression.isUnlocked(index: 2, completed: afterFirst) == false)
    }

    /// The defining anti-burnout property: unlock depends ONLY on prior-node
    /// completion. There is no time or streak input to the function at all, so a
    /// user returning after any gap sees the exact same unlock state and loses
    /// no progress.
    @Test
    func unlockNeverGatesOnTimeOrStreak() {
        // Same completion vector evaluated as if days had passed. The function
        // has no date parameter, so identical completion -> identical unlock.
        let completed = [true, true, false, false]
        let unlockToday = (0..<completed.count).map { TreeProgression.isUnlocked(index: $0, completed: completed) }
        // "After a long gap" is represented by re-evaluating with the same
        // progress; nothing decays.
        let unlockAfterGap = (0..<completed.count).map { TreeProgression.isUnlocked(index: $0, completed: completed) }
        #expect(unlockToday == unlockAfterGap)
        #expect(unlockToday == [true, true, true, false])
    }

    // MARK: - XP

    @Test
    func xpAccruesOnCheckpointCompletion() {
        let kinds: [NodeKind] = [.lesson, .checkpoint]
        // Nothing done -> no XP.
        #expect(TreeProgression.totalXP(kinds: kinds, completed: [false, false]) == 0)
        // Lesson done -> only lesson XP.
        #expect(TreeProgression.totalXP(kinds: kinds, completed: [true, false]) == TreeProgression.lessonXP)
        // Checkpoint done too -> lesson + checkpoint XP, and the checkpoint is
        // worth more than the lesson.
        let full = TreeProgression.totalXP(kinds: kinds, completed: [true, true])
        #expect(full == TreeProgression.lessonXP + TreeProgression.checkpointXP)
        #expect(TreeProgression.checkpointXP > TreeProgression.lessonXP)
    }

    @Test
    func checkpointAwardsMoreThanZero() {
        #expect(TreeProgression.xp(for: .checkpoint) > 0)
        #expect(TreeProgression.xp(for: .lesson) > 0)
    }
}
