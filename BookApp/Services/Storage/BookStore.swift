import Foundation

/// Owns the on-disk + iCloud Drive locations for book files and transformation outputs.
/// SwiftData stores metadata only; the binaries live here.
struct BookStore: Sendable {
    static let shared = BookStore()

    private let containerID = "iCloud.com.lukataylor.bookapp"

    /// Root for all book originals and variants. Falls back to the local
    /// app-support directory when iCloud is signed out.
    var rootURL: URL {
        if let cloud = FileManager.default.url(forUbiquityContainerIdentifier: containerID) {
            return cloud.appendingPathComponent("Documents", isDirectory: true)
        }
        // swiftlint:disable:next force_try
        let fallback = try! FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("BookApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    func bookFolder(for bookID: UUID, create: Bool = true) -> URL {
        let folder = rootURL.appendingPathComponent(bookID.uuidString, isDirectory: true)
        if create {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
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
