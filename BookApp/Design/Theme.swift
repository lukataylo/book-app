import SwiftUI

/// Visual tokens shared across every screen. Values inspired by the iOS Books
/// app: warm neutrals, generous whitespace, restrained accent. Reader chrome
/// uses these tokens too, but the `ReaderTheme` for body text is independent
/// (light / sepia / dark / black per the user's setting).
enum Theme {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat  = 8
        static let s: CGFloat   = 12
        static let m: CGFloat   = 16
        static let l: CGFloat   = 24
        static let xl: CGFloat  = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let s: CGFloat  = 8
        static let m: CGFloat  = 14
        static let l: CGFloat  = 20
        static let xl: CGFloat = 28
    }

    enum Palette {
        // Editorial black-and-white — refined, high-contrast, no warmth.
        // Inspired by Things 3, Linear, the iOS Books reader's true-black mode.
        static let appBackground = Color(light: "FFFFFF", dark: "000000")
        // Lifted surface for cards / sheets.
        static let surface       = Color(light: "F5F5F4", dark: "111111")
        // Primary text: pure ink.
        static let textPrimary   = Color(light: "0A0A0A", dark: "FAFAFA")
        // Secondary text: 60% ink, still WCAG-AA against the surface.
        static let textSecondary = Color(light: "6B7280", dark: "9CA3AF")
        // Accent: pure ink. Used for the import button + active-tab tint.
        static let accent        = Color(light: "0A0A0A", dark: "FAFAFA")
        // Soft elevation under book covers.
        static let bookShadow    = Color.black.opacity(0.18)
        // Hairline dividers.
        static let divider       = Color(light: "E5E5E5", dark: "1F1F1F")
    }

    enum BookSpine {
        /// Per-genre spine colors used as fallbacks when no cover is supplied.
        static let palette: [String: Color] = [
            "Self-improvement": Color(hex: "DC2626"),
            "Philosophy":       Color(hex: "7C3AED"),
            "Business":         Color(hex: "0891B2"),
            "Science":          Color(hex: "059669"),
            "Fiction":          Color(hex: "DB2777"),
            "History":          Color(hex: "92400E"),
            "Biography":        Color(hex: "4338CA"),
            "Default":          Color(hex: "475569")
        ]

        static func color(for tags: [String]) -> Color {
            for tag in tags {
                if let c = palette[tag] { return c }
            }
            return palette["Default"]!
        }
    }
}

extension Color {
    init(light: String, dark: String) {
        #if canImport(UIKit)
        self = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
        #elseif canImport(AppKit)
        self = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                ? NSColor(hex: dark)
                : NSColor(hex: light)
        })
        #else
        self = Color(hex: light)
        #endif
    }

    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}

#if canImport(UIKit)
import UIKit
private extension UIColor {
    convenience init(hex: String) {
        let c = hex.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: c).scanHexInt64(&rgb)
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

#if canImport(AppKit)
import AppKit
private extension NSColor {
    convenience init(hex: String) {
        let c = hex.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: c).scanHexInt64(&rgb)
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
