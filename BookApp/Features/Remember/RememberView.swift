import SwiftUI
import SwiftData

/// Remember tab — Deepstash-style knowledge-card decks, one per book.
/// Books that ship with a summary pack arrive with a curated deck; any other
/// book with text can generate one on demand.
struct RememberView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.title) private var books: [Book]

    @State private var selectedBook: Book?
    @State private var generatingBookID: UUID?
    @State private var errorText: String?
    @State private var query = ""

    private var decks: [Book] {
        applyQuery(books.filter { !($0.knowledgeCards ?? []).isEmpty })
    }

    private var candidates: [Book] {
        applyQuery(books.filter {
            ($0.knowledgeCards ?? []).isEmpty
            && !($0.originalVariant?.contentText.isEmpty ?? true)
        })
    }

    private func applyQuery(_ list: [Book]) -> [Book] {
        guard !query.isEmpty else { return list }
        let q = query.lowercased()
        return list.filter {
            $0.title.lowercased().contains(q) || $0.author.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    header
                    if decks.isEmpty && candidates.isEmpty {
                        emptyState
                    } else {
                        deckGrid
                        if !candidates.isEmpty {
                            generateSection
                        }
                    }
                    Spacer(minLength: Theme.Spacing.xxl)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.m)
            }
            .background(Theme.Palette.appBackground.ignoresSafeArea())
            .searchable(text: $query, prompt: "Search decks")
            .navigationDestination(item: $selectedBook) { book in
                CardDeckView(book: book)
            }
            .alert("Couldn't create cards", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Remember")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("One idea per card. Swipe through a book's deck, save what you want to keep.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    private var deckGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: Theme.Spacing.m)],
            spacing: Theme.Spacing.m
        ) {
            ForEach(decks, id: \.id) { book in
                Button { selectedBook = book } label: {
                    deckTile(book)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func deckTile(_ book: Book) -> some View {
        let cards = book.knowledgeCards ?? []
        let savedCount = cards.filter(\.saved).count
        let topCategory = cards.first?.category ?? ""
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ZStack {
                // Stacked-deck illusion: a quiet card back peeking out
                // behind the frosted front card.
                RoundedRectangle(cornerRadius: Theme.Radius.l, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .rotationEffect(.degrees(2.5))
                    .offset(x: 3, y: 4)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: KnowledgeCardStyle.symbol(for: topCategory))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(KnowledgeCardStyle.tint(for: topCategory))
                        Spacer()
                        Text("\(cards.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .monospacedDigit()
                    }
                    Spacer()
                    Text(cards.first?.title ?? book.title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .padding(Theme.Spacing.m)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .glassCard(cornerRadius: Theme.Radius.l)
            }
            .frame(height: 130)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(savedCount > 0 ? "\(cards.count) cards · \(savedCount) saved" : "\(cards.count) cards")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }

    private var generateSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Create a deck")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
            VStack(spacing: 0) {
                ForEach(candidates, id: \.id) { book in
                    Button {
                        Task { await generate(for: book) }
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            Image(systemName: generatingBookID == book.id ? "hourglass" : "sparkles")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                    .lineLimit(1)
                                Text(generatingBookID == book.id ? "Generating cards…" : "Generate knowledge cards")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(generatingBookID != nil)
                    if book.id != candidates.last?.id {
                        Divider().background(Theme.Palette.divider)
                    }
                }
            }
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "square.stack")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.7))
            Text("No decks yet")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Open a summary from the Read tab, or import a book — every book can become a deck of idea cards.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    private func generate(for book: Book) async {
        guard let text = book.originalVariant?.contentText, !text.isEmpty else { return }
        generatingBookID = book.id
        defer { generatingBookID = nil }
        do {
            _ = try await KnowledgeCardEngine().generate(book: book, source: text, context: modelContext)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        RememberView().modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
