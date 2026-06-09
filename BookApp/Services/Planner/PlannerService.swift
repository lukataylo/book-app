import Foundation
import EventKit

enum PlannerError: Error, LocalizedError {
    case calendarAccessDenied
    case remindersAccessDenied
    case noDefaultCalendar

    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied:
            return "Calendar access was declined. Enable it in Settings → Privacy → Calendars."
        case .remindersAccessDenied:
            return "Reminders access was declined. Enable it in Settings → Privacy → Reminders."
        case .noDefaultCalendar:
            return "No default calendar is configured on this device."
        }
    }
}

/// Exports action-plan items to the system Calendar (events) and Reminders
/// (tasks). Write-only calendar access — the app never reads the user's
/// existing events, which keeps the privacy story intact.
@MainActor
final class PlannerService {
    static let shared = PlannerService()

    private let store = EKEventStore()

    /// Adds a single `.event` item to the calendar on the given date.
    /// Events default to 9:00 local time; `durationMinutes` sets the length.
    func addToCalendar(_ item: ActionItem, on day: Date) async throws {
        guard try await store.requestWriteOnlyAccessToEvents() else {
            throw PlannerError.calendarAccessDenied
        }
        guard let calendar = store.defaultCalendarForNewEvents else {
            throw PlannerError.noDefaultCalendar
        }
        let start = Self.at(hour: 9, of: day)
        let minutes = item.durationMinutes > 0 ? item.durationMinutes : 30
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = item.title
        event.notes = eventNotes(for: item)
        event.startDate = start
        event.endDate = start.addingTimeInterval(TimeInterval(minutes * 60))
        try store.save(event, span: .thisEvent)
        item.scheduledAt = start
        item.exportedToSystem = true
    }

    /// Adds a single `.task` item to Reminders, due on the given date.
    func addToReminders(_ item: ActionItem, due day: Date) async throws {
        guard try await store.requestFullAccessToReminders() else {
            throw PlannerError.remindersAccessDenied
        }
        guard let calendar = store.defaultCalendarForNewReminders() else {
            throw PlannerError.noDefaultCalendar
        }
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar
        reminder.title = item.title
        reminder.notes = eventNotes(for: item)
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day], from: Self.at(hour: 9, of: day)
        )
        try store.save(reminder, commit: true)
        item.scheduledAt = Self.at(hour: 9, of: day)
        item.exportedToSystem = true
    }

    /// Exports a whole plan starting from `startDate`: day-1 items land on
    /// the start date, day-N items N−1 days later. Events go to Calendar,
    /// tasks to Reminders. Returns the number of items exported.
    @discardableResult
    func schedulePlan(_ items: [ActionItem], startingFrom startDate: Date) async throws -> Int {
        var exported = 0
        for item in items where !item.exportedToSystem {
            let day = Calendar.current.date(
                byAdding: .day, value: max(item.dayOffset - 1, 0), to: startDate
            ) ?? startDate
            switch item.kind {
            case .event: try await addToCalendar(item, on: day)
            case .task:  try await addToReminders(item, due: day)
            }
            exported += 1
        }
        return exported
    }

    private func eventNotes(for item: ActionItem) -> String {
        var lines: [String] = []
        if !item.detail.isEmpty { lines.append(item.detail) }
        if let title = item.book?.title { lines.append("From your BookApp plan: \(title)") }
        return lines.joined(separator: "\n\n")
    }

    private static func at(hour: Int, of day: Date) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }
}
