import WidgetKit
import SwiftUI

struct TodaysMemoryWidget: Widget {
    let kind: String = "TodaysMemoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodaysMemoryProvider()) { entry in
            TodaysMemoryWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today's memory")
        .description("A calm nudge to review what you've learned.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodaysMemoryEntry: TimelineEntry {
    let date: Date
    let snapshot: MemorySnapshot?
}

struct TodaysMemoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodaysMemoryEntry {
        TodaysMemoryEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodaysMemoryEntry) -> Void) {
        completion(TodaysMemoryEntry(date: .now, snapshot: MemorySnapshot.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodaysMemoryEntry>) -> Void) {
        let entry = TodaysMemoryEntry(date: .now, snapshot: MemorySnapshot.read())
        // The app reloads timelines when the deck or settings change; an hourly
        // wake is a safety net so the count rolls over across midnight.
        let next = Date.now.addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TodaysMemoryWidgetView: View {
    let entry: TodaysMemoryEntry
    @Environment(\.widgetFamily) private var family

    private var dueCount: Int { entry.snapshot?.dueCount ?? 0 }
    private var topCardText: String { entry.snapshot?.topCardText ?? "" }

    var body: some View {
        if dueCount > 0 {
            switch family {
            case .systemSmall: smallView
            default:           mediumView
            }
        } else {
            emptyState
        }
    }

    private var countLabel: String {
        // Automatic pluralisation per locale (same pattern as the app's stats).
        "^[\(dueCount) memory](inflect: true)"
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text("All caught up")
                .font(.system(size: 14, weight: .semibold, design: .serif))
            Text("Nothing to review right now.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(8)
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(countLabel)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .lineLimit(2)
            Text("ready to review")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today's memory")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(countLabel)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .lineLimit(1)
            if !topCardText.isEmpty {
                Text(topCardText)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            Text("Tap to review")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
