import SwiftUI
import SwiftData

/// One book's implementation plan — steps grouped by day, checkable in-app,
/// exportable to the system Calendar (events) and Reminders (tasks).
struct ActionPlanView: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext

    @State private var showScheduleSheet = false
    @State private var startDate = Date.now
    @State private var isExporting = false
    @State private var statusText: String?
    @State private var errorText: String?

    private var itemsByDay: [(day: Int, items: [ActionItem])] {
        let all = (book.actionItems ?? [])
            .sorted { ($0.dayOffset, $0.order) < ($1.dayOffset, $1.order) }
        var grouped: [Int: [ActionItem]] = [:]
        for item in all { grouped[item.dayOffset, default: []].append(item) }
        return grouped.keys.sorted().map { (day: $0, items: grouped[$0] ?? []) }
    }

    var body: some View {
        List {
            Section {
                Button {
                    showScheduleSheet = true
                } label: {
                    Label(
                        isExporting ? "Adding to Calendar & Reminders…" : "Put this plan on my calendar",
                        systemImage: "calendar.badge.plus"
                    )
                    .font(.system(size: 15, weight: .semibold))
                }
                .disabled(isExporting || allExported)
                if allExported {
                    Text("Every step has been exported. Events are in your Calendar, to-dos in Reminders.")
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            ForEach(itemsByDay, id: \.day) { group in
                Section("Day \(group.day)") {
                    ForEach(group.items, id: \.id) { item in
                        ActionItemRow(item: item) {
                            toggle(item)
                        } onExport: {
                            Task { await exportSingle(item) }
                        }
                    }
                }
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showScheduleSheet) {
            scheduleSheet
                .presentationDetents([.medium])
        }
        .alert("Couldn't schedule", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
        .overlay(alignment: .bottom) {
            if let statusText {
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.black.opacity(0.8)))
                    .padding(.bottom, Theme.Spacing.l)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: statusText)
    }

    private var allExported: Bool {
        let items = book.actionItems ?? []
        return !items.isEmpty && items.allSatisfy(\.exportedToSystem)
    }

    private var scheduleSheet: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Day 1 starts", selection: $startDate, displayedComponents: .date)
                } footer: {
                    Text("Steps marked as practice sessions become Calendar events at 9:00; one-off steps become Reminders due on their day.")
                }
                Section {
                    Button {
                        showScheduleSheet = false
                        Task { await exportAll() }
                    } label: {
                        Label("Add \(pendingCount) steps", systemImage: "calendar.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .navigationTitle("Schedule plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showScheduleSheet = false }
                }
            }
        }
    }

    private var pendingCount: Int {
        (book.actionItems ?? []).filter { !$0.exportedToSystem }.count
    }

    private func toggle(_ item: ActionItem) {
        item.completed.toggle()
        item.completedAt = item.completed ? .now : nil
        try? modelContext.save()
    }

    private func exportAll() async {
        isExporting = true
        defer { isExporting = false }
        do {
            let count = try await PlannerService.shared.schedulePlan(
                (book.actionItems ?? []), startingFrom: startDate
            )
            try? modelContext.save()
            flashStatus("Added \(count) steps to Calendar & Reminders")
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// Day-1 anchor for single-item exports. If part of the plan was already
    /// scheduled, derive the start the bulk export used (earliest exported
    /// item's date minus its day offset) so a late export lands on the same
    /// timeline; otherwise anchor at today.
    private var planStartDate: Date {
        let derived = (book.actionItems ?? []).compactMap { sibling -> Date? in
            guard let scheduled = sibling.scheduledAt else { return nil }
            return Calendar.current.date(
                byAdding: .day, value: -(sibling.dayOffset - 1), to: scheduled
            )
        }.min()
        return derived ?? Date.now
    }

    private func exportSingle(_ item: ActionItem) async {
        let day = Calendar.current.date(
            byAdding: .day, value: max(item.dayOffset - 1, 0), to: planStartDate
        ) ?? Date.now
        do {
            switch item.kind {
            case .event:
                try await PlannerService.shared.addToCalendar(item, on: day)
                flashStatus("Added to Calendar")
            case .task:
                try await PlannerService.shared.addToReminders(item, due: day)
                flashStatus("Added to Reminders")
            }
            try? modelContext.save()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func flashStatus(_ text: String) {
        statusText = text
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if statusText == text { statusText = nil }
        }
    }
}

private struct ActionItemRow: View {
    let item: ActionItem
    var onToggle: () -> Void
    var onExport: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Button(action: onToggle) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.completed ? Color.green : Theme.Palette.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.completed ? "Mark as not done" : "Mark as done")

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .strikethrough(item.completed)
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                HStack(spacing: 6) {
                    Label(
                        item.kind == .event ? eventBadge : "To-do",
                        systemImage: item.kind == .event ? "calendar" : "checkmark.square"
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    if item.exportedToSystem {
                        Label("Scheduled", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.green)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing) {
            if !item.exportedToSystem {
                Button(action: onExport) {
                    Label(
                        item.kind == .event ? "Calendar" : "Remind",
                        systemImage: item.kind == .event ? "calendar.badge.plus" : "bell.badge"
                    )
                }
                .tint(.blue)
            }
        }
    }

    private var eventBadge: String {
        item.durationMinutes > 0 ? "\(item.durationMinutes) min session" : "Session"
    }
}
