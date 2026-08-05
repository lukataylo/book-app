import SwiftUI
import SwiftData

/// Search tab — one field over both things a reader looks for: a book on
/// the shelf, and a passage they kept out of one.
///
/// Deliberately not full-text over book bodies. That already exists, per
/// book, in the reader's Search-in-book sheet, and doing it here would
/// mean reading every variant off disk on each query. Searching inside
/// one book is a different job from finding which book to open.
struct SearchView: View {
    @Query(sort: \Book.title) private var books: [Book]
    @Query(sort: \Annotation.createdAt, order: .reverse) private var annotations: [Annotation]

    @State private var query = ""
    @State private var selectedBook: Book?

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    prompt
                } else if matchedBooks.isEmpty && matchedPassages.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    results
                }
            }
            .background(Theme.Palette.appBackground.ignoresSafeArea())
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Books, authors, themes, highlights")
            .navigationDestination(item: $selectedBook) { BookDetailView(book: $0) }
        }
    }

    // MARK: - Results

    private var results: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if !matchedBooks.isEmpty {
                    section("Books") {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 110), spacing: Theme.Spacing.m)],
                            alignment: .leading,
                            spacing: Theme.Spacing.l
                        ) {
                            ForEach(matchedBooks, id: \.id) { book in
                                Button { selectedBook = book } label: {
                                    BookCardView(book: book, width: 110)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                if !matchedPassages.isEmpty {
                    section("Highlights") {
                        VStack(spacing: Theme.Spacing.m) {
                            ForEach(matchedPassages, id: \.id) { passage in
                                Button { selectedBook = passage.book } label: {
                                    passageRow(passage)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Spacer(minLength: Theme.Spacing.xxl)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.m)
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            content()
        }
    }

    private func passageRow(_ passage: Annotation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(passage.quotedText)
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            if let title = passage.book?.title {
                Text(title)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
    }

    private var prompt: some View {
        ContentUnavailableView(
            "Search your library",
            systemImage: "magnifyingglass",
            description: Text("Find a book by title, author or theme — or a passage you highlighted.")
        )
    }

    // MARK: - Matching

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private var matchedBooks: [Book] {
        let q = normalizedQuery
        guard !q.isEmpty else { return [] }
        return books.filter {
            $0.title.lowercased().contains(q)
            || $0.author.lowercased().contains(q)
            || $0.detectedThemes.contains { $0.lowercased().contains(q) }
            || $0.categoryTags.contains { $0.lowercased().contains(q) }
        }
    }

    private var matchedPassages: [Annotation] {
        let q = normalizedQuery
        guard !q.isEmpty else { return [] }
        return annotations.filter {
            $0.quotedText.lowercased().contains(q) || $0.note.lowercased().contains(q)
        }
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        SearchView().modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
