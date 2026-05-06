import SwiftUI
import SwiftData

/// The Bookmarks tab — a visual gallery of every saved highlight and
/// bookmark across the user's library, presented as oversized "wisdom
/// cards" rather than a flat list. Each card pairs the quoted passage
/// with the originating book's cover so the source is glanceable.
///
/// Pre-seeded on first launch from each demo book's `learnings.json`,
/// so a freshly-installed app has a populated, attractive feed.
struct BookmarksGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Annotation.createdAt, order: .reverse) private var annotations: [Annotation]
    @Query(sort: \Bookmark.createdAt,  order: .reverse) private var bookmarks: [Bookmark]
    @Query(sort: \Book.title)                            private var allBooks: [Book]

    @State private var filter: Filter = .all
    @State private var bookFilter: UUID? = nil
    @State private var query: String = ""
    @State private var debouncedQuery: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var selectedBook: Book?

    enum Filter: String, CaseIterable, Identifiable {
        case all, highlights, bookmarks
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all:        return "All"
            case .highlights: return "Highlights"
            case .bookmarks:  return "Bookmarks"
            }
        }
    }

    var body: some View {
        let items = filteredItems()

        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14, pinnedViews: []) {
                    header(count: items.count)
                    filterStrip
                    if !annotations.isEmpty || !bookmarks.isEmpty {
                        bookStrip
                    }
                    if items.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        ForEach(items) { item in
                            BookmarkCard(item: item) {
                                if let book = item.book { selectedBook = book }
                            }
                            .padding(.horizontal, Theme.Spacing.l)
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding(.top, Theme.Spacing.s)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(Theme.Palette.appBackground.ignoresSafeArea())
            .searchable(text: $query, prompt: "Search highlights and bookmarks")
            .navigationTitle("Bookmarks")
            .navigationDestination(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
            // Debounce — annotation/bookmark search runs over the entire
            // saved-passage list across all books; rescanning per keystroke
            // makes typing feel sluggish.
            .onChange(of: query) { _, newValue in
                debounceTask?.cancel()
                debounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    guard !Task.isCancelled else { return }
                    debouncedQuery = newValue
                }
            }
            .onAppear { debouncedQuery = query }
        }
    }

    // MARK: - Subviews

    private func header(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your library, distilled.")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(count == 0
                 ? "Highlight a passage or bookmark a paragraph to see it here."
                 : "\(count) saved \(count == 1 ? "passage" : "passages") across your books.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
    }

    private var filterStrip: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { f in
                Button { filter = f } label: {
                    Text(f.label)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(filter == f
                                           ? Theme.Palette.textPrimary
                                           : Theme.Palette.surface)
                        )
                        .foregroundStyle(filter == f
                                         ? Theme.Palette.appBackground
                                         : Theme.Palette.textPrimary)
                }
                .buttonStyle(.plain)
            }
            if bookFilter != nil {
                Button {
                    bookFilter = nil
                } label: {
                    Label("Clear book", systemImage: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.Palette.surface))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    /// Horizontal strip of book covers — tapping one filters the feed to
    /// passages from that book.
    private var bookStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(booksWithMarks(), id: \.id) { book in
                    Button {
                        bookFilter = (bookFilter == book.id) ? nil : book.id
                    } label: {
                        BookCardView(book: book, width: 52, showsTitle: false)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        bookFilter == book.id
                                            ? Theme.Palette.accent
                                            : Color.clear,
                                        lineWidth: 2.5
                                    )
                            )
                            .opacity(bookFilter == nil || bookFilter == book.id ? 1.0 : 0.4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.6))
            Text("Nothing matches your filters yet.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    /// Books that actually have highlights or bookmarks attached, in the
    /// order they were last saved to.
    private func booksWithMarks() -> [Book] {
        var seen = Set<UUID>()
        var result: [Book] = []
        for ann in annotations {
            if let b = ann.book, !seen.contains(b.id) {
                seen.insert(b.id); result.append(b)
            }
        }
        for bm in bookmarks {
            if let b = bm.book, !seen.contains(b.id) {
                seen.insert(b.id); result.append(b)
            }
        }
        return result
    }

    private func filteredItems() -> [BookmarkItem] {
        var items: [BookmarkItem] = []
        if filter != .bookmarks {
            items += annotations.map { BookmarkItem(annotation: $0) }
        }
        if filter != .highlights {
            items += bookmarks.map { BookmarkItem(bookmark: $0) }
        }
        if let bid = bookFilter {
            items = items.filter { $0.book?.id == bid }
        }
        let q = debouncedQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            items = items.filter {
                $0.body.lowercased().contains(q)
                    || ($0.book?.title.lowercased().contains(q) ?? false)
                    || ($0.book?.author.lowercased().contains(q) ?? false)
            }
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - Card model

/// A unified row that lets the gallery render Annotations and Bookmarks
/// side by side without the consumer caring which underlying type it is.
struct BookmarkItem: Identifiable {
    enum Kind { case highlight, bookmark }
    let id: UUID
    let kind: Kind
    let body: String
    let chapter: String
    let createdAt: Date
    let book: Book?
    let colorHex: String?

    init(annotation: Annotation) {
        self.id = annotation.id
        self.kind = .highlight
        self.body = annotation.quotedText
        self.chapter = annotation.note   // we reuse note for chapter when seeded
        self.createdAt = annotation.createdAt
        self.book = annotation.book
        self.colorHex = annotation.color.hex
    }
    init(bookmark: Bookmark) {
        self.id = bookmark.id
        self.kind = .bookmark
        self.body = bookmark.snippet.isEmpty
            ? (bookmark.label.isEmpty ? "Paragraph \(bookmark.paragraphIndex + 1)" : bookmark.label)
            : bookmark.snippet
        self.chapter = bookmark.label
        self.createdAt = bookmark.createdAt
        self.book = bookmark.book
        self.colorHex = nil
    }
}

// MARK: - Card

private struct BookmarkCard: View {
    let item: BookmarkItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                topRow
                Text(item.body)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .lineLimit(8)
                bottomRow
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.Palette.textSecondary.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var topRow: some View {
        HStack(spacing: 10) {
            kindBadge
            if !item.chapter.isEmpty, item.kind == .highlight {
                Text(item.chapter)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(item.createdAt.formatted(.relative(presentation: .named)))
                .font(.system(size: 11))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    private var kindBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: item.kind == .highlight ? "highlighter" : "bookmark.fill")
                .font(.system(size: 10, weight: .bold))
            Text(item.kind == .highlight ? "HIGHLIGHT" : "BOOKMARK")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(badgeColor.opacity(0.18))
        )
        .foregroundStyle(badgeColor)
    }

    private var bottomRow: some View {
        HStack(spacing: 10) {
            if let book = item.book {
                BookCardView(book: book, width: 32, showsTitle: false)
                VStack(alignment: .leading, spacing: 1) {
                    Text(book.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    private var badgeColor: Color {
        switch item.kind {
        case .highlight: return Color(hex: item.colorHex ?? "#FFC107")
        case .bookmark:  return Theme.Palette.accent
        }
    }
}
