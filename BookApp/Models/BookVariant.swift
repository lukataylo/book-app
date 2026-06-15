import Foundation
import SwiftData

enum VariantKind: String, Codable, CaseIterable, Sendable {
    case original
    case compressed
    case expanded
    case styled
    case themeOmitted

    var displayName: String {
        switch self {
        case .original:     return "Original"
        case .compressed:   return "Compressed"
        case .expanded:     return "Expanded"
        case .styled:       return "Styled"
        case .themeOmitted: return "Themes omitted"
        }
    }
}

@Model
final class BookVariant {
    var id: UUID = UUID()
    var book: Book?
    var kindRaw: String = VariantKind.original.rawValue
    var targetPages: Int = 0
    var styleReference: String = ""
    var omittedThemes: [String] = []
    var contentBookmark: Data?
    /// Legacy in-row body. Kept for backwards compatibility — new
    /// variants leave this empty and store text at
    /// `BookStore.shared.variantTextURL(bookID:variantID:)`.
    /// `BlobMigration` moves any non-empty values onto disk and clears
    /// them on first launch after the upgrade. SwiftData / CloudKit
    /// don't tolerate megabytes of String per record well; sync stalls
    /// or silently drops oversized fields.
    var contentText: String = ""
    /// Filename within `<bookFolder>` that holds the body text when the
    /// new disk-backed path is in use. Empty string means "fall back to
    /// `contentText`".
    var contentFilename: String = ""
    var generatedAt: Date = Date.now
    var modelUsed: String = ""
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var costUSD: Double = 0
    var sourceVariantID: UUID?
    var label: String = ""

    init(
        id: UUID = UUID(),
        book: Book? = nil,
        kind: VariantKind = .original,
        contentText: String = "",
        contentBookmark: Data? = nil,
        targetPages: Int = 0,
        styleReference: String = "",
        omittedThemes: [String] = [],
        modelUsed: String = "",
        sourceVariantID: UUID? = nil
    ) {
        self.id = id
        self.book = book
        self.kindRaw = kind.rawValue
        self.contentText = contentText
        self.contentBookmark = contentBookmark
        self.targetPages = targetPages
        self.styleReference = styleReference
        self.omittedThemes = omittedThemes
        self.modelUsed = modelUsed
        self.sourceVariantID = sourceVariantID
        self.generatedAt = .now
        self.label = Self.makeLabel(kind: kind, targetPages: targetPages, styleReference: styleReference)
    }

    var kind: VariantKind {
        get { VariantKind(rawValue: kindRaw) ?? .original }
        set { kindRaw = newValue.rawValue }
    }

    static func makeLabel(kind: VariantKind, targetPages: Int, styleReference: String) -> String {
        switch kind {
        case .original:     return "Original"
        case .compressed:   return "Compressed → \(targetPages) pages"
        case .expanded:     return "Expanded → \(targetPages) pages"
        case .styled:       return styleReference.isEmpty ? "Styled" : "Styled like \(styleReference)"
        case .themeOmitted: return "Themes omitted"
        }
    }

    /// Read the variant's body text. Prefers the in-memory
    /// `contentText` (legacy / test path: tests construct variants with
    /// `contentText:` and don't write to disk, and pre-migration users
    /// still have the text in-row). Falls through to the disk file
    /// written by `BookStore.writeVariantText` for migrated and
    /// freshly-imported variants.
    ///
    /// Reads are dispatched to a detached task so multi-MB books don't
    /// block the main thread on first reader open.
    @MainActor
    func loadText() async -> String {
        let inMemory = self.contentText
        if !inMemory.isEmpty { return inMemory }
        guard let bookID = book?.id else { return "" }
        let variantID = self.id
        return await Task.detached(priority: .userInitiated) {
            let url = BookStore.shared.variantTextURL(bookID: bookID, variantID: variantID)
            return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }.value
    }
}
