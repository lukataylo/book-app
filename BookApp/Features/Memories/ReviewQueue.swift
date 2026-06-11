import Foundation

/// Pure queue logic for the daily review loop. This is where the anti-burnout
/// rules live (spec §3a/§3b). It is deliberately free of SwiftData so the
/// "a missed day never becomes an avalanche" guarantees are unit-testable.
///
/// The load-bearing invariant: **no session is ever larger than the daily
/// cap.** If the math ever yields "do 200 today to catch up," the queue is
/// wrong — that is exactly the Anki failure mode the research flagged as the
/// #1 quit trigger (`user-pain-points.md` §3).
enum ReviewQueue {

    /// A minimal projection of a `KeyLearning` needed to schedule it. Using a
    /// value type keeps the queue testable without a model container.
    struct Item: Equatable, Identifiable, Sendable {
        var id: UUID
        var dueAt: Date?
        var isScheduled: Bool
        var isSuspended: Bool
        var starred: Bool

        init(id: UUID, dueAt: Date?, isScheduled: Bool = true, isSuspended: Bool = false, starred: Bool = false) {
            self.id = id
            self.dueAt = dueAt
            self.isScheduled = isScheduled
            self.isSuspended = isSuspended
            self.starred = starred
        }
    }

    /// Cards eligible for review right now: scheduled, not suspended, due at or
    /// before `now`. Unsorted/uncapped — use ``dailyQueue`` for what to show.
    static func due(from items: [Item], now: Date = .now) -> [Item] {
        items.filter { item in
            guard item.isScheduled, !item.isSuspended, let due = item.dueAt else { return false }
            return due <= now
        }
    }

    /// What to actually show today: due cards, oldest-due first, starred biased
    /// slightly earlier, capped at `dailyLimit`.
    ///
    /// Anything beyond the cap is intentionally *not* returned. It stays due and
    /// surfaces tomorrow under the same cap, so the user sees "20 today", never
    /// "247 due" (spec §3a). The overflow count is available via ``waiting``.
    static func dailyQueue(from items: [Item], now: Date = .now, dailyLimit: Int) -> [Item] {
        guard dailyLimit > 0 else { return [] }
        return ordered(due(from: items, now: now)).prefix(dailyLimit).map { $0 }
    }

    /// How many due cards are held back beyond today's cap. Shown as a calm
    /// "more waiting" affordance rather than a scary backlog number.
    static func waiting(from items: [Item], now: Date = .now, dailyLimit: Int) -> Int {
        max(0, due(from: items, now: now).count - max(0, dailyLimit))
    }

    /// Order due cards: oldest due first, with starred cards given a small
    /// head start so user-flagged ideas come up sooner.
    static func ordered(_ items: [Item]) -> [Item] {
        items.sorted { lhs, rhs in
            let l = sortKey(lhs)
            let r = sortKey(rhs)
            return l < r
        }
    }

    /// Distance past due, with a fixed credit for starred cards so they sort
    /// ahead of a same-age unstarred card. Earlier (more overdue) sorts first.
    private static func sortKey(_ item: Item) -> Double {
        let due = item.dueAt?.timeIntervalSinceReferenceDate ?? .greatestFiniteMagnitude
        let starBias: Double = item.starred ? 12 * 3600 : 0   // ~half a day head start
        return due - starBias
    }

    // MARK: - Seeding ("Add whole book")

    /// Spread initial due dates for a batch of freshly-added Memories across the
    /// next few days so day one is not a wall and there is no re-test cliff
    /// (spec §5, "Add whole book" staggering).
    ///
    /// Returns one date per card, in order. The first `perDay` cards are due at
    /// `start`, the next `perDay` one day later, and so on. `perDay` is clamped
    /// to the daily cap so seeding can never exceed it.
    static func seedDueDates(
        count: Int,
        start: Date = .now,
        perDay: Int = 5,
        dailyLimit: Int = 20,
        calendar: Calendar = .current
    ) -> [Date] {
        guard count > 0 else { return [] }
        let batch = max(1, min(perDay, dailyLimit))
        return (0..<count).map { index in
            let dayOffset = index / batch
            guard dayOffset > 0 else { return start }
            return calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
        }
    }

    // MARK: - Catch-up metering

    /// Re-space a pile of overdue cards forward so no future day exceeds the
    /// cap (spec §3b "forgiving catch-up"). Returns new due dates keyed by id;
    /// cards that already fit within today's cap keep `now` and are reviewed
    /// today, the rest are metered across upcoming days, oldest-due first.
    ///
    /// This is the explicit "welcome back" rebuild for a returning user: the
    /// queue is reconstructed at the cap, never as the sum of everything missed.
    static func meterOverdue(
        _ items: [Item],
        now: Date = .now,
        dailyLimit: Int,
        calendar: Calendar = .current
    ) -> [UUID: Date] {
        guard dailyLimit > 0 else { return [:] }
        let overdue = ordered(due(from: items, now: now))
        var result: [UUID: Date] = [:]
        for (index, item) in overdue.enumerated() {
            let dayOffset = index / dailyLimit
            let date = dayOffset == 0
                ? now
                : (calendar.date(byAdding: .day, value: dayOffset, to: startOfDay(now, calendar)) ?? now)
            result[item.id] = date
        }
        return result
    }

    private static func startOfDay(_ date: Date, _ calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }
}
