import Testing
import Foundation
@testable import BookApp

/// The scheduler is the engine behind the anti-burnout review loop. These
/// tests pin the two product rules that must never regress: no late penalty,
/// and failure relearns rather than nukes.
struct FSRSSchedulerTests {

    private let scheduler = FSRSScheduler()
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test
    func firstGoodReviewGraduatesToOneDay() {
        let result = scheduler.next(state: .init(), grade: .good, reviewedAt: t0)
        #expect(result.state.repetitions == 1)
        #expect(result.state.lapses == 0)
        #expect(abs(result.state.intervalDays - 1.0) < 0.001)
        #expect(abs(result.dueAt.timeIntervalSince(t0) - 86_400) < 1)
    }

    @Test
    func successiveGoodReviewsGrowTheInterval() {
        var state = scheduler.next(state: .init(), grade: .good, reviewedAt: t0).state
        let firstInterval = state.intervalDays
        state = scheduler.next(state: state, grade: .good, reviewedAt: t0).state
        #expect(state.intervalDays > firstInterval)
        #expect(state.repetitions == 2)
    }

    @Test
    func easyGrowsFasterThanHard() {
        // From an identical mid-strength state, Easy must schedule further out.
        let base = FSRSScheduler.State(stability: 2, difficulty: 5, intervalDays: 2, repetitions: 1, lapses: 0)
        let hard = scheduler.next(state: base, grade: .hard, reviewedAt: t0)
        let easy = scheduler.next(state: base, grade: .easy, reviewedAt: t0)
        #expect(easy.state.intervalDays > hard.state.intervalDays)
    }

    @Test
    func againRelearnsWithoutNuking() {
        // A strong card that's failed once should come back the same session
        // (short relearn step) and keep most of its stability for recovery.
        let strong = FSRSScheduler.State(stability: 30, difficulty: 5, intervalDays: 30, repetitions: 5, lapses: 0)
        let result = scheduler.next(state: strong, grade: .again, reviewedAt: t0)
        #expect(result.state.lapses == 1)
        #expect(result.state.repetitions == 0)
        #expect(result.state.intervalDays < 1)          // relearn step, not a new long interval
        #expect(result.state.stability > 0)             // decayed, not reset to zero
        #expect(result.state.stability < strong.stability)
    }

    @Test
    func intervalIgnoresHowLateTheReviewWas() {
        // The no-late-penalty rule: the next interval depends only on the
        // card's state and the grade, never on the gap since it came due.
        let state = FSRSScheduler.State(stability: 5, difficulty: 5, intervalDays: 5, repetitions: 2, lapses: 0)
        let onTime = scheduler.next(state: state, grade: .good, reviewedAt: t0)
        let twoWeeksLate = scheduler.next(state: state, grade: .good, reviewedAt: t0.addingTimeInterval(14 * 86_400))
        #expect(abs(onTime.state.intervalDays - twoWeeksLate.state.intervalDays) < 0.0001)
    }

    @Test
    func leechFlagFiresExactlyOnceAtThreshold() {
        var state = FSRSScheduler.State()
        var leechEvents = 0
        // Default threshold is 8 lapses.
        for _ in 0..<10 {
            let result = scheduler.next(state: state, grade: .again, reviewedAt: t0)
            if result.becameLeech { leechEvents += 1 }
            state = result.state
        }
        #expect(state.lapses == 10)
        #expect(leechEvents == 1)                         // fires on the crossing, never again
        #expect(scheduler.isLeech(lapses: state.lapses))
    }

    @Test
    func difficultyStaysInRange() {
        var state = FSRSScheduler.State(difficulty: 9.8)
        // Many hard/again grades must not push difficulty past 10.
        for _ in 0..<20 { state = scheduler.next(state: state, grade: .again, reviewedAt: t0).state }
        #expect(state.difficulty <= 10)
        for _ in 0..<40 { state = scheduler.next(state: state, grade: .easy, reviewedAt: t0).state }
        #expect(state.difficulty >= 1)
    }
}
