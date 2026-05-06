import WidgetKit
import SwiftUI

struct ContinueReadingWidget: Widget {
    let kind: String = "ContinueReadingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ContinueReadingProvider()) { entry in
            ContinueReadingWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Continue reading")
        .description("Pick up where you left off in BookApp.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ContinueReadingEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct ContinueReadingProvider: TimelineProvider {
    func placeholder(in context: Context) -> ContinueReadingEntry {
        ContinueReadingEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ContinueReadingEntry) -> Void) {
        completion(ContinueReadingEntry(date: .now, snapshot: WidgetSnapshot.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ContinueReadingEntry>) -> Void) {
        let entry = ContinueReadingEntry(date: .now, snapshot: WidgetSnapshot.read())
        // Refresh policy: widget reloads via `WidgetCenter.reloadAllTimelines()`
        // when the main app saves progress, so we just ask iOS to wake us in
        // an hour as a safety net.
        let next = Date.now.addingTimeInterval(60 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct ContinueReadingWidgetView: View {
    let entry: ContinueReadingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snap = entry.snapshot {
            switch family {
            case .systemSmall:  smallView(snap)
            default:            mediumView(snap)
            }
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "books.vertical")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text("Open BookApp to start reading")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(8)
    }

    @ViewBuilder
    private func smallView(_ snap: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            cover(for: snap, side: 56)
                .frame(width: 56, height: 80)
            Text(snap.title)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .lineLimit(2)
            progressBar(percent: snap.percent)
            Text("\(Int(snap.percent * 100))%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func mediumView(_ snap: WidgetSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            cover(for: snap, side: 64)
                .frame(width: 64, height: 96)
            VStack(alignment: .leading, spacing: 6) {
                Text("Continue reading")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(snap.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .lineLimit(2)
                if !snap.author.isEmpty {
                    Text(snap.author)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                progressBar(percent: snap.percent)
                Text("\(Int(snap.percent * 100))% · updated \(snap.updatedAt.formatted(.relative(presentation: .numeric)))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func cover(for snap: WidgetSnapshot, side: CGFloat) -> some View {
        if let url = WidgetSnapshot.coverURL(filename: snap.coverFilename),
           let ui = UIImage(contentsOfFile: url.path) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.secondary.opacity(0.15))
                .overlay(
                    Image(systemName: "book.closed")
                        .foregroundStyle(.secondary)
                )
        }
    }

    private func progressBar(percent: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.2))
                Capsule().fill(.primary)
                    .frame(width: geo.size.width * min(1, max(0, percent)))
            }
        }
        .frame(height: 4)
    }
}
