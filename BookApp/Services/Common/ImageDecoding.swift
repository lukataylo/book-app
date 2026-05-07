import Foundation
import ImageIO

#if canImport(UIKit)
import UIKit

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
    static func decode(fileURL: URL) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options as CFDictionary),
              CGImageSourceGetStatus(source) == .statusComplete else {
            return nil
        }
        return imageFromSource(source)
    }

    private static func imageFromSource(_ source: CGImageSource) -> UIImage? {
        guard CGImageSourceGetCount(source) > 0 else { return nil }
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

#else

enum ImageDecoding {
    static func decode(data: Data) -> Any? { nil }
    static func decode(fileURL: URL) -> Any? { nil }
}

#endif
