import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]
    @State private var query = ""
    @State private var selected: Book?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.Palette.textSecondary)
                    TextField("Search titles, authors, themes…", text: $query)
                        .textFieldStyle(.plain)
                }
                .padding(Theme.Spacing.m)
                .background(Theme.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
                .padding(.horizontal, Theme.Spacing.l)

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 130), spacing: Theme.Spacing.m)],
                        alignment: .leading,
                        spacing: Theme.Spacing.l
                    ) {
                        ForEach(filtered) { book in
                            Button { selected = book } label: {
                                BookCardView(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                }
            }
            .background(Theme.Palette.appBackground.ignoresSafeArea())
            .navigationTitle("Search")
            .navigationDestination(item: $selected) { book in
                ReaderView(book: book)
            }
        }
    }

    private var filtered: [Book] {
        guard !query.isEmpty else { return books }
        let q = query.lowercased()
        return books.filter {
            $0.title.lowercased().contains(q)
            || $0.author.lowercased().contains(q)
            || $0.detectedThemes.contains(where: { $0.lowercased().contains(q) })
            || $0.categoryTags.contains(where: { $0.lowercased().contains(q) })
        }
    }
}
