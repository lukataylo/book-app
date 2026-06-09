import SwiftUI
import SwiftData

/// Shared visual language for knowledge cards — minimal, iOS-native, no
/// gradients. Category identity is carried by a small tint + symbol on an
/// otherwise glass (material) surface.
enum KnowledgeCardStyle {
    static func tint(for category: String) -> Color {
        switch category {
        case "Principle":    return Color(hex: "6D28D9")
        case "Mental Model": return Color(hex: "1D4ED8")
        case "Habit":        return Color(hex: "047857")
        case "Insight":      return Color(hex: "C2410C")
        case "Warning":      return Color(hex: "B91C1C")
        case "Practice":     return Color(hex: "0E7490")
        default:             return Color(hex: "475569")
        }
    }

    static func symbol(for category: String) -> String {
        switch category {
        case "Principle":    return "key.fill"
        case "Mental Model": return "cube.transparent"
        case "Habit":        return "repeat"
        case "Insight":      return "lightbulb.fill"
        case "Warning":      return "exclamationmark.triangle.fill"
        case "Practice":     return "target"
        default:             return "circle.fill"
        }
    }

}

/// Small category identifier: tinted symbol + label in a frosted capsule.
struct CategoryChip: View {
    let category: String
    var compact = false

    var body: some View {
        let tint = KnowledgeCardStyle.tint(for: category)
        HStack(spacing: 5) {
            Image(systemName: KnowledgeCardStyle.symbol(for: category))
                .font(.system(size: compact ? 9 : 10, weight: .semibold))
            Text(category.uppercased())
                .font(.system(size: compact ? 9 : 11, weight: .bold))
                .tracking(1.1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 5)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}

/// Swipeable deck for one book — the Deepstash-style reading surface.
/// Each card can be saved (→ Saved tab) or shared as text.
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

                deckProgress
                    .padding(.bottom, Theme.Spacing.s)
            }
        }
        .background(Theme.Palette.appBackground.ignoresSafeArea())
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    /// "3 of 12" plus a thin position bar — quieter than page dots at this
    /// card count.
    private var deckProgress: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.divider)
                    Capsule()
                        .fill(Theme.Palette.textPrimary)
                        .frame(width: geo.size.width * CGFloat(index + 1) / CGFloat(max(cards.count, 1)))
                        .animation(.easeOut(duration: 0.2), value: index)
                }
            }
            .frame(width: 120, height: 3)
            Text("\(min(index + 1, cards.count)) of \(cards.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Palette.textSecondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Card \(min(index + 1, cards.count)) of \(cards.count)")
    }

    private func toggleSave(_ card: KnowledgeCard) {
        card.saved.toggle()
        card.savedAt = card.saved ? .now : nil
        try? modelContext.save()
    }
}

/// One rendered knowledge card. Reused at full size in the deck and inside
/// the Saved tab's detail sheet.
struct KnowledgeCardFace: View {
    let card: KnowledgeCard
    var onToggleSave: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                if !card.category.isEmpty {
                    CategoryChip(category: card.category)
                }
                Spacer()
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .accessibilityLabel("Share card")
            }

            Spacer(minLength: 0)

            Text(card.title)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.body)
                .font(.system(size: 16))
                .lineSpacing(5)
                .foregroundStyle(Theme.Palette.textPrimary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(alignment: .center) {
                if let title = card.book?.title {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .lineLimit(1)
                        if let author = card.book?.author, !author.isEmpty {
                            Text(author)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                if let onToggleSave {
                    Button(action: onToggleSave) {
                        Image(systemName: card.saved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                card.saved
                                    ? KnowledgeCardStyle.tint(for: card.category)
                                    : Theme.Palette.textSecondary
                            )
                            .padding(11)
                            .background(Circle().fill(.thinMaterial))
                            .overlay(Circle().strokeBorder(Theme.Palette.divider, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.success, trigger: card.saved)
                    .accessibilityLabel(card.saved ? "Remove from saved" : "Save card")
                }
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard()
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
