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
    var contentText: String = ""
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
}
