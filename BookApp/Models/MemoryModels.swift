import Foundation
import SwiftData

/// One daily review sitting. The headline product metric is retention
/// (`goodOrBetterCount` / `cardsReviewed`), not streak length — see
/// `PLAN.md` §7 resolution and spec §4.2.
@Model
final class ReviewSession {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var endedAt: Date?
    var cardsReviewed: Int = 0
    var againCount: Int = 0
    /// The real retention signal: cards recalled (Hard/Good/Easy).
    var goodOrBetterCount: Int = 0
    /// `KeyLearning.id`s touched this session.
    var memoryIDs: [UUID] = []

    init(id: UUID = UUID(), startedAt: Date = .now) {
        self.id = id
        self.startedAt = startedAt
    }

    /// Fraction of cards recalled this session, 0...1. `nil` until any card
    /// is reviewed.
    var retention: Double? {
        guard cardsReviewed > 0 else { return nil }
        return Double(goodOrBetterCount) / Double(cardsReviewed)
    }

    func record(grade: ReviewGrade, memoryID: UUID) {
        cardsReviewed += 1
        if grade.isRecall { goodOrBetterCount += 1 } else { againCount += 1 }
        if !memoryIDs.contains(memoryID) { memoryIDs.append(memoryID) }
    }
}

/// Append-only per-review history. Kept separate from `KeyLearning` so the
/// Memory record stays small, and so FSRS weights can be fit per-user later
/// (spec §6, open question 1).
@Model
final class ReviewLog {
    var id: UUID = UUID()
    /// -> `KeyLearning.id`.
    var memoryID: UUID = UUID()
    var reviewedAt: Date = Date.now
    var gradeRaw: String = ""
    var intervalBeforeDays: Double = 0
    var intervalAfterDays: Double = 0
    /// Teach-back score if applicable, else -1.
    var score: Int = -1

    init(
        id: UUID = UUID(),
        memoryID: UUID,
        reviewedAt: Date = .now,
        grade: ReviewGrade,
        intervalBeforeDays: Double,
        intervalAfterDays: Double,
        score: Int = -1
    ) {
        self.id = id
        self.memoryID = memoryID
        self.reviewedAt = reviewedAt
        self.gradeRaw = grade.rawValue
        self.intervalBeforeDays = intervalBeforeDays
        self.intervalAfterDays = intervalAfterDays
        self.score = score
    }

    var grade: ReviewGrade? { ReviewGrade(rawValue: gradeRaw) }
}

/// Lightweight single-record streak/preference state. The streak is cosmetic
/// here: it never gates review and never sends guilt-trip copy (spec §3d).
@Model
final class StreakState {
    var id: UUID = UUID()
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    /// Start-of-day for the last day the user reviewed anything.
    var lastActiveDay: Date?
    /// Hard cap on cards surfaced per day (spec §3a). User-adjustable.
    var dailyLimit: Int = 20
    /// Reminders are off until the user opts in.
    var remindersEnabled: Bool = false
    /// Minutes since local midnight for the daily nudge.
    var reminderMinuteOfDay: Int = 9 * 60

    init(id: UUID = UUID()) {
        self.id = id
    }

    /// Advance the streak for a review happening on `day` (a start-of-day
    /// date). A missed day resets the streak to 1 rather than punishing the
    /// user with lost progress mid-session.
    func registerActivity(on day: Date, calendar: Calendar = .current) {
        defer {
            lastActiveDay = day
            longestStreak = max(longestStreak, currentStreak)
        }
        guard let last = lastActiveDay else { currentStreak = 1; return }
        if calendar.isDate(day, inSameDayAs: last) { return }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: day)
        if let yesterday, calendar.isDate(last, inSameDayAs: yesterday) {
            currentStreak += 1
        } else {
            currentStreak = 1
        }
    }
}
