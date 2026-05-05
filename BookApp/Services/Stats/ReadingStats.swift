import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#endif

/// Lightweight reading-time tracker. UserDefaults-backed so it survives
/// re-installs and doesn't need a SwiftData migration. Designed to be
/// invisible to most callers — `start()` when the reader appears,
/// `stop()` when it disappears, plus passive coverage of foreground /
/// background transitions.
///
/// Stats surfaced in Settings:
///   - **Current streak**: number of consecutive days ending today with at
///     least 1 minute of reading.
///   - **This week**: sum of minutes Mon-Sun of the current week.
///   - **All time**: total minutes accumulated.
@MainActor
final class ReadingStats: ObservableObject {
    static let shared = ReadingStats()

    /// `[YYYY-MM-DD: minutes]` map.
    private let dailyKey = "ReadingStats.daily-v1"
    private let allTimeKey = "ReadingStats.allTime-v1"

    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var minutesThisWeek: Int = 0
    @Published private(set) var minutesAllTime: Int = 0

    private var sessionStartedAt: Date?
    private var notificationObservers: [NSObjectProtocol] = []

    init() {
        recompute()
        attachLifecycleObservers()
    }
    // No deinit — this is a singleton (`shared`), it lives for the app's
    // lifetime, and the lifecycle observers are removed implicitly when
    // the process exits.

    func start() {
        guard sessionStartedAt == nil else { return }
        sessionStartedAt = .now
    }

    func stop() {
        guard let started = sessionStartedAt else { return }
        sessionStartedAt = nil
        let minutes = Int(Date.now.timeIntervalSince(started) / 60)
        guard minutes >= 1 else { return }
        record(minutes: minutes)
    }

    private func record(minutes: Int) {
        var daily = UserDefaults.standard.dictionary(forKey: dailyKey) as? [String: Int] ?? [:]
        let key = Self.dayKey(for: .now)
        daily[key, default: 0] += minutes
        UserDefaults.standard.set(daily, forKey: dailyKey)

        let total = UserDefaults.standard.integer(forKey: allTimeKey) + minutes
        UserDefaults.standard.set(total, forKey: allTimeKey)
        recompute()
    }

    private func recompute() {
        let daily = UserDefaults.standard.dictionary(forKey: dailyKey) as? [String: Int] ?? [:]
        currentStreak = Self.computeStreak(daily: daily)
        minutesThisWeek = Self.computeWeekTotal(daily: daily)
        minutesAllTime = UserDefaults.standard.integer(forKey: allTimeKey)
    }

    private func attachLifecycleObservers() {
        #if canImport(UIKit)
        let willResign = UIApplication.willResignActiveNotification
        let willEnter  = UIApplication.didBecomeActiveNotification

        let bgToken = NotificationCenter.default.addObserver(
            forName: willResign, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        let fgToken = NotificationCenter.default.addObserver(
            forName: willEnter, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.recompute() }
        }
        notificationObservers = [bgToken, fgToken]
        #endif
    }

    static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = .init(identifier: .gregorian)
        f.locale = .init(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func computeStreak(daily: [String: Int]) -> Int {
        let cal = Calendar(identifier: .gregorian)
        var date = Date.now
        var streak = 0
        // If today has no minutes yet, the streak is what ended yesterday;
        // we still count it as alive while there is *some* time today, or
        // if yesterday hit ≥1 minute.
        for offset in 0..<365 {
            let key = dayKey(for: date)
            let minutes = daily[key] ?? 0
            if minutes >= 1 {
                streak += 1
            } else if offset == 0 {
                // Today is empty — keep going to count yesterday-onward.
            } else {
                break
            }
            date = cal.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return streak
    }

    private static func computeWeekTotal(daily: [String: Int]) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let now = Date.now
        let comps = cal.dateComponents([.weekOfYear, .yearForWeekOfYear], from: now)
        guard let weekStart = cal.date(from: comps) else { return 0 }
        var total = 0
        for offset in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            total += daily[dayKey(for: d)] ?? 0
        }
        return total
    }
}
