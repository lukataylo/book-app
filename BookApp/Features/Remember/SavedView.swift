import SwiftUI
import SwiftData

/// Saved tab — everything the user chose to keep, in one place:
/// saved knowledge cards (new), key learnings and highlight cards (the
/// pre-redesign Learnings + Bookmarks tabs, unchanged, as segments).
struct SavedView: View {
    private enum Segment: String, CaseIterable, Identifiable {
        case cards      = "Cards"
        case learnings  = "Learnings"
        case highlights = "Highlights"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .cards

    var body: some View {
        VStack(spacing: 0) {
            Picker("Saved content", selection: $segment) {
                ForEach(Segment.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .background(Theme.Palette.appBackground)

            switch segment {
            case .cards:
                SavedCardsView()
            case .learnings:
                // Pre-existing global learnings list — owns its NavigationStack.
                LearningsListView()
            case .highlights:
                // Pre-existing highlights gallery — owns its NavigationStack.
                BookmarksGalleryView()
            }
        }
        .background(Theme.Palette.appBackground.ignoresSafeArea())
    }
}

/// Saved knowledge cards across every book.
private struct SavedCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<KnowledgeCard> { $0.saved },
        sort: \KnowledgeCard.savedAt,
        order: .reverse
    ) private var cards: [KnowledgeCard]

    @State private var expandedCard: KnowledgeCard?

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    ContentUnavailableView(
                        "Nothing saved yet",
                        systemImage: "bookmark",
                        description: Text("Tap the bookmark on any knowledge card in the Remember tab and it will live here.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.m) {
                            ForEach(cards, id: \.id) { card in
                                Button { expandedCard = card } label: {
                                    savedRow(card)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        unsave(card)
                                    } label: {
                                        Label("Remove from Saved", systemImage: "bookmark.slash")
                                    }
                                    ShareLink(item: shareText(for: card)) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.vertical, Theme.Spacing.m)
                    }
                }
            }
            .background(Theme.Palette.appBackground.ignoresSafeArea())
            .navigationTitle("Saved cards")
            .sheet(item: $expandedCard) { card in
                KnowledgeCardFace(card: card) {
                    card.saved.toggle()
                    card.savedAt = card.saved ? .now : nil
                    try? modelContext.save()
                }
                .padding(Theme.Spacing.l)
                .presentationDetents([.large])
                .presentationBackground(Theme.Palette.appBackground)
            }
        }
    }

    private func savedRow(_ card: KnowledgeCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !card.category.isEmpty {
                    Text(card.category.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.18)))
                }
                Spacer()
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text(card.title)
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Text(card.body)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            if let title = card.book?.title {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            KnowledgeCardStyle.gradient(for: card.category)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous))
        )
    }

    private func unsave(_ card: KnowledgeCard) {
        card.saved = false
        card.savedAt = nil
        try? modelContext.save()
    }

    private func shareText(for card: KnowledgeCard) -> String {
        var lines = [card.title, "", card.body]
        if let title = card.book?.title {
            lines.append("")
            lines.append("— from \(title)")
        }
        return lines.joined(separator: "\n")
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        SavedView().modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
