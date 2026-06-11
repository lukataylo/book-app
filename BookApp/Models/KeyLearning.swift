import Foundation
import SwiftData

/// How a Memory is reviewed. A `KeyLearning` carries one of these once it
/// enters the spaced-repetition deck. The scheduler is identical across
/// kinds; only the review UI and how a grade is produced differ.
/// See `research/pivot-2026/memory-system-spec.md` §2.
enum CardKind: String, Codable, CaseIterable, Sendable {
    case insight      // recognition prompt: "did this come back to you?"
    case cloze        // a blanked span or short Q&A, recalled then revealed
    case teachBack    // user explains it; an LLM grades the explanation (Phase 2)
    case microLesson  // illustrated swipe deck with a recall beat (Phase 3)

    var displayName: String {
        switch self {
        case .insight:     return "Insight"
        case .cloze:       return "Quiz"
        case .teachBack:   return "Teach-back"
        case .microLesson: return "Micro-lesson"
        }
    }
}

/// A review outcome. Feeds `FSRSScheduler` to set the next interval.
enum ReviewGrade: String, Codable, CaseIterable, Sendable {
    case again   // failed recall
    case hard    // recalled with struggle
    case good    // recalled cleanly
    case easy    // trivial

    var displayName: String {
        switch self {
        case .again: return "Again"
        case .hard:  return "Hard"
        case .good:  return "Good"
        case .easy:  return "Easy"
        }
    }

    /// True when the card was successfully recalled. Drives retention stats
    /// (`ReviewSession.goodOrBetterCount`) and lapse counting.
    var isRecall: Bool { self != .again }
}

/// Why a card left the daily queue. A leech (keeps failing) is auto-suspended
/// so it stops haunting the loop — see spec §3c.
enum SuspendReason: String, Codable, Sendable {
    case none
    case leech
    case userPaused
    case retired
}

@Model
final class KeyLearning {
    var id: UUID = UUID()
    var book: Book?
    var text: String = ""
    var chapterRef: String = ""
    var locator: String = ""
    var starred: Bool = false
    var userEdited: Bool = false
    var createdAt: Date = Date.now
    var tags: [String] = []

    // MARK: - Spaced-repetition state
    // Every field below is defaulted, so SwiftData/CloudKit migration is
    // additive: existing learnings load as unscheduled insights and only
    // enter the deck when the user opts them in. See spec §4.1.

    var cardKindRaw: String = CardKind.insight.rawValue
    /// `false` = saved but never entered the review deck.
    var isScheduled: Bool = false
    /// FSRS difficulty proxy (1...10), persisted across reviews.
    var srsDifficulty: Double = 5
    /// FSRS stability in days; 0 until the first successful review.
    var srsStability: Double = 0
    var srsIntervalDays: Double = 0
    /// `nil` = not yet due-scheduled.
    var dueAt: Date?
    var lastReviewedAt: Date?
    var lastGradeRaw: String = ""
    /// Successful recalls in a row.
    var repetitions: Int = 0
    /// Count of `again` grades over the card's life.
    var lapses: Int = 0

    // MARK: - Leech / suspension
    var isSuspended: Bool = false
    var suspendedReasonRaw: String = SuspendReason.none.rawValue

    // MARK: - Card payload (kind-specific; empty when unused)
    /// Cloze/Q&A prompt. Falls back to `text` for plain insights.
    var front: String = ""
    /// Answer for cloze/Q&A.
    var back: String = ""
    /// Encoded blanked range over `front` for cloze cards.
    var clozeMask: String = ""
    /// Links a generated card / micro-lesson back to its source summary.
    var sourceSummaryID: UUID?

    // MARK: - Teach-back (Phase 2)
    var lastExplanation: String = ""
    /// 0...100 LLM grade; -1 = never graded.
    var lastScore: Int = -1

    init(
        id: UUID = UUID(),
        book: Book? = nil,
        text: String,
        chapterRef: String = "",
        locator: String = "",
        starred: Bool = false,
        userEdited: Bool = false
    ) {
        self.id = id
        self.book = book
        self.text = text
        self.chapterRef = chapterRef
        self.locator = locator
        self.starred = starred
        self.userEdited = userEdited
        self.createdAt = .now
    }

    // MARK: - Computed accessors (mirror the `BookVariant.kind` pattern)

    var cardKind: CardKind {
        get { CardKind(rawValue: cardKindRaw) ?? .insight }
        set { cardKindRaw = newValue.rawValue }
    }

    var lastGrade: ReviewGrade? { ReviewGrade(rawValue: lastGradeRaw) }

    var suspendedReason: SuspendReason {
        get { SuspendReason(rawValue: suspendedReasonRaw) ?? .none }
        set { suspendedReasonRaw = newValue.rawValue }
    }

    /// The prompt shown at the front of the card. Insights show their own
    /// text; cloze/Q&A cards show the authored `front`.
    var promptText: String {
        switch cardKind {
        case .insight, .microLesson:
            return text
        case .cloze, .teachBack:
            return front.isEmpty ? text : front
        }
    }
}
