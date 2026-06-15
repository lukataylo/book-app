import Foundation
import ImageIO
#if canImport(UIKit)
import UIKit
import SwiftUI

/// In-memory cache for decoded book cover images.
///
/// `BookCardView` was calling `UIImage(data: book.coverData)` from inside
/// its body, which means SwiftUI re-decoded the JPEG every time the
/// shelf re-rendered (e.g. when reading progress changed for any book in
/// the library). For a 20-book library that's 20 redundant decodes per
/// state change. Decoded UIImages also defer the bitmap render until
/// draw, which causes scroll hitches on first scroll-into-view.
///
/// We key off the book's identity (UUID) rather than the data bytes
/// because covers don't change after import, and identity comparisons
/// are far cheaper than hashing a multi-hundred-KB Data.
@MainActor
enum CoverImageCache {
    private static let cache: NSCache<NSUUID, UIImage> = {
        let c = NSCache<NSUUID, UIImage>()
        c.countLimit = 256                  // covers a comfortable library
        c.totalCostLimit = 64 * 1024 * 1024 // 64 MB before OS-eviction
        return c
    }()

    /// Synchronous lookup. Returns the cached image if present, otherwise
    /// `nil` — call sites should kick off `prepare(for:data:)` to populate.
    static func image(for bookID: UUID) -> UIImage? {
        cache.object(forKey: bookID as NSUUID)
    }

    /// Decode the cover off the main thread, store in the cache, and
    /// publish to subscribers. Idempotent — concurrent calls for the same
    /// book are deduped by the NSCache lookup before decoding.
    ///
    /// Goes through `ImageDecoding.decode` rather than `UIImage(data:)`
    /// directly: UIKit's initialiser logs "-17102 decompressing image"
    /// to the console *before* it returns nil for corrupt sources, and
    /// we have no way to silence that from Swift. The CGImageSource
    /// path checks status first and skips the decode attempt for known-
    /// bad bytes, so the console stays clean.
    static func prepare(for bookID: UUID, data: Data) async -> UIImage? {
        if let cached = cache.object(forKey: bookID as NSUUID) { return cached }
        let decoded: UIImage? = await Task.detached(priority: .userInitiated) {
            ImageDecoding.decode(data: data)
        }.value
        guard let img = decoded else { return nil }
        let cost = Int(img.size.width * img.size.height * 4)
        cache.setObject(img, forKey: bookID as NSUUID, cost: max(cost, 1))
        return img
    }

    /// Variant of `prepare` that reads cover bytes off disk. Used for
    /// books whose cover lives at `BookStore.coverURL(bookID:)` rather
    /// than in the SwiftData row's `coverData` field.
    static func prepare(for bookID: UUID, fileURL: URL) async -> UIImage? {
        if let cached = cache.object(forKey: bookID as NSUUID) { return cached }
        let path = fileURL.path
        let decoded: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let raw = UIImage(contentsOfFile: path) else { return nil }
            return raw.preparingForDisplay() ?? raw
        }.value
        guard let img = decoded else { return nil }
        let cost = Int(img.size.width * img.size.height * 4)
        cache.setObject(img, forKey: bookID as NSUUID, cost: max(cost, 1))
        return img
    }

    static func evict(bookID: UUID) {
        cache.removeObject(forKey: bookID as NSUUID)
    }

    static func clear() { cache.removeAllObjects() }
}

/// Reusable cover view that decodes the JPEG once per book and reuses
/// the bitmap across renders. The cover bytes can come from either the
/// legacy `Book.coverData` field (in-row) or from the on-disk file at
/// `BookStore.coverURL(bookID:)` — the cache keys off `bookID` so both
/// paths share decoded bitmaps.
struct CachedCoverImage: View {
    enum Source {
        case data(Data)
        case file(URL)
    }

    let bookID: UUID
    let source: Source
    /// Fallback rendered when the data fails to decode — keeps the cell
    /// laid out at the same size so the scroll position doesn't jump.
    let fallback: () -> AnyView

    @State private var image: UIImage?

    init(bookID: UUID, source: Source, @ViewBuilder fallback: @escaping () -> some View) {
        self.bookID = bookID
        self.source = source
        let wrapped: () -> AnyView = { AnyView(fallback()) }
        self.fallback = wrapped
    }

    /// Convenience for the legacy in-row data path.
    init(bookID: UUID, data: Data, @ViewBuilder fallback: @escaping () -> some View) {
        self.init(bookID: bookID, source: .data(data), fallback: fallback)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                fallback()
            }
        }
        .task(id: bookID) {
            // LazyVGrid / shelves recycle cells; without nilling the
            // stored image when the bookID changes we'd flash the
            // previous book's cover until the new one finishes decoding.
            // The cache hit path immediately replaces this nil so the
            // user only ever sees a blank cell when the cache truly
            // misses (first-paint of an unseen book).
            self.image = CoverImageCache.image(for: bookID)
            if self.image != nil { return }
            switch source {
            case .data(let data):
                self.image = await CoverImageCache.prepare(for: bookID, data: data)
            case .file(let url):
                self.image = await CoverImageCache.prepare(for: bookID, fileURL: url)
            }
        }
    }
}
#endif
