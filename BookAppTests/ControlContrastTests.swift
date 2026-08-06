import Foundation
import Testing
import SwiftUI
import UIKit
@testable import BookApp

/// A UISwitch knob is always white. Any colour used as the "on" fill has
/// to stay clear of white in both schemes, or the control disappears —
/// which is what `accent` did in dark mode, where it resolves to #FAFAFA.
@MainActor
struct ControlContrastTests {

    private func luminance(_ color: Color, _ style: UIUserInterfaceStyle) -> Double {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let ui = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        // Rec. 709 relative luminance, enough to answer "is this white?"
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    @Test
    func switchedOnFillContrastsWithAWhiteKnobInBothSchemes() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let l = luminance(Theme.Palette.controlOn, style)
            #expect(l < 0.6, "controlOn is too light in \(style == .dark ? "dark" : "light") mode (\(l)); a white knob vanishes on it")
        }
    }

    @Test
    func accentIsStillUnsuitableForThisJob() {
        // Documents why controlOn exists rather than reusing accent.
        #expect(luminance(Theme.Palette.accent, .dark) > 0.9)
    }
}
