import SwiftUI
import SwiftData
import PDFKit

#if canImport(UIKit)
import UIKit
#endif

/// PDF viewer for imported PDF books.
///
/// We render the original PDF via `PDFKit.PDFView` rather than the
/// text-based reader so layouts, embedded images, equations, tables and
/// page geometry survive intact. AI-transformed variants of a PDF still
/// route to `ReaderView` because they're plain text by construction —
/// only `kind == .original` lands here.
///
/// Reading progress is stored as `pdfpage:<n>` in `ReadingProgress.locator`,
/// so resume-on-open lands on the same page even when the document gains
/// or loses pages between sessions (we clamp on read).
struct PDFReaderView: View {
    let book: Book
    let variant: BookVariant

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var document: PDFDocument?
    @State private var loadError: String?
    @State private var currentPage: Int = 0
    @State private var pageCount: Int = 0
    @State private var persistTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let document {
                PDFKitView(
                    document: document,
                    initialPage: initialPageOnLoad(),
                    onPageChange: { idx in
                        currentPage = idx
                        schedulePersist(page: idx)
                    }
                )
                .ignoresSafeArea(edges: .bottom)
            } else if let loadError {
                errorState(loadError)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.Palette.appBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(book.title)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    if pageCount > 0 {
                        Text("Page \(currentPage + 1) of \(pageCount)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
            }
        }
        .task { loadDocument() }
        .onDisappear {
            // Cancel any pending debounced save — leaving it in flight
            // means the persisted page can land *after* a different
            // book's reader has overwritten state and corrupt the resume
            // target.
            persistTask?.cancel()
        }
    }

    // MARK: - Document loading

    private func loadDocument() {
        guard document == nil else { return }
        guard let url = resolvePDFURL() else {
            loadError = "Couldn't locate the original PDF on disk."
            return
        }
        guard let doc = PDFDocument(url: url) else {
            loadError = "PDFKit couldn't open this file. It may be corrupted or password-protected."
            return
        }
        document = doc
        pageCount = doc.pageCount
        currentPage = max(0, min(initialPageOnLoad(), max(doc.pageCount - 1, 0)))
    }

    /// Find the `original.pdf` for this book on disk. We prefer resolving
    /// the saved security-scoped bookmark (handles iCloud Drive items
    /// that move) and fall back to the deterministic path under the
    /// book's folder when the bookmark is unset or stale.
    private func resolvePDFURL() -> URL? {
        if let data = book.originalFileBookmark,
           let resolved = BookStore.shared.resolveBookmark(data),
           FileManager.default.fileExists(atPath: resolved.path) {
            return resolved
        }
        let candidate = BookStore.shared.bookFolder(for: book.id, create: false)
            .appendingPathComponent("original.pdf")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    // MARK: - Resume / persist

    private func initialPageOnLoad() -> Int {
        let variantID = variant.id
        let relevant = (book.progress ?? [])
            .filter { $0.variantID == variantID }
            .max { $0.updatedAt < $1.updatedAt }
        guard let progress = relevant else { return 0 }
        let locator = progress.locator
        if locator.hasPrefix("pdfpage:"),
           let n = Int(locator.dropFirst("pdfpage:".count)) {
            return max(0, n)
        }
        // Fallback: percent-based estimate if the locator is from an
        // earlier session that hadn't standardised the format yet.
        if pageCount > 0 {
            return max(0, min(Int(progress.percent * Double(pageCount)), pageCount - 1))
        }
        return 0
    }

    private func schedulePersist(page: Int) {
        guard pageCount > 0 else { return }
        persistTask?.cancel()
        let percent = Double(page + 1) / Double(pageCount)
        persistTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            updateProgress(page: page, percent: percent)
        }
    }

    private func updateProgress(page: Int, percent: Double) {
        let bookID = book.id
        let variantID = variant.id
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.book?.id == bookID && $0.variantID == variantID }
        )
        let existing = (try? modelContext.fetch(descriptor))?.first
        if let existing {
            existing.percent = percent
            existing.locator = "pdfpage:\(page)"
            existing.updatedAt = .now
        } else {
            let p = ReadingProgress(
                book: book,
                variantID: variantID,
                locator: "pdfpage:\(page)",
                percent: percent
            )
            modelContext.insert(p)
        }
        book.lastOpenedAt = .now
        try? modelContext.save()
    }

    // MARK: - Error state

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("Can't open this PDF")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Back") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - PDFKit bridge

#if canImport(UIKit)

/// `UIViewRepresentable` wrapper around `PDFKit.PDFView`. iOS-Books-style
/// horizontal paging via `usePageViewController(true)`, page-change events
/// surfaced through `onPageChange`. The view is recreated when the document
/// changes (rare — typically once per book open).
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let initialPage: Int
    /// MainActor-typed because the PDFReaderView's `currentPage` /
    /// `schedulePersist` calls are SwiftData-bound and must run on the
    /// main actor. Without the annotation, Swift 6 strict concurrency
    /// warns ("can not be referenced from a nonisolated context") because
    /// the Coordinator that fires this closure is a plain NSObject.
    let onPageChange: @MainActor (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPageChange: onPageChange) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.usePageViewController(false)
        view.pageBreakMargins = .init(top: 8, left: 0, bottom: 8, right: 0)
        view.backgroundColor = .clear
        view.maxScaleFactor = 4.0
        view.minScaleFactor = 0.4

        if initialPage > 0,
           let target = document.page(at: max(0, min(initialPage, document.pageCount - 1))) {
            // PDFView ignores setCurrentPage if called too early; defer
            // to the next runloop so the view has finished laying out
            // its scroll view.
            DispatchQueue.main.async {
                view.go(to: target)
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: view
        )
        // Surface the initial page once the view has had a chance to
        // load — without this, the first page change fires when the user
        // turns past the first page, and the resume locator never gets
        // refreshed for read-from-the-top sessions.
        Task { @MainActor in
            context.coordinator.notifyCurrentPage(of: view)
        }
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
        }
    }

    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    /// `@unchecked Sendable` because the only stored property is a `let`
    /// (immutable after init) and the only methods either run synchronously
    /// from the notification thread or hop to MainActor explicitly. NSObject
    /// can't be Sendable conventionally, but for this read-only Coordinator
    /// the contract holds.
    final class Coordinator: NSObject, @unchecked Sendable {
        let onPageChange: @MainActor (Int) -> Void
        init(onPageChange: @escaping @MainActor (Int) -> Void) {
            self.onPageChange = onPageChange
        }

        @objc func pageChanged(_ notification: Notification) {
            // NotificationCenter dispatches the .PDFViewPageChanged
            // notification on the thread that posted it (main, in
            // PDFKit's case, but we don't rely on that). Hop explicitly
            // to the main actor before invoking the SwiftUI-bound
            // closure so the @MainActor contract is honoured even if
            // PDFKit ever changes its dispatch behaviour.
            guard let view = notification.object as? PDFView else { return }
            Task { @MainActor in self.notifyCurrentPage(of: view) }
        }

        @MainActor
        func notifyCurrentPage(of view: PDFView) {
            guard let document = view.document, let page = view.currentPage else { return }
            let idx = document.index(for: page)
            // PDFKit returns NSNotFound (and bridges to negative) when the
            // page isn't in the document — happens during edits, when a
            // notification fires for an in-flight page move, or on
            // damaged PDFs. Persisting `-1` corrupts the resume locator.
            guard idx >= 0, idx < document.pageCount else { return }
            onPageChange(idx)
        }
    }
}

#else

struct PDFKitView: View {
    let document: PDFDocument
    let initialPage: Int
    let onPageChange: (Int) -> Void
    var body: some View {
        Text("PDF rendering requires UIKit.")
            .foregroundStyle(.secondary)
    }
}

#endif
