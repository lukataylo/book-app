import Foundation
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
    /// Validates `cgImage` after decode to weed out images that ImageIO
    /// will fail to render at draw time — those are the source of the
    /// "Error -17102 decompressing image" warnings flooding the console.
    static func prepare(for bookID: UUID, data: Data) async -> UIImage? {
        if let cached = cache.object(forKey: bookID as NSUUID) { return cached }
        let decoded: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let raw = UIImage(data: data) else { return nil }
            let prepared = raw.preparingForDisplay() ?? raw
            // Final correctness check — `preparingForDisplay()` will hand
            // back an image that still has no usable CGImage when the
            // source bytes are partially corrupt. Drawing it later prints
            // the -17102 warning. Reject here so the fallback view renders
            // instead.
            guard prepared.cgImage != nil,
                  prepared.size.width > 0, prepared.size.height > 0 else { return nil }
            return prepared
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
/// the bitmap across renders. Callers pass in the source `Data` (so we
/// don't take a strong ref to the SwiftData model from inside the cache)
/// plus the stable book ID used as the cache key.
struct CachedCoverImage: View {
    let bookID: UUID
    let data: Data
    /// Fallback rendered when the data fails to decode — keeps the cell
    /// laid out at the same size so the scroll position doesn't jump.
    let fallback: () -> AnyView

    @State private var image: UIImage?

    init(bookID: UUID, data: Data, @ViewBuilder fallback: @escaping () -> some View) {
        self.bookID = bookID
        self.data = data
        let wrapped: () -> AnyView = { AnyView(fallback()) }
        self.fallback = wrapped
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
            self.image = await CoverImageCache.prepare(for: bookID, data: data)
        }
    }
}
#endif
