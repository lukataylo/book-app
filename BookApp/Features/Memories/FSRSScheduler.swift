import Foundation

/// A pure, FSRS-flavoured spaced-repetition scheduler.
///
/// It tracks per-card *stability* (how long the memory lasts, in days) and
/// *difficulty* (1...10), and grows the interval from the grade. This is a
/// simplified, deterministic model — not the full FSRS weight set — chosen so
/// the anti-burnout rules are easy to reason about and unit-test. Per-user
/// weight fitting is a later refinement (spec §6, open question 1).
///
/// Two product rules are baked in deliberately and must not regress:
///
/// 1. **No late penalty.** The next interval is computed from the card's prior
///    state and the grade only. How *late* the actual review was never shortens
///    or lengthens the schedule. A user who returns after two weeks away is not
///    punished for the gap (spec §3b).
/// 2. **Failure relearns, it doesn't nuke.** `again` drops the card to a short
///    relearning step and increments `lapses`, but stability decays rather than
///    resetting to zero, so a previously-strong card recovers quickly.
///
/// The scheduler is a value type with no I/O. `MemoryStore` owns persistence.
struct FSRSScheduler {

    struct Config: Sendable {
        /// Where a freshly-failed card lands. Short, so it comes back the same
        /// session without dumping a pile of work later.
        var relearnStep: TimeInterval = 10 * 60   // 10 minutes
        /// Initial stability (days) on the first successful review, by grade.
        var initialStabilityHard: Double = 0.5
        var initialStabilityGood: Double = 1.0
        var initialStabilityEasy: Double = 3.0
        /// Multiplicative interval growth on subsequent successful reviews.
        var growthHard: Double = 1.2
        var growthGood: Double = 2.0
        var growthEasy: Double = 2.6
        /// Stability retained after a lapse (fraction of prior stability).
        var lapseRetention: Double = 0.4
        /// Difficulty nudge per grade, clamped to 1...10.
        var difficultyStepUp: Double = 1.0     // on `again`
        var difficultyStepHard: Double = 0.15
        var difficultyStepEasy: Double = -0.3
        /// Cap so intervals stay sane for a habit product.
        var maxIntervalDays: Double = 365
        /// `lapses >= leechThreshold` marks a leech (spec §3c).
        var leechThreshold: Int = 8

        static let `default` = Config()
    }

    var config: Config = .default

    /// The mutable SRS state of a single card. Mirrors the `KeyLearning`
    /// fields but is detached from SwiftData so the math is testable in
    /// isolation.
    struct State: Equatable, Sendable {
        var stability: Double = 0
        var difficulty: Double = 5
        var intervalDays: Double = 0
        var repetitions: Int = 0
        var lapses: Int = 0
    }

    struct Result: Equatable, Sendable {
        var state: State
        var dueAt: Date
        /// True once `lapses` crosses the leech threshold this review.
        var becameLeech: Bool
    }

    /// Apply a grade and return the next state + due date.
    ///
    /// - Parameters:
    ///   - state: the card's current SRS state.
    ///   - grade: the user's (or LLM's) outcome.
    ///   - reviewedAt: when the review happened. The next due date is measured
    ///     from here, never from when the card *was* due — that's the no-late-
    ///     penalty rule.
    func next(state: State, grade: ReviewGrade, reviewedAt: Date = .now) -> Result {
        var s = state
        let wasLeech = s.lapses >= config.leechThreshold

        s.difficulty = clampDifficulty(s.difficulty + difficultyStep(for: grade))

        let interval: Double
        switch grade {
        case .again:
            s.lapses += 1
            s.repetitions = 0
            // Decay, don't destroy: a strong card recovers fast.
            s.stability = max(minStability, s.stability * config.lapseRetention)
            interval = config.relearnStep / 86_400      // relearn step in days

        case .hard, .good, .easy:
            s.repetitions += 1
            if state.stability <= 0 {
                s.stability = initialStability(for: grade)
            } else {
                s.stability = min(config.maxIntervalDays,
                                  state.stability * growth(for: grade, difficulty: s.difficulty))
            }
            interval = s.stability
        }

        s.intervalDays = interval
        let dueAt = reviewedAt.addingTimeInterval(interval * 86_400)
        let becameLeech = !wasLeech && s.lapses >= config.leechThreshold
        return Result(state: s, dueAt: dueAt, becameLeech: becameLeech)
    }

    /// Whether a card's lapse count makes it a leech right now.
    func isLeech(lapses: Int) -> Bool { lapses >= config.leechThreshold }

    // MARK: - Internals

    private let minStability = 0.1

    private func initialStability(for grade: ReviewGrade) -> Double {
        switch grade {
        case .again: return minStability
        case .hard:  return config.initialStabilityHard
        case .good:  return config.initialStabilityGood
        case .easy:  return config.initialStabilityEasy
        }
    }

    /// Easier cards (lower difficulty) grow faster. The factor is the base
    /// grade growth scaled by how far difficulty sits from the midpoint.
    private func growth(for grade: ReviewGrade, difficulty: Double) -> Double {
        let base: Double
        switch grade {
        case .again: return config.lapseRetention
        case .hard:  base = config.growthHard
        case .good:  base = config.growthGood
        case .easy:  base = config.growthEasy
        }
        let difficultyAdjust = 1 + (5 - difficulty) * 0.04   // ±16% across the range
        return max(1.05, base * difficultyAdjust)
    }

    private func difficultyStep(for grade: ReviewGrade) -> Double {
        switch grade {
        case .again: return config.difficultyStepUp
        case .hard:  return config.difficultyStepHard
        case .good:  return 0
        case .easy:  return config.difficultyStepEasy
        }
    }

    private func clampDifficulty(_ d: Double) -> Double { min(10, max(1, d)) }
}
