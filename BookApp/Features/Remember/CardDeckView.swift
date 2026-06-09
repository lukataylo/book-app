import SwiftUI
import SwiftData

/// Shared visual language for knowledge cards — gradient per category.
enum KnowledgeCardStyle {
    static func gradient(for category: String) -> LinearGradient {
        let colors: [Color]
        switch category {
        case "Principle":    colors = [Color(hex: "7C3AED"), Color(hex: "4C1D95")]
        case "Mental Model": colors = [Color(hex: "2563EB"), Color(hex: "1E3A8A")]
        case "Habit":        colors = [Color(hex: "059669"), Color(hex: "064E3B")]
        case "Insight":      colors = [Color(hex: "EA580C"), Color(hex: "7C2D12")]
        case "Warning":      colors = [Color(hex: "DC2626"), Color(hex: "7F1D1D")]
        case "Practice":     colors = [Color(hex: "0891B2"), Color(hex: "164E63")]
        default:             colors = [Color(hex: "475569"), Color(hex: "1E293B")]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Swipeable full-bleed deck for one book — the Deepstash-style reading
/// surface. Each card can be saved (→ Saved tab) or shared as text.
struct CardDeckView: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @State private var index = 0

    private var cards: [KnowledgeCard] {
        (book.knowledgeCards ?? []).sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            if cards.isEmpty {
                ContentUnavailableView(
                    "No cards", systemImage: "square.stack",
                    description: Text("This deck is empty.")
                )
            } else {
                TabView(selection: $index) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                        KnowledgeCardFace(card: card) {
                            toggleSave(card)
                        }
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.vertical, Theme.Spacing.s)
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Text("\(min(index + 1, cards.count)) of \(cards.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.bottom, Theme.Spacing.s)
            }
        }
        .background(Theme.Palette.appBackground.ignoresSafeArea())
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func toggleSave(_ card: KnowledgeCard) {
        card.saved.toggle()
        card.savedAt = card.saved ? .now : nil
        try? modelContext.save()
    }
}

/// One rendered knowledge card. Reused at full size in the deck and at
/// reduced size in the Saved tab.
struct KnowledgeCardFace: View {
    let card: KnowledgeCard
    var onToggleSave: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                if !card.category.isEmpty {
                    Text(card.category.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.18)))
                }
                Spacer()
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            Spacer(minLength: 0)

            Text(card.title)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.body)
                .font(.system(size: 16))
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(alignment: .center) {
                if let title = card.book?.title {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                        if let author = card.book?.author, !author.isEmpty {
                            Text(author)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                if let onToggleSave {
                    Button(action: onToggleSave) {
                        Image(systemName: card.saved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Circle().fill(.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(card.saved ? "Remove from saved" : "Save card")
                }
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            KnowledgeCardStyle.gradient(for: card.category)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        )
        .shadow(color: Theme.Palette.bookShadow, radius: 12, x: 0, y: 6)
    }

    private var shareText: String {
        var lines = [card.title, "", card.body]
        if let title = card.book?.title {
            lines.append("")
            lines.append("— from \(title)")
        }
        return lines.joined(separator: "\n")
    }
}
