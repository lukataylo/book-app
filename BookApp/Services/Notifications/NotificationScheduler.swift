import Foundation
import UserNotifications

/// Local daily-review reminders. The whole value of spaced repetition is
/// coming back when a card is due, so a gentle once-a-day nudge is the only
/// notification the app sends — opt-in, no account, no server.
enum NotificationScheduler {
    private static let reviewReminderID = "daily-review-reminder"

    /// Ask for alert permission. Returns whether it was granted.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// (Re)schedule the repeating daily reminder at `minuteOfDay` minutes after
    /// local midnight. Replaces any existing one so changing the time is clean.
    static func scheduleDailyReview(minuteOfDay: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reviewReminderID])

        var components = DateComponents()
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60

        let content = UNMutableNotificationContent()
        content.title = "Time to remember"
        content.body = "A few cards are ready for today's review."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: reviewReminderID, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancelDailyReview() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reviewReminderID])
    }
}
