import Testing
import Foundation
@testable import BookApp

/// These tests pin the anti-burnout guarantees that differentiate the product
/// from Anki-style backlog avalanches (`user-pain-points.md` §3): the daily
/// session is always capped, overdue work is metered forward, and seeding a
/// whole book never creates a wall.
struct ReviewQueueTests {

    private let now = Date(timeIntervalSinceReferenceDate: 2_000_000)
    private let cal = Calendar.current

    private func item(_ id: UUID = UUID(), dueOffsetDays: Double, scheduled: Bool = true, suspended: Bool = false, starred: Bool = false) -> ReviewQueue.Item {
        ReviewQueue.Item(
            id: id,
            dueAt: now.addingTimeInterval(dueOffsetDays * 86_400),
            isScheduled: scheduled,
            isSuspended: suspended,
            starred: starred
        )
    }

    @Test
    func dueExcludesFutureSuspendedAndUnscheduled() {
        let items = [
            item(dueOffsetDays: -1),                       // due
            item(dueOffsetDays: 2),                        // future
            item(dueOffsetDays: -1, scheduled: false),     // not in deck
            item(dueOffsetDays: -1, suspended: true)       // leech
        ]
        #expect(ReviewQueue.due(from: items, now: now).count == 1)
    }

    @Test
    func dailyQueueNeverExceedsTheCap() {
        // The load-bearing invariant. 200 overdue cards, cap 20 → show 20.
        let items = (0..<200).map { item(dueOffsetDays: -Double($0) - 1) }
        let queue = ReviewQueue.dailyQueue(from: items, now: now, dailyLimit: 20)
        #expect(queue.count == 20)
        #expect(ReviewQueue.waiting(from: items, now: now, dailyLimit: 20) == 180)
    }

    @Test
    func queueShowsOldestDueFirst() {
        let oldest = item(dueOffsetDays: -10)
        let middle = item(dueOffsetDays: -5)
        let newest = item(dueOffsetDays: -1)
        let queue = ReviewQueue.dailyQueue(from: [newest, oldest, middle], now: now, dailyLimit: 10)
        #expect(queue.map(\.id) == [oldest.id, middle.id, newest.id])
    }

    @Test
    func starredCardsGetASmallHeadStart() {
        // A starred card sorts ahead of an unstarred card due at the same time.
        let plain = item(dueOffsetDays: -1, starred: false)
        let flagged = item(dueOffsetDays: -1, starred: true)
        let queue = ReviewQueue.ordered([plain, flagged])
        #expect(queue.first?.id == flagged.id)
    }

    @Test
    func seedingStaggersAcrossDaysAndRespectsTheCap() {
        // "Add whole book": 12 ideas, 5/day → 5 today, 5 tomorrow, 2 day after.
        let dates = ReviewQueue.seedDueDates(count: 12, start: now, perDay: 5, dailyLimit: 20, calendar: cal)
        #expect(dates.count == 12)
        let byDay = Dictionary(grouping: dates) { cal.startOfDay(for: $0) }
        #expect(byDay.count == 3)
        #expect(byDay.values.allSatisfy { $0.count <= 5 })
        // perDay can never exceed the daily cap.
        let capped = ReviewQueue.seedDueDates(count: 12, start: now, perDay: 50, dailyLimit: 3, calendar: cal)
        let cappedByDay = Dictionary(grouping: capped) { cal.startOfDay(for: $0) }
        #expect(cappedByDay.values.allSatisfy { $0.count <= 3 })
    }

    @Test
    func meteringOverdueNeverPilesMoreThanTheCapIntoAnyDay() {
        // The "welcome back" rebuild: 100 overdue, cap 20 → spread so no day
        // ever exceeds 20, and the first batch is due now.
        let items = (0..<100).map { item(dueOffsetDays: -Double($0) - 1) }
        let metered = ReviewQueue.meterOverdue(items, now: now, dailyLimit: 20, calendar: cal)
        #expect(metered.count == 100)
        let byDay = Dictionary(grouping: metered.values) { cal.startOfDay(for: $0) }
        #expect(byDay.values.allSatisfy { $0.count <= 20 })
        #expect(byDay.count == 5)
        let dueNow = metered.values.filter { abs($0.timeIntervalSince(now)) < 1 }.count
        #expect(dueNow == 20)
    }

    @Test
    func zeroOrNegativeCapShowsNothing() {
        let items = (0..<5).map { _ in item(dueOffsetDays: -1) }
        #expect(ReviewQueue.dailyQueue(from: items, now: now, dailyLimit: 0).isEmpty)
        #expect(ReviewQueue.waiting(from: items, now: now, dailyLimit: 0) == 5)
    }
}
