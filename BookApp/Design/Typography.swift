import SwiftUI

/// Typography system — confident, native, intentional.
///
/// Titles use **New York** (`.serif` design) for warmth and editorial feel;
/// UI chrome uses **SF Pro** (`.default` design) for clarity. We rely on
/// system fonts at every size so dynamic-type scaling, optical sizing and
/// localisation come for free.
enum Typography {
    /// Hero greeting on the library home — biggest text in the app.
    static let hero          = Font.system(size: 38, weight: .bold,     design: .serif)
    /// Sheet titles, screen titles.
    static let largeTitle    = Font.system(size: 28, weight: .semibold, design: .serif)
    /// "Top selections", "Your shelves", category headings.
    static let sectionTitle  = Font.system(size: 22, weight: .semibold, design: .serif)
    /// Smaller serif heading inside cards.
    static let cardTitle     = Font.system(size: 15, weight: .semibold, design: .serif)
    /// Body copy in lists, forms.
    static let body          = Font.system(size: 16, weight: .regular)
    /// Secondary metadata — authors under a title, helper text.
    static let secondary     = Font.system(size: 13, weight: .regular)
    /// Inline captions — page X of Y, timestamps.
    static let caption       = Font.system(size: 12, weight: .regular)
    /// Tiny meta — chip text, version strings.
    static let micro         = Font.system(size: 11, weight: .medium)

    /// Maps a `ReaderFont` setting to a SwiftUI `Font` at a given point size.
    static func reader(_ readerFont: ReaderFont, size: CGFloat) -> Font {
        switch readerFont {
        case .system: return .system(size: size)
        case .serif:  return .system(size: size, weight: .regular, design: .serif)
        default:      return .custom(readerFont.rawValue, size: size)
        }
    }

    /// Reader body font that scales with Dynamic Type. Used when the
    /// "Use system text size" toggle is on in Reader Settings — the
    /// in-app `fontSize` slider is ignored; the user's iOS-wide
    /// accessibility size drives the rendering instead.
    static func readerDynamic(_ readerFont: ReaderFont) -> Font {
        switch readerFont {
        case .system:
            return .body
        case .serif:
            return .system(.body, design: .serif)
        default:
            // Custom-font path — anchor at .body and let SwiftUI scale.
            // 19pt is the user's default size in the slider, kept as the
            // base so the visual size on a "Large" Dynamic Type setting
            // matches what the slider would have produced.
            return .custom(readerFont.rawValue, size: 19, relativeTo: .body)
        }
    }
}
