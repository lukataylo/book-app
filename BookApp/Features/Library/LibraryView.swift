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
    @State private var importErrorMessage: String?
    @State private var deleteCandidate: Book?
    @State private var editingBook: Book?

    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    header
                    searchBar
                    if books.isEmpty {
                        emptyState
                    } else {
                        if let resume = continueCandidate() {
                            continueCard(book: resume.book, percent: resume.percent)
                                .padding(.horizontal, Theme.Spacing.l)
                        }
                        topSelections
                        ForEach(categoryGroups, id: \.0) { (category, list) in
                            ShelfView(
                                title: category,
                                books: list,
                                progressMap: progressMap,
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentingPicker = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Theme.Palette.accent)
                    }
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

    private var progressMap: [UUID: Double] {
        var map: [UUID: Double] = [:]
        for p in allProgress {
            guard let bookID = p.book?.id else { continue }
            map[bookID] = max(map[bookID] ?? 0, p.percent)
        }
        return map
    }

    private struct ContinueCandidate {
        let book: Book
        let percent: Double
        let updatedAt: Date
    }

    private func continueCandidate() -> ContinueCandidate? {
        let candidates = allProgress
            .compactMap { p -> ContinueCandidate? in
                guard let book = p.book, p.percent > 0.005 else { return nil }
                return ContinueCandidate(book: book, percent: p.percent, updatedAt: p.updatedAt)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
        return candidates.first
    }

    @ViewBuilder
    private func continueCard(book: Book, percent: Double) -> some View {
        Button {
            selectedBook = book
        } label: {
            HStack(spacing: 14) {
                BookCardView(book: book, width: 56, showsTitle: false, progress: percent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Continue reading")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .textCase(.uppercase)
                    Text(book.title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    Text("\(Int(percent * 100))% complete · \(book.author)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                    .fill(Theme.Palette.surface)
            )
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
        // Remove the on-disk book folder if it exists.
        let folder = BookStore.shared.bookFolder(for: book.id, create: false)
        try? FileManager.default.removeItem(at: folder)
        modelContext.delete(book)
        try? modelContext.save()
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greetingName.isEmpty ? "Welcome." : "Hi \(greetingName),")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("Sharpen your\nmind with\ngreat books.")
                .font(.system(size: 38, weight: .bold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .lineSpacing(-2)
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
                }
            } else if searchFocused {
                Button("Cancel") {
                    searchFocused = false
                }
                .font(.system(size: 14))
                .foregroundStyle(Theme.Palette.textPrimary)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        .padding(.horizontal, Theme.Spacing.l)
        .animation(.easeInOut(duration: 0.18), value: searchFocused)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "books.vertical")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.7))
                .padding(.bottom, Theme.Spacing.xs)
            Text("Your shelf is empty")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Import an epub, pdf, or mobi to get started.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)
            Button {
                presentingPicker = true
            } label: {
                Label("Import a book", systemImage: "square.and.arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.s + 2)
                    .background(Theme.Palette.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, Theme.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    private var topSelections: some View {
        let recent = Array(books.prefix(8))
        return ShelfView(
            title: "Top selections for you",
            subtitle: "Based on what you're reading",
            books: recent,
            progressMap: progressMap,
            onSelect: { book in selectedBook = book },
            onLongPress: { book, action in handleCardAction(book: book, action: action) }
        )
    }

    private var categoryGroups: [(String, [Book])] {
        var buckets: [String: [Book]] = [:]
        for book in books {
            let cat = book.categoryTags.first ?? "Uncategorized"
            buckets[cat, default: []].append(book)
        }
        return buckets.sorted { $0.key < $1.key }
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
