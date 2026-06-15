import SwiftUI

/// First-launch walkthrough. Shown by `BookAppApp` when
/// `UserDefaults["Onboarding.completed-v1"]` is false. Four swipeable panels
/// covering: import → AI elastic length / style → spaced-repetition review →
/// audio + speed reading.
/// Dismissing the last panel writes the flag so it never appears again on
/// this device. (Restoring iCloud state on a fresh install can re-trigger
/// this — that's intentional, since the app's affordances change enough
/// between releases that a refresher is cheap.)
///
/// Colors come entirely from the adaptive palette (appBackground / textPrimary
/// / textSecondary) so every panel is legible in both light and dark mode —
/// matching the app's editorial monochrome identity. The earlier colored
/// panels broke in dark mode (white-on-white button, washed-out accent panel,
/// unreadable text on the fixed sepia ground).
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages: [Panel] = [
        Panel(
            symbol: "books.vertical.fill",
            title: "Your library, your way",
            blurb: "Drop in EPUBs, PDFs, even MOBI. They're auto-tagged and shelved by category, ready to read."
        ),
        Panel(
            symbol: "wand.and.stars",
            title: "Elastic length, on-device",
            blurb: "Compress a 400-page book to 20, or expand five pages to fifty. On-device AI handles short transforms on the latest iPhones; add your own Anthropic key for the rest."
        ),
        Panel(
            symbol: "brain.head.profile",
            title: "Remember what you read",
            blurb: "Turn the ideas you keep into spaced-repetition cards. A quick daily review brings each one back right before you'd forget it."
        ),
        Panel(
            symbol: "headphones",
            title: "Listen or speed-read",
            blurb: "Tap Listen for word-synced narration with lock-screen controls, or Speed for a focus mode you can run up to 1000 wpm. Both inherit your reader's font and theme."
        )
    ]

    var body: some View {
        ZStack {
            Theme.Palette.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, panel in
                        panelView(panel)
                            .tag(idx)
                            .padding(.horizontal, 28)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                pageIndicator
                    .padding(.bottom, 18)

                primaryButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)

                Button("Skip") { complete() }
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.bottom, 28)
                    .opacity(page == pages.count - 1 ? 0 : 1)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: page)
    }

    @ViewBuilder
    private func panelView(_ panel: Panel) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 24)
            Image(systemName: panel.symbol)
                .font(.system(size: 88, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.bottom, 12)

            Text(panel.title)
                .font(.system(.title, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.center)

            Text(panel.blurb)
                .font(.system(.body))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)

            Spacer()
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.Palette.textPrimary : Theme.Palette.textSecondary.opacity(0.35))
                    .frame(width: i == page ? 22 : 7, height: 7)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: page)
            }
        }
    }

    private var primaryButton: some View {
        Button {
            if page < pages.count - 1 {
                page += 1
            } else {
                complete()
            }
        } label: {
            Text(page < pages.count - 1 ? "Next" : "Start reading")
                .font(.system(.callout, weight: .semibold))
                // Inverse of the button fill so it's legible in both modes:
                // light → dark fill + light text; dark → light fill + dark text.
                .foregroundStyle(Theme.Palette.appBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.Palette.textPrimary)
                )
        }
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: OnboardingView.completedKey)
        onFinish()
    }

    static let completedKey = "Onboarding.completed-v1"

    private struct Panel {
        let symbol: String
        let title: String
        let blurb: String
    }
}
