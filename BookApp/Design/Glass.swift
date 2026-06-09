import SwiftUI

/// The app's glass language: frosted material surfaces with a hairline
/// stroke and a soft lift. Used for elevated, floating content — knowledge
/// cards, the continue-reading card, badges, toasts, bottom bars — while
/// flat lists stay on `Theme.Palette.surface`. No gradients anywhere.
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.xl

    func body(content: Content) -> some View {
        content
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Palette.divider, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = Theme.Radius.xl) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}
