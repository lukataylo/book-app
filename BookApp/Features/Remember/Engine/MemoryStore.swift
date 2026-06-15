import Foundation
import SwiftData

/// Bridges the pure scheduler/queue to SwiftData. Keeps the SwiftData-touching
/// surface thin: all scheduling decisions come from ``FSRSScheduler`` and
/// ``ReviewQueue`` so the testable logic stays pure.
@MainActor
struct MemoryStore {
    let context: ModelContext
    var scheduler = FSRSScheduler()
    var now: () -> Date = { .now }
    var calendar: Calendar = .current

    // MARK: - Saving

    /// Put a single learning into the review deck, due immediately.
    func saveAsMemory(_ learning: KeyLearning, kind: CardKind = .insight) {
        guard !learning.isScheduled else { return }
        learning.cardKind = kind
        learning.isScheduled = true
        learning.isSuspended = false
        learning.suspendedReason = .none
        learning.dueAt = now()
        try? context.save()
    }

    /// Seed every key learning of a book into the deck, staggered across the
    /// next few days so the first session is not a wall (spec §5).
    func addWholeBook(_ book: Book, perDay: Int = 5, dailyLimit: Int = 20) {
        let unscheduled = (book.keyLearnings ?? []).filter { !$0.isScheduled }
        guard !unscheduled.isEmpty else { return }
        // Stable order so the stagger is deterministic.
        let ordered = unscheduled.sorted { $0.createdAt < $1.createdAt }
        let dueDates = ReviewQueue.seedDueDates(
            count: ordered.count,
            start: now(),
            perDay: perDay,
            dailyLimit: dailyLimit,
            calendar: calendar
        )
        for (learning, due) in zip(ordered, dueDates) {
            learning.isScheduled = true
            learning.dueAt = due
        }
        try? context.save()
    }

    // MARK: - Reviewing

    /// Today's review queue: due, ordered, capped at `dailyLimit`.
    func dueToday(dailyLimit: Int) -> [KeyLearning] {
        let scheduled = fetchScheduled()
        let byID = Dictionary(uniqueKeysWithValues: scheduled.map { ($0.id, $0) })
        let queue = ReviewQueue.dailyQueue(from: scheduled.map(projection), now: now(), dailyLimit: dailyLimit)
        return queue.compactMap { byID[$0.id] }
    }

    /// Count of due cards held back beyond today's cap.
    func waitingCount(dailyLimit: Int) -> Int {
        ReviewQueue.waiting(from: fetchScheduled().map(projection), now: now(), dailyLimit: dailyLimit)
    }

    /// Today's queue and the held-back count from a SINGLE fetch — used by the
    /// Remember banner, which re-renders per search keystroke, so two separate
    /// fetch+sort passes there were measurable overhead.
    func dueAndWaiting(dailyLimit: Int) -> (due: [KeyLearning], waiting: Int) {
        let scheduled = fetchScheduled()
        let items = scheduled.map(projection)
        let byID = Dictionary(uniqueKeysWithValues: scheduled.map { ($0.id, $0) })
        let queue = ReviewQueue.dailyQueue(from: items, now: now(), dailyLimit: dailyLimit)
        let waiting = ReviewQueue.waiting(from: items, now: now(), dailyLimit: dailyLimit)
        return (queue.compactMap { byID[$0.id] }, waiting)
    }

    /// Apply a grade to a Memory: advance the scheduler, log the review, update
    /// the session, and auto-suspend the card if it just became a leech.
    @discardableResult
    func grade(_ memory: KeyLearning, _ grade: ReviewGrade, session: ReviewSession, teachBackScore: Int = -1) -> FSRSScheduler.Result {
        let reviewedAt = now()
        let before = FSRSScheduler.State(
            stability: memory.srsStability,
            difficulty: memory.srsDifficulty,
            intervalDays: memory.srsIntervalDays,
            repetitions: memory.repetitions,
            lapses: memory.lapses
        )
        let result = scheduler.next(state: before, grade: grade, reviewedAt: reviewedAt)

        memory.srsStability = result.state.stability
        memory.srsDifficulty = result.state.difficulty
        memory.srsIntervalDays = result.state.intervalDays
        memory.repetitions = result.state.repetitions
        memory.lapses = result.state.lapses
        memory.dueAt = result.dueAt
        memory.lastReviewedAt = reviewedAt
        memory.lastGradeRaw = grade.rawValue
        if teachBackScore >= 0 { memory.lastScore = teachBackScore }

        if result.becameLeech {
            memory.isSuspended = true
            memory.suspendedReason = .leech
        }

        let log = ReviewLog(
            memoryID: memory.id,
            reviewedAt: reviewedAt,
            grade: grade,
            intervalBeforeDays: before.intervalDays,
            intervalAfterDays: result.state.intervalDays,
            score: teachBackScore
        )
        context.insert(log)
        session.record(grade: grade, memoryID: memory.id)
        try? context.save()
        return result
    }

    /// Lift a leech/paused card back into the deck, optionally after the user
    /// reformulated it. Resets lapses so it gets a clean run (spec §3c).
    func reinstate(_ memory: KeyLearning, resetLapses: Bool = true) {
        memory.isSuspended = false
        memory.suspendedReason = .none
        if resetLapses { memory.lapses = 0 }
        memory.dueAt = now()
        try? context.save()
    }

    // MARK: - Internals

    private func fetchScheduled() -> [KeyLearning] {
        let descriptor = FetchDescriptor<KeyLearning>(
            predicate: #Predicate { $0.isScheduled && !$0.isSuspended }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func projection(_ k: KeyLearning) -> ReviewQueue.Item {
        ReviewQueue.Item(
            id: k.id,
            dueAt: k.dueAt,
            isScheduled: k.isScheduled,
            isSuspended: k.isSuspended,
            starred: k.starred
        )
    }
}
