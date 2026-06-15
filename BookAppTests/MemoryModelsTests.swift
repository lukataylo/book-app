import Testing
import Foundation
@testable import BookApp

struct MemoryModelsTests {

    // MARK: - ReviewSession

    @Test
    func retentionCountsRecallNotCompletion() {
        let session = ReviewSession()
        let a = UUID(), b = UUID(), c = UUID(), d = UUID()
        session.record(grade: .good, memoryID: a)
        session.record(grade: .easy, memoryID: b)
        session.record(grade: .hard, memoryID: c)
        session.record(grade: .again, memoryID: d)
        #expect(session.cardsReviewed == 4)
        #expect(session.goodOrBetterCount == 3)   // hard still counts as recall
        #expect(session.againCount == 1)
        #expect(session.retention.map { Int($0 * 100) } == 75)
    }

    @Test
    func retentionIsNilBeforeAnyReview() {
        #expect(ReviewSession().retention == nil)
    }

    @Test
    func sameCardReviewedTwiceCountsOnceInMemoryIDs() {
        let session = ReviewSession()
        let id = UUID()
        session.record(grade: .again, memoryID: id)
        session.record(grade: .good, memoryID: id)
        #expect(session.memoryIDs == [id])
        #expect(session.cardsReviewed == 2)
    }

    // MARK: - StreakState

    @Test
    func streakIncrementsOnConsecutiveDays() {
        let cal = Calendar.current
        let streak = StreakState()
        let day1 = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 3_000_000))
        let day2 = cal.date(byAdding: .day, value: 1, to: day1)!
        let day3 = cal.date(byAdding: .day, value: 2, to: day1)!
        streak.registerActivity(on: day1, calendar: cal)
        streak.registerActivity(on: day2, calendar: cal)
        streak.registerActivity(on: day3, calendar: cal)
        #expect(streak.currentStreak == 3)
        #expect(streak.longestStreak == 3)
    }

    @Test
    func sameDayActivityDoesNotDoubleCount() {
        let cal = Calendar.current
        let streak = StreakState()
        let day1 = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 3_000_000))
        streak.registerActivity(on: day1, calendar: cal)
        streak.registerActivity(on: day1, calendar: cal)
        #expect(streak.currentStreak == 1)
    }

    @Test
    func missedDayResetsStreakWithoutLosingLongest() {
        // A gap resets the current streak to 1 — the user is welcomed back, not
        // punished — while the longest streak is preserved.
        let cal = Calendar.current
        let streak = StreakState()
        let day1 = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 3_000_000))
        let day2 = cal.date(byAdding: .day, value: 1, to: day1)!
        let day5 = cal.date(byAdding: .day, value: 4, to: day1)!
        streak.registerActivity(on: day1, calendar: cal)
        streak.registerActivity(on: day2, calendar: cal)
        streak.registerActivity(on: day5, calendar: cal)
        #expect(streak.currentStreak == 1)
        #expect(streak.longestStreak == 2)
    }

    @Test
    func dailyLimitDefaultsToTheAntiBurnoutCap() {
        #expect(StreakState().dailyLimit == 20)
        #expect(StreakState().remindersEnabled == false)   // opt-in, never default-on
    }
}
