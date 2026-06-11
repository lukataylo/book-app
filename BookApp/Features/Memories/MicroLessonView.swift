import SwiftUI
import SwiftData

/// The pleasant face of spaced repetition (spec §2d, PLAN.md §4.4): a short
/// portrait swipe deck generated from a book's key ideas. There is no image
/// generation in the app, so the "illustration" is a house style: one themed
/// SF Symbol per card over a tinted panel (PLAN.md's fixed-icon-system option).
/// The deck ends on a recall beat that can seed the ideas into the review deck.
struct MicroLessonView: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    @State private var added = false

    /// At most a handful of cards so the lesson stays snackable.
    private var ideas: [KeyLearning] {
        Array((book.keyLearnings ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(8))
    }

    private var store: MemoryStore { MemoryStore(context: modelContext) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.Palette.appBackground.ignoresSafeArea()

            if ideas.isEmpty {
                empty
            } else {
                TabView(selection: $page) {
                    ForEach(Array(ideas.enumerated()), id: \.element.id) { index, idea in
                        card(idea, index: index).tag(index)
                    }
                    recallBeat.tag(ideas.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(Theme.Spacing.m)
            }
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Cards

    private func card(_ idea: KeyLearning, index: Int) -> some View {
        let style = MicroLessonStyle.style(forIndex: index, tags: idea.tags)
        return VStack(spacing: Theme.Spacing.l) {
            Spacer()
            Image(systemName: style.symbol)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(style.tint)
                .frame(width: 132, height: 132)
                .background(style.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.xl))

            Text(idea.text)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.l)

            if let title = book.title.isEmpty ? nil : book.title {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(index + 1) of \(ideas.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recallBeat: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            Image(systemName: added ? "checkmark.circle.fill" : "brain.head.profile")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(added ? .green : Theme.Palette.accent)
            Text(added ? "Saved to Memories" : "Keep these?")
                .font(.title2.weight(.semibold))
            Text(added
                 ? "They'll come back for review on a gentle schedule."
                 : "Add these ideas to your review deck so they actually stick.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)

            if !added {
                Button {
                    store.addWholeBook(book)
                    added = true
                } label: {
                    Text("Add to Memories")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.s)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Palette.accent)
                .padding(.horizontal, Theme.Spacing.xl)
            } else {
                Button("Done") { dismiss() }
                    .font(.headline)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var empty: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No ideas yet")
                .font(.title3.weight(.semibold))
            Text("Extract key learnings first, then a micro-lesson appears here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)
            Button("Close") { dismiss() }
                .padding(.top, Theme.Spacing.s)
        }
    }
}

/// House art for micro-lesson cards: a deterministic SF Symbol + tint chosen
/// from the idea's theme tags (falling back to a rotating set keyed by position
/// so a tagless deck still looks varied). Pure and testable.
enum MicroLessonStyle {
    struct Card: Equatable { var symbol: String; var tint: Color }

    /// Theme tag (lowercased substring match) to a symbol.
    static let symbolForTheme: [(needle: String, symbol: String)] = [
        ("habit", "repeat.circle"),
        ("focus", "scope"),
        ("decision", "arrow.triangle.branch"),
        ("money", "dollarsign.circle"),
        ("business", "chart.line.uptrend.xyaxis"),
        ("power", "bolt.circle"),
        ("fear", "exclamationmark.triangle"),
        ("love", "heart"),
        ("time", "hourglass"),
        ("mind", "brain"),
        ("stoic", "leaf"),
        ("history", "clock.arrow.circlepath")
    ]

    /// Fallback rotation so a deck with no recognizable tags still varies.
    static let fallbackSymbols = [
        "lightbulb", "sparkles", "star", "flame", "drop", "circle.hexagongrid"
    ]

    static func style(forIndex index: Int, tags: [String]) -> Card {
        let symbol = symbol(forIndex: index, tags: tags)
        let tint = Theme.BookSpine.color(for: tags)
        return Card(symbol: symbol, tint: tint)
    }

    static func symbol(forIndex index: Int, tags: [String]) -> String {
        let hay = tags.joined(separator: " ").lowercased()
        for entry in symbolForTheme where hay.contains(entry.needle) {
            return entry.symbol
        }
        guard !fallbackSymbols.isEmpty else { return "lightbulb" }
        return fallbackSymbols[index % fallbackSymbols.count]
    }
}
