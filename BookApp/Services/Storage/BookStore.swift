import Foundation

/// Owns the on-disk + iCloud Drive locations for book files and transformation outputs.
/// SwiftData stores metadata only; the binaries live here.
///
/// Reference type so `rootURL` can be resolved exactly once and cached —
/// `FileManager.url(forUbiquityContainerIdentifier:)` does a synchronous
/// I/O hop to verify the iCloud token, and the reader was hammering it
/// per inline image render. The container location is fixed for the life
/// of the process so it's safe to cache aggressively.
final class BookStore: @unchecked Sendable {
    static let shared = BookStore()

    private let containerID = "iCloud.com.lukataylor.bookapp"
    /// Cached root after first resolution. `@unchecked Sendable` is correct
    /// here because the only mutation happens once inside `init` and every
    /// subsequent access is a pure read.
    let rootURL: URL

    private init() {
        self.rootURL = Self.resolveRootURL(containerID: "iCloud.com.lukataylor.bookapp")
    }

    /// Falls back through three progressively more-tolerant locations:
    ///   1. iCloud Drive ubiquity container (when iCloud is signed in)
    ///   2. Application Support / BookApp / (when sandboxed write works)
    ///   3. NSTemporaryDirectory / BookApp (last-resort, ephemeral)
    /// We never crash on container resolution — readers shouldn't lose their
    /// place because of an iCloud handshake failure.
    private static func resolveRootURL(containerID: String) -> URL {
        if let cloud = FileManager.default.url(forUbiquityContainerIdentifier: containerID) {
            let docs = cloud.appendingPathComponent("Documents", isDirectory: true)
            try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
            return docs
        }
        if let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            let dir = appSupport.appendingPathComponent("BookApp", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("BookApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    func bookFolder(for bookID: UUID, create: Bool = true) -> URL {
        let folder = rootURL.appendingPathComponent(bookID.uuidString, isDirectory: true)
        if create {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    /// Folder for inline-image bytes extracted on import. Reader paragraphs
    /// containing `[img:<filename>]` resolve to `<imagesFolder>/<filename>`.
    func imagesFolder(for bookID: UUID, create: Bool = true) -> URL {
        let folder = bookFolder(for: bookID, create: create)
            .appendingPathComponent("images", isDirectory: true)
        if create {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    /// Deterministic URL for the file that holds a variant's plain-text
    /// content. Used by the disk-backed `BookVariant.loadText()` so a
    /// multi-MB transform body doesn't ride along through SwiftData /
    /// CloudKit (where it would hit the per-record field-size cap and
    /// stall sync).
    func variantTextURL(bookID: UUID, variantID: UUID, create: Bool = false) -> URL {
        bookFolder(for: bookID, create: create)
            .appendingPathComponent("variant-\(variantID.uuidString).txt")
    }

    /// Deterministic URL for a book's cover image. Stored as a JPEG so a
    /// 200KB cover doesn't sit in CloudKit field-storage on every Book
    /// record.
    func coverURL(bookID: UUID, create: Bool = false) -> URL {
        bookFolder(for: bookID, create: create)
            .appendingPathComponent("cover.jpg")
    }

    /// Atomic write of a variant's text body. Returns true on success so
    /// callers can decide whether to clear the legacy `contentText`
    /// SwiftData field.
    @discardableResult
    func writeVariantText(_ text: String, bookID: UUID, variantID: UUID) -> Bool {
        let url = variantTextURL(bookID: bookID, variantID: variantID, create: true)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    /// Atomic write of a book's cover image bytes.
    @discardableResult
    func writeCover(_ data: Data, bookID: UUID) -> Bool {
        let url = coverURL(bookID: bookID, create: true)
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Copy an imported file into the book's folder, returning a security-scoped bookmark.
    @discardableResult
    func ingestOriginal(from sourceURL: URL, bookID: UUID, format: BookFormat) throws -> (URL, Data) {
        let folder = bookFolder(for: bookID)
        let dest = folder.appendingPathComponent("original.\(format.rawValue)", isDirectory: false)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        // The file picker hands us a security-scoped URL; copy with that scope active.
        let didStartScope = sourceURL.startAccessingSecurityScopedResource()
        defer { if didStartScope { sourceURL.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        let bookmark = try dest.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        return (dest, bookmark)
    }

    /// Save a transformed variant's text body into the book's folder.
    @discardableResult
    func saveVariant(text: String, bookID: UUID, variantID: UUID) throws -> (URL, Data) {
        let folder = bookFolder(for: bookID)
        let dest = folder.appendingPathComponent("variant-\(variantID.uuidString).txt")
        try text.write(to: dest, atomically: true, encoding: .utf8)
        let bookmark = try dest.bookmarkData()
        return (dest, bookmark)
    }

    /// Resolve a stored bookmark back into a usable URL.
    func resolveBookmark(_ data: Data) -> URL? {
        var stale = false
        return try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
    }
}
