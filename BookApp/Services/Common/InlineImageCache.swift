import Foundation
import ImageIO
#if canImport(UIKit)
import UIKit
import SwiftUI

/// In-memory cache for inline EPUB images.
///
/// Two-tier API:
///   - `cached(at:)` is a synchronous fast-path that hits the NSCache and
///     returns immediately when the figure has already been decoded.
///   - `prepare(at:)` does the JPEG decode + `preparingForDisplay()` on a
///     background actor and writes back into the cache. Use this from a
///     `.task` so the first scroll-into-view doesn't stutter on the main
///     thread (the previous implementation could hang the run loop for
///     50–200 ms per figure on first paint).
///
/// `NSCache` gives us free memory-pressure eviction — when iOS warns
/// about memory, the OS purges entries automatically. We don't need to
/// manage that ourselves.
@MainActor
enum InlineImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 64                  // ~64 figures resident in memory
        c.totalCostLimit = 32 * 1024 * 1024 // 32 MB ceiling, then OS-evicted
        return c
    }()

    static func cached(at url: URL) -> UIImage? {
        cache.object(forKey: url.path as NSString)
    }

    /// Decode + warm the cache off the main actor. Returns the cached
    /// image (now decoded) so the call site can update its @State directly.
    /// Routes through `ImageDecoding` so corrupt EPUB figures don't
    /// trigger the "-17102 decompressing image" log spam during scroll.
    static func prepare(at url: URL) async -> UIImage? {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let path = url.path
        let decoded: UIImage? = await Task.detached(priority: .userInitiated) {
            ImageDecoding.decode(fileURL: URL(fileURLWithPath: path))
        }.value
        guard let img = decoded else { return nil }
        let cost = Int(img.size.width * img.size.height * 4)
        cache.setObject(img, forKey: key, cost: max(cost, 1))
        return img
    }

    static func clear() { cache.removeAllObjects() }
}

/// Image view used by the reader for inline EPUB figures. Defers the
/// JPEG decode to a background task so the first scroll past a figure
/// doesn't hitch.
struct InlineFigureImage: View {
    let url: URL

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                // Reserve a thin placeholder so the surrounding paragraph
                // layout doesn't jump when the bitmap arrives.
                Color.clear.frame(height: 1)
            }
        }
        .task(id: url) {
            // Reset before doing any work so a recycled cell doesn't
            // show the previous figure during the async decode.
            self.image = InlineImageCache.cached(at: url)
            if self.image != nil { return }
            self.image = await InlineImageCache.prepare(at: url)
        }
    }
}
#endif
