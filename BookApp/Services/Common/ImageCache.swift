import Foundation
import ImageIO

#if canImport(UIKit)
import UIKit
import SwiftUI


/// Silent image decoder.
///
/// `UIImage(data:)` and `UIImage(contentsOfFile:)` log "-17102
/// decompressing image -- possibly corrupt" to the console whenever the
/// source bytes are unrecognisable, even though they return `nil`
/// cleanly. There is no Swift-level switch to suppress that message —
/// it's emitted by ImageIO inside the C side of the decode pipeline.
///
/// `CGImageSourceGetStatus` lets us inspect the source's parsed state
/// *before* asking it to produce an image. When the status is
/// `.statusInvalidData` (the underlying cause of -17102) we bail out
/// without ever calling the decoding entry point that would log.
///
/// The output goes through `preparingForDisplay()` so the bitmap is
/// pre-decoded — saves the per-frame stutter on first scroll-into-view.
enum ImageDecoding {

    /// Decode arbitrary in-memory image bytes. Returns nil silently for
    /// corrupt or unknown formats.
    static func decode(data: Data) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary),
              CGImageSourceGetStatus(source) == .statusComplete else {
            return nil
        }
        return imageFromSource(source)
    }

    /// Decode an image file by URL. Routes through `CGImageSource` so a
    /// truncated or corrupt file logs nothing.
    ///
    /// `maxPixelDimension` downsamples on the way in via
    /// `kCGImageSourceCreateThumbnailFromImageAlways` — recommended by
    /// Apple's Image I/O sample for any UI that doesn't need the full
    /// resolution. EPUB figures often arrive at 3-4K which would otherwise
    /// hold ~50MB per figure resident in `InlineImageCache`.
    /// Pass `nil` for a full-resolution decode (e.g. when generating
    /// lock-screen artwork that genuinely needs the source size).
    static func decode(fileURL: URL, maxPixelDimension: Int? = nil) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options as CFDictionary),
              CGImageSourceGetStatus(source) == .statusComplete else {
            return nil
        }
        return imageFromSource(source, maxPixelDimension: maxPixelDimension)
    }

    private static func imageFromSource(_ source: CGImageSource, maxPixelDimension: Int? = nil) -> UIImage? {
        guard CGImageSourceGetCount(source) > 0 else { return nil }
        if let max = maxPixelDimension, max > 0 {
            // CGImageSource can downsample during decode — much cheaper
            // than `cgImage.scale(to:)` after the fact and avoids holding
            // the full-resolution bitmap in memory at any point.
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: max
            ]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary),
                  cg.width > 0, cg.height > 0 else { return nil }
            return UIImage(cgImage: cg)
        }
        let imageOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldAllowFloat: false
        ]
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, imageOptions as CFDictionary),
              cgImage.width > 0, cgImage.height > 0 else {
            return nil
        }
        let raw = UIImage(cgImage: cgImage)
        return raw.preparingForDisplay() ?? raw
    }
}


/// One in-memory cache for every decoded image the app shows — book
/// covers and inline EPUB figures alike. Both are "decode a file off the
/// main thread, keep the bitmap around", so they share one `NSCache`
/// rather than two that differ only in their limits.
///
/// `NSCache` gives us free memory-pressure eviction: when iOS warns
/// about memory the OS purges entries itself.
@MainActor
enum ImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 256
        c.totalCostLimit = 64 * 1024 * 1024
        return c
    }()

    /// Synchronous fast path. Returns nil on a miss — call `prepare` to
    /// populate.
    static func cached(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    /// Decode off the main actor and warm the cache. Idempotent —
    /// concurrent calls for the same key dedupe on the lookup before
    /// decoding.
    ///
    /// `maxPixelDimension` downsamples during decode (see
    /// `ImageDecoding.decode(fileURL:maxPixelDimension:)`). Inline EPUB
    /// figures pass 1600; covers are already small enough to decode whole.
    static func prepare(_ key: String, url: URL, maxPixelDimension: Int? = nil) async -> UIImage? {
        if let hit = cache.object(forKey: key as NSString) { return hit }
        let path = url.path
        let decoded: UIImage? = await Task.detached(priority: .userInitiated) {
            ImageDecoding.decode(fileURL: URL(fileURLWithPath: path), maxPixelDimension: maxPixelDimension)
        }.value
        guard let img = decoded else { return nil }
        let cost = Int(img.size.width * img.size.height * 4)
        cache.setObject(img, forKey: key as NSString, cost: max(cost, 1))
        return img
    }

    static func clear() { cache.removeAllObjects() }
}

/// Book cover, decoded once per book and reused across renders.
struct CachedCoverImage: View {
    let bookID: UUID
    let url: URL
    /// Rendered when the file is missing or fails to decode — keeps the
    /// cell laid out at the same size so scroll position doesn't jump.
    let fallback: () -> AnyView

    @State private var image: UIImage?

    init(bookID: UUID, url: URL, @ViewBuilder fallback: @escaping () -> some View) {
        self.bookID = bookID
        self.url = url
        let wrapped: () -> AnyView = { AnyView(fallback()) }
        self.fallback = wrapped
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                fallback()
            }
        }
        .task(id: bookID) {
            // Shelves recycle cells; without re-reading on id change we
            // would flash the previous book's cover during the decode.
            self.image = ImageCache.cached(bookID.uuidString)
            if self.image != nil { return }
            self.image = await ImageCache.prepare(bookID.uuidString, url: url)
        }
    }
}

/// Inline EPUB figure. Defers the decode to a background task so the
/// first scroll past a figure doesn't hitch.
struct InlineFigureImage: View {
    let url: URL

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                // Reserve a thin placeholder so the surrounding paragraph
                // layout doesn't jump when the bitmap arrives.
                Color.clear.frame(height: 1)
            }
        }
        .task(id: url) {
            self.image = ImageCache.cached(url.path)
            if self.image != nil { return }
            // 1600px keeps figures sharp at the reader's body width on
            // every shipping device; a 4K source would otherwise sit at
            // ~50 MB resident and evict everything else.
            self.image = await ImageCache.prepare(url.path, url: url, maxPixelDimension: 1600)
        }
    }
}
#endif
