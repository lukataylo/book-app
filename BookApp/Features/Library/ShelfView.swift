import SwiftUI

/// One horizontal shelf of books for a category. Mirrors the "Top selections
/// for you" layout from the home screen mock.
struct ShelfView: View {
    let title: String
    let subtitle: String?
    let books: [Book]
    let progressMap: [UUID: Double]
    let onSelect: (Book) -> Void
    let onLongPress: ((Book, BookCardAction) -> Void)?

    init(
        title: String,
        subtitle: String? = nil,
        books: [Book],
        progressMap: [UUID: Double] = [:],
        onSelect: @escaping (Book) -> Void,
        onLongPress: ((Book, BookCardAction) -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.books = books
        self.progressMap = progressMap
        self.onSelect = onSelect
        self.onLongPress = onLongPress
    }

    /// Actions surfaced from a long-press on a book card.
    enum BookCardAction { case edit, delete }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.sectionTitle)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.secondary)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                Spacer()
                // "See all" used to live here but pointed nowhere — leaving it
                // out until there's a filtered category screen to push to.
            }
            .padding(.horizontal, Theme.Spacing.l)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    ForEach(books) { book in
                        Button {
                            onSelect(book)
                        } label: {
                            BookCardView(book: book, progress: progressMap[book.id] ?? 0)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if let onLongPress {
                                Button {
                                    onLongPress(book, .edit)
                                } label: {
                                    Label("Edit metadata", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    onLongPress(book, .delete)
                                } label: {
                                    Label("Delete book", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                // The card carries a drop shadow (radius 8, y:4). A
                // horizontal ScrollView clips to its content bounds, so
                // without room on every edge the shadow is sheared off at
                // the top and bottom of the shelf. Pad the scrolled content
                // by the shadow's reach so it renders whole.
                .padding(.vertical, Theme.Spacing.s)
            }
            // Counter the added top/bottom padding so shelf spacing is
            // unchanged — the padding exists only to give the shadow room.
            .padding(.vertical, -Theme.Spacing.s + Theme.Spacing.xs)
        }
    }
}
