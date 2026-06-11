import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Computes the "Today's Memory" widget payload from SwiftData and writes it
/// into the App Group container. Keeps the widget honest about the daily cap
/// (spec §3a): `dueCount` is what the user would actually see today, never the
/// raw overdue pile.
@MainActor
enum MemorySnapshotWriter {

    /// Default daily cap, mirroring `StreakState.dailyLimit`.
    static let defaultDailyLimit = 20

    /// Fetch scheduled, non-suspended Memories, compute today's due queue via
    /// `ReviewQueue`, and write the snapshot. Reloads widget timelines after.
    static func refresh(context: ModelContext, dailyLimit: Int = defaultDailyLimit, now: Date = .now) {
        let cap = max(1, dailyLimit)
        let scheduled = fetchScheduled(context: context)
        let byID = Dictionary(uniqueKeysWithValues: scheduled.map { ($0.id, $0) })
        let queue = ReviewQueue.dailyQueue(
            from: scheduled.map(projection),
            now: now,
            dailyLimit: cap
        )
        let topText = queue.first.flatMap { byID[$0.id]?.promptText } ?? ""
        let snapshot = MemorySnapshot(
            dueCount: queue.count,
            topCardText: topText,
            updatedAt: now
        )
        snapshot.write()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private static func fetchScheduled(context: ModelContext) -> [KeyLearning] {
        let descriptor = FetchDescriptor<KeyLearning>(
            predicate: #Predicate { $0.isScheduled && !$0.isSuspended }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func projection(_ k: KeyLearning) -> ReviewQueue.Item {
        ReviewQueue.Item(
            id: k.id,
            dueAt: k.dueAt,
            isScheduled: k.isScheduled,
            isSuspended: k.isSuspended,
            starred: k.starred
        )
    }
}
