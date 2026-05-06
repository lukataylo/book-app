import Foundation
import SwiftData

enum ReaderTheme: String, Codable, CaseIterable, Sendable {
    case light, sepia, dark, black

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .sepia: return "Sepia"
        case .dark:  return "Dark"
        case .black: return "Black"
        }
    }
}

enum ReaderMargin: String, Codable, CaseIterable, Sendable {
    case narrow, medium, wide

    var horizontalPadding: Double {
        switch self {
        case .narrow: return 22
        case .medium: return 34
        case .wide:   return 52
        }
    }
}

enum ReaderFont: String, Codable, CaseIterable, Sendable {
    case system          = "system"
    case serif           = "serif"
    case iowanOldStyle   = "Iowan Old Style"
    case charter         = "Charter"
    case georgia         = "Georgia"
    case palatino        = "Palatino"
    case newYork         = "New York"
    case atkinsonHyper   = "Atkinson Hyperlegible"
    case openDyslexic    = "OpenDyslexic"

    var displayName: String { rawValue }
}

@Model
final class ReaderSettings {
    var id: UUID = UUID()
    var fontRaw: String = ReaderFont.iowanOldStyle.rawValue
    var fontSize: Double = 19
    var lineSpacing: Double = 1.55
    var marginRaw: String = ReaderMargin.medium.rawValue
    var themeRaw: String = ReaderTheme.light.rawValue
    var paragraphSpacing: Double = 8
    var hyphenation: Bool = true
    var pageTurnAnimation: Bool = true
    /// When `true`, the reader's `ScrollView` snaps to viewport boundaries so
    /// each scroll lands on a "page" rather than mid-paragraph.
    var paginatedScroll: Bool = false
    /// Drop caps on the first paragraph after a `# Heading` line.
    var dropCaps: Bool = true
    /// What appears in the bottom bar's left slot.
    var progressIndicatorRaw: String = ProgressIndicatorStyle.timeLeft.rawValue

    init(id: UUID = UUID()) {
        self.id = id
    }

    var font: ReaderFont {
        get { ReaderFont(rawValue: fontRaw) ?? .iowanOldStyle }
        set { fontRaw = newValue.rawValue }
    }

    var margin: ReaderMargin {
        get { ReaderMargin(rawValue: marginRaw) ?? .medium }
        set { marginRaw = newValue.rawValue }
    }

    var theme: ReaderTheme {
        get { ReaderTheme(rawValue: themeRaw) ?? .light }
        set { themeRaw = newValue.rawValue }
    }

    var progressIndicator: ProgressIndicatorStyle {
        get { ProgressIndicatorStyle(rawValue: progressIndicatorRaw) ?? .timeLeft }
        set { progressIndicatorRaw = newValue.rawValue }
    }
}

enum ProgressIndicatorStyle: String, Codable, CaseIterable, Sendable {
    case timeLeft     = "timeLeft"
    case pageCount    = "pageCount"
    case progressBar  = "progressBar"

    var displayName: String {
        switch self {
        case .timeLeft:    return "Time left"
        case .pageCount:   return "Page count"
        case .progressBar: return "Progress bar"
        }
    }
}
