import Foundation
import SwiftData

enum AnnotationColor: String, Codable, CaseIterable, Sendable {
    case yellow, green, blue, pink, purple

    var hex: String {
        switch self {
        case .yellow: return "#FFE082"
        case .green:  return "#A5D6A7"
        case .blue:   return "#90CAF9"
        case .pink:   return "#F8BBD0"
        case .purple: return "#CE93D8"
        }
    }
}

@Model
final class Annotation {
    var id: UUID = UUID()
    var book: Book?
    var variantID: UUID?
    var locator: String = ""
    var quotedText: String = ""
    var note: String = ""
    var colorRaw: String = AnnotationColor.yellow.rawValue
    var createdAt: Date = Date.now
    /// Wall-clock timestamp of the last in-app edit. SwiftData + CloudKit
    /// resolve concurrent edits with last-write-wins; this field doesn't
    /// change that, but it gives a future "show conflicting edits" UI
    /// (or a manual reconciliation tool) the data it needs to detect
    /// when two devices touched the same row in overlapping windows.
    /// Optional default keeps the SwiftData migration silent for users
    /// upgrading from a pre-`lastEditedAt` build.
    var lastEditedAt: Date? = Date.now

    init(
        id: UUID = UUID(),
        book: Book? = nil,
        variantID: UUID? = nil,
        locator: String = "",
        quotedText: String = "",
        note: String = "",
        color: AnnotationColor = .yellow
    ) {
        self.id = id
        self.book = book
        self.variantID = variantID
        self.locator = locator
        self.quotedText = quotedText
        self.note = note
        self.colorRaw = color.rawValue
        self.createdAt = .now
        self.lastEditedAt = .now
    }

    var color: AnnotationColor {
        get { AnnotationColor(rawValue: colorRaw) ?? .yellow }
        set {
            colorRaw = newValue.rawValue
            lastEditedAt = .now
        }
    }

    /// Bump `lastEditedAt` after mutating `note`. Call sites must use
    /// this rather than poking `note` directly so two-device conflict
    /// detection has a reliable ordering signal.
    func updateNote(_ value: String) {
        note = value
        lastEditedAt = .now
    }
}
