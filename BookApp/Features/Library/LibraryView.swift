import SwiftUI
import SwiftData

/// Library home — matches the first screenshot. Greeting header, search,
/// "Top selections" carousel, then one shelf per category (auto-tagged
/// during import by the local LLM). Empty state offers an import button.
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.lastOpenedAt, order: .reverse) private var books: [Book]
    @Query(sort: \ReadingProgress.updatedAt, order: .reverse) private var allProgress: [ReadingProgress]

    @State private var searchText = ""
    @State private var presentingPicker = false
    @State private var selectedBook: Book?
    @State private var resumeBook: Book?
    @State private var importErrorMessage: String?
    @State private var deleteCandidate: Book?
    @State private var editingBook: Book?

    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Compute the derived collections ONCE per body evaluation rather
        // than recomputing inside every subview that consumes them. SwiftUI
        // re-runs `body` on any observed state change, so without this the
        // shelves and the continue-reading card walked the progress array
        // three times per render.
        let progress = Self.buildProgressMap(allProgress)
        let groups = Self.buildCategoryGroups(books)
        let resume = Self.firstResumeCandidate(allProgress)
        let query = searchText.trimmingCharacters(in: .whitespaces)

        NavigationStack {
            ScrollView {
                // Books-style section rhythm: more air between sections
                // (xl) than inside them.
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header
                    searchBar
                    if books.isEmpty {
                        emptyState
                    } else if !query.isEmpty {
                        searchResults(for: query)
                    } else {
                        if let resume {
                            continueCard(book: resume.book, percent: resume.percent)
                                .padding(.horizontal, Theme.Spacing.l)
                        }
                        recentShelf(progress: progress)
                        ForEach(groups, id: \.0) { (category, list) in
                            ShelfView(
                                title: category,
                                books: list,
                                progressMap: progress,
                                onSelect: { book in selectedBook = book },
                                onLongPress: { book, action in
                                    handleCardAction(book: book, action: action)
                                }
                            )
                        }
                    }
                    Spacer(minLength: Theme.Spacing.xxl)
                }
                .padding(.top, Theme.Spacing.m)
            }
            .scrollDismissesKeyboard(.immediately)
            // Tap on the empty area below content closes the keyboard without
            // blocking scroll gestures (background hit-test, not a tap on
            // content rows).
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { searchFocused = false }
            )
            .background(Theme.Palette.appBackground.ignoresSafeArea())
            .toolbar {
                // One search affordance only (the inline field below the
                // hero); the toolbar keeps just the import action.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentingPicker = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(.title2, weight: .medium))
                            .foregroundStyle(Theme.Palette.accent)
                    }
                    .accessibilityLabel("Import a book")
                }
            }
            .sheet(isPresented: $presentingPicker) {
                DocumentPickerView { urls in
                    Task { await importPicked(urls) }
                }
            }
            .navigationDestination(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
            // Books-style one-tap resume: the continue card opens the
            // reader directly instead of detouring through the detail
            // screen. PDFs keep their PDFKit reader.
            .navigationDestination(item: $resumeBook) { book in
                if let original = book.originalVariant {
                    if book.format == .pdf {
                        PDFReaderView(book: book, variant: original)
                    } else {
                        ReaderView(book: book, variant: original)
                    }
                }
            }
            .alert("Couldn't import", isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "")
            }
            .alert("Delete this book?", isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let b = deleteCandidate { performDelete(b) }
                    deleteCandidate = nil
                }
                Button("Cancel", role: .cancel) { deleteCandidate = nil }
            } message: {
                Text("\(deleteCandidate?.title ?? "This book") and its variants, learnings, and highlights will be removed from this device.")
            }
            .sheet(item: $editingBook) { book in
                EditBookMetadataSheet(book: book)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Progress + continue-reading

    private struct ContinueCandidate {
        let book: Book
        let percent: Double
        let updatedAt: Date
    }

    private static func buildProgressMap(_ all: [ReadingProgress]) -> [UUID: Double] {
        var map: [UUID: Double] = [:]
        for p in all {
            guard let bookID = p.book?.id else { continue }
            map[bookID] = max(map[bookID] ?? 0, p.percent)
        }
        return map
    }

    private static func buildCategoryGroups(_ books: [Book]) -> [(String, [Book])] {
        var buckets: [String: [Book]] = [:]
        for book in books {
            let cat = book.categoryTags.first ?? "Uncategorized"
            buckets[cat, default: []].append(book)
        }
        return buckets.sorted { $0.key < $1.key }
    }

    private static func firstResumeCandidate(_ all: [ReadingProgress]) -> ContinueCandidate? {
        // `allProgress` already arrives sorted by updatedAt desc — so the
        // first valid hit is the most recent one. Avoids a full sort.
        for p in all {
            if let book = p.book, p.percent > 0.005 {
                return ContinueCandidate(book: book, percent: p.percent, updatedAt: p.updatedAt)
            }
        }
        return nil
    }

    @ViewBuilder
    private func continueCard(book: Book, percent: Double) -> some View {
        Button {
            resumeBook = book
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                BookCardView(book: book, width: 56, showsTitle: false, progress: percent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Continue reading")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .textCase(.uppercase)
                    Text(book.title)
                        .font(.system(.callout, design: .serif, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    Text("\(Int(percent * 100))% complete · \(book.author)")
                        .font(.system(.caption))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary.opacity(0.5))
            }
            .padding(Theme.Spacing.s)
            .glassCard(cornerRadius: Theme.Radius.m)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card actions

    private func handleCardAction(book: Book, action: ShelfView.BookCardAction) {
        switch action {
        case .edit:   editingBook = book
        case .delete: deleteCandidate = book
        }
    }

    private func performDelete(_ book: Book) {
        // Delete the SwiftData record on the main actor (cheap), then move
        // the on-disk folder removal off the main thread — it can be slow
        // for image-heavy books and we don't want the alert dismiss to
        // hitch.
        let bookID = book.id
        modelContext.delete(book)
        try? modelContext.save()
        Task.detached(priority: .utility) {
            let folder = BookStore.shared.bookFolder(for: bookID, create: false)
            try? FileManager.default.removeItem(at: folder)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greetingName.isEmpty ? "Welcome." : "Hi \(greetingName),")
                .font(.system(.body, weight: .regular))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("Sharpen your mind with great books.")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.xs)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Palette.textSecondary)
            TextField("Search books, themes, learnings…", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .submitLabel(.done)
                .onSubmit { searchFocused = false }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Clear search")
            } else if searchFocused {
                Button("Cancel") {
                    searchFocused = false
                }
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Palette.textPrimary)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                .strokeBorder(Theme.Palette.divider, lineWidth: 0.5)
        )
        .padding(.horizontal, Theme.Spacing.l)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: searchFocused)
    }

    /// Live results for the home search field — title, author, category and
    /// theme matches across the whole shelf.
    @ViewBuilder
    private func searchResults(for query: String) -> some View {
        let q = query.lowercased()
        let matches = books.filter {
            $0.title.lowercased().contains(q)
            || $0.author.lowercased().contains(q)
            || $0.detectedThemes.contains(where: { $0.lowercased().contains(q) })
            || $0.categoryTags.contains(where: { $0.lowercased().contains(q) })
        }
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(matches.isEmpty ? "No matches" : "Results")
                .font(Typography.sectionTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, Theme.Spacing.l)
            if matches.isEmpty {
                Text("Nothing on your shelf matches \"\(query)\".")
                    .font(Typography.secondary)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.horizontal, Theme.Spacing.l)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110), spacing: Theme.Spacing.m)],
                    alignment: .leading,
                    spacing: Theme.Spacing.l
                ) {
                    ForEach(matches, id: \.id) { book in
                        Button { selectedBook = book } label: {
                            BookCardView(book: book, width: 110)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "books.vertical")
                .font(.system(.largeTitle, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.7))
                .padding(.bottom, Theme.Spacing.xs)
            Text("Your shelf is empty")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Import an epub, pdf, or mobi to get started.")
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)
            Button {
                presentingPicker = true
            } label: {
                Label("Import a book", systemImage: "square.and.arrow.down")
                    .font(.system(.callout, weight: .semibold))
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.s + 2)
                    .background(Theme.Palette.accent)
                    // Inverted ink — readable in both color schemes.
                    .foregroundStyle(Theme.Palette.appBackground)
                    .clipShape(Capsule())
            }
            .padding(.top, Theme.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    private func recentShelf(progress: [UUID: Double]) -> some View {
        let recent = Array(books.prefix(8))
        return ShelfView(
            title: "Recent",
            subtitle: nil,
            books: recent,
            progressMap: progress,
            onSelect: { book in selectedBook = book },
            onLongPress: { book, action in handleCardAction(book: book, action: action) }
        )
    }

    private var greetingName: String {
        // iOS 16+ returns a generic device name unless the app declares the
        // Personal Information entitlement, so we don't try to be clever —
        // just a friendly default. The user can override in Settings later.
        let trimmed = displayUserName().trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "" : trimmed
    }

    private func displayUserName() -> String {
        #if canImport(UIKit)
        let raw = UIDevice.current.name
        // Strip generic device-name prefixes ("iPhone", "iPad", etc.) — those
        // come back when the entitlement isn't granted.
        let lower = raw.lowercased()
        let generic = ["iphone", "ipad", "ipod", "mac"]
        if generic.contains(where: { lower == $0 || lower.hasPrefix($0 + " ") }) { return "" }
        // "Luka's iPhone" → "Luka"
        return String(raw.split(separator: "'").first ?? "")
        #else
        return ""
        #endif
    }

    @MainActor
    private func importPicked(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        let service = ImportService(modelContext: modelContext)
        for url in urls {
            do {
                _ = try await service.importBook(from: url)
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }
}

#if canImport(UIKit)
import UIKit
#endif

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        LibraryView().modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
