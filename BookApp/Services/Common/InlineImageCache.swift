import Foundation
#if canImport(UIKit)
import UIKit

/// In-memory cache for inline EPUB images so the reader doesn't re-decode
/// every figure on every scroll frame. `UIImage(contentsOfFile:)` lazily
/// decodes the JPEG only when the image is rendered, which means each
/// scroll re-paint of a figure can stutter for 8–30ms on older devices.
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

    /// Load and cache the image at `url`. Returns nil if the file is
    /// missing or the bytes can't be decoded.
    static func image(at url: URL) -> UIImage? {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        // Pre-decode once on first load so the first scroll-into-view is
        // smooth — `UIImage(contentsOfFile:)` defers decode until draw.
        let decoded = image.preparingForDisplay() ?? image
        let cost = Int(decoded.size.width * decoded.size.height * 4)
        cache.setObject(decoded, forKey: key, cost: max(cost, 1))
        return decoded
    }

    static func clear() { cache.removeAllObjects() }
}
#endif
