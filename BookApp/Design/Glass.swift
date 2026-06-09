import SwiftUI

/// The app's glass language: frosted material surfaces with a hairline
/// stroke and a soft lift. Used for elevated, floating content — knowledge
/// cards, the continue-reading card, badges, toasts, bottom bars — while
/// flat lists stay on `Theme.Palette.surface`. No gradients anywhere.
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.xl

    func body(content: Content) -> some View {
        content
            // Shadow lives on the background shape, not the composed view —
            // a shadow after a translucent material makes every non-opaque
            // subview (glyphs, symbols) cast its own.
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Palette.divider, lineWidth: 0.5)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = Theme.Radius.xl) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}
