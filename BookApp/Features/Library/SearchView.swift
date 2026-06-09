import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]
    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var debounceTask: Task<Void, Never>?
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
            // Route through the detail screen like every other path — it
            // owns variant selection and sends PDFs to the PDF reader.
            .navigationDestination(item: $selected) { book in
                BookDetailView(book: book)
            }
            // Debounce keystrokes — without this every character rescans
            // the whole library and re-diffs the LazyVGrid. 250ms keeps
            // the search feeling immediate while letting the user finish
            // typing a word before we do real work.
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

    private var filtered: [Book] {
        guard !debouncedQuery.isEmpty else { return books }
        let q = debouncedQuery.lowercased()
        return books.filter {
            $0.title.lowercased().contains(q)
            || $0.author.lowercased().contains(q)
            || $0.detectedThemes.contains(where: { $0.lowercased().contains(q) })
            || $0.categoryTags.contains(where: { $0.lowercased().contains(q) })
        }
    }
}
