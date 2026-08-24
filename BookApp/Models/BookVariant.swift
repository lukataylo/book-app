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

    /// Write the variant's body text to its deterministic location under
    /// the book folder. Returns false if the write failed, so the caller
    /// can refuse to persist a variant nobody can read.
    ///
    /// Body text never lives in the SwiftData row: CloudKit silently
    /// drops or stalls on multi-megabyte fields, and a full book is
    /// exactly that.
    @discardableResult
    func writeText(_ text: String) -> Bool {
        guard let bookID = book?.id else { return false }
        return BookStore.shared.writeVariantText(text, bookID: bookID, variantID: id)
    }

    /// Read the variant's body text from disk.
    ///
    /// Reads are dispatched to a detached task so multi-MB books don't
    /// block the main thread on first reader open.
    @MainActor
    func loadText() async -> String {
        guard let bookID = book?.id else { return "" }
        let variantID = self.id
        return await Task.detached(priority: .userInitiated) {
            let url = BookStore.shared.variantTextURL(bookID: bookID, variantID: variantID)
            return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }.value
    }
}
