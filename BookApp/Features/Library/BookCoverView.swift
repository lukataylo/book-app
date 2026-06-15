import SwiftUI

/// The single source of truth for rendering a book's cover, so the shelf, the
/// search grid, and the detail screen can never drift apart or re-decode
/// differently. Resolution order:
///   1. designed vector cover (`Covers.xcassets`, authored 2:3 → fills the
///      2:3 frame with no crop),
///   2. disk-backed raster via `CachedCoverImage` (off-thread decode + cache),
///   3. legacy in-row `coverData` (also via the cache),
///   4. generated Idea-Glyph cover.
///
/// Decorative for VoiceOver: the whole cover is `accessibilityHidden`, so the
/// designed/generated artwork never leaks an asset filename or double-reads the
/// title — the surrounding card/detail supplies the spoken label.
struct BookCoverView: View {
    let book: Book

    var body: some View {
        cover.accessibilityHidden(true)
    }

    @ViewBuilder
    private var cover: some View {
        #if canImport(UIKit)
        if let asset = CoverArt.designedAssetName(for: book) {
            Image(asset)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if !book.coverFilename.isEmpty {
            CachedCoverImage(bookID: book.id, source: .file(BookStore.shared.coverURL(bookID: book.id))) {
                GeneratedCoverView(book: book)
            }
        } else if let data = book.coverData {
            CachedCoverImage(bookID: book.id, source: .data(data)) {
                GeneratedCoverView(book: book)
            }
        } else {
            GeneratedCoverView(book: book)
        }
        #else
        if let data = book.coverImageData(),
           let image = BookCardView.platformImage(from: data) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            GeneratedCoverView(book: book)
        }
        #endif
    }
}
