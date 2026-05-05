import SwiftUI

/// One horizontal shelf of books for a category. Mirrors the "Top selections
/// for you" layout from the home screen mock.
struct ShelfView: View {
    let title: String
    let subtitle: String?
    let books: [Book]
    let onSelect: (Book) -> Void

    init(
        title: String,
        subtitle: String? = nil,
        books: [Book],
        onSelect: @escaping (Book) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.books = books
        self.onSelect = onSelect
    }

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
                            BookCardView(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xs)
            }
        }
    }
}
