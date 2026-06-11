import Foundation
import SwiftData
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Schedules the one gentle daily nudge (spec §3d). Hard rules baked in here:
/// reminders are opt-in, there is exactly one per day, and the copy is
/// invitational and count-only. No streak-loss threats, no congratulation
/// spam.
@MainActor
enum MemoryReminders {

    /// Stable identifier so we only ever have one scheduled request.
    static let requestIdentifier = "memory-daily-nudge"

    /// Single entry point: refresh the widget snapshot, then reschedule (or
    /// cancel) the daily reminder to match the current preferences. Call this
    /// on launch, on scenePhase active, and after any settings change.
    static func refresh(context: ModelContext, streak: StreakState) {
        MemorySnapshotWriter.refresh(context: context, dailyLimit: streak.dailyLimit)
        reschedule(context: context, streak: streak)
    }

    /// Ask for notification authorization. Provisional is enough: it lets the
    /// nudge arrive quietly in Notification Center without an upfront prompt,
    /// which fits the calm, opt-in posture. Returns whether we may post.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(
            options: [.alert, .sound, .provisional]
        )) ?? false
        return granted
        #else
        return false
        #endif
    }

    /// Reschedule the daily reminder from current state. Cancels any existing
    /// request first so we never stack duplicates, then schedules one repeating
    /// notification at the chosen minute when reminders are enabled.
    static func reschedule(context: ModelContext, streak: StreakState) {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])

        guard streak.remindersEnabled else { return }

        let dueCount = MemorySnapshot.read()?.dueCount ?? 0
        let content = UNMutableNotificationContent()
        content.title = "Time to remember"
        content.body = invitationalBody(dueCount: dueCount)
        content.sound = .default

        var components = DateComponents()
        let minute = max(0, min(streak.reminderMinuteOfDay, 24 * 60 - 1))
        components.hour = minute / 60
        components.minute = minute % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
        #endif
    }

    /// Cancel the daily nudge entirely (used when the user opts out).
    static func cancelAll() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        #endif
    }

    /// Count-aware, invitational copy. Never references streaks or loss.
    /// Resolved through `String(localized:)` so the `^[…](inflect: true)`
    /// automatic-grammar morphology ("1 memory" / "3 memories") is applied;
    /// a raw notification body string would otherwise show the markup.
    static func invitationalBody(dueCount: Int) -> String {
        guard dueCount > 0 else {
            return String(localized: "A quiet moment to revisit what you've learned.")
        }
        return String(localized: "^[\(dueCount) memory](inflect: true) ready to review.")
    }
}
