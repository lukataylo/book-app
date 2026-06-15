import SwiftUI

/// First-launch walkthrough. Shown by `BookAppApp` when
/// `UserDefaults["Onboarding.completed-v1"]` is false. Four swipeable panels
/// covering: import → AI elastic length / style → spaced-repetition review →
/// audio + speed reading.
/// Dismissing the last panel writes the flag so it never appears again on
/// this device. (Restoring iCloud state on a fresh install can re-trigger
/// this — that's intentional, since the app's affordances change enough
/// between releases that a refresher is cheap.)
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages: [Panel] = [
        Panel(
            symbol: "books.vertical.fill",
            title: "Your library, your way",
            blurb: "Drop in EPUBs, PDFs, even MOBI — they get auto-tagged and shelved by category. Three classics are pre-loaded so you can dive in immediately.",
            tone: .ink
        ),
        Panel(
            symbol: "wand.and.stars",
            title: "Elastic length, on-device",
            blurb: "Compress a 400-page book to 20 — or expand five pages to fifty — using Apple Intelligence. Zero API key needed for short transforms; bring a Claude key for the deep restyles.",
            tone: .accent
        ),
        Panel(
            symbol: "brain.head.profile",
            title: "Remember what you read",
            blurb: "Turn the ideas you keep into spaced-repetition cards. A quick daily review brings each one back right before you'd forget it.",
            tone: .ink
        ),
        Panel(
            symbol: "headphones",
            title: "Listen or speed-read",
            blurb: "Tap Listen for word-synced narration with lock-screen controls, or Speed for a focus mode you can run up to 1000 wpm. Both inherit your reader's font and theme.",
            tone: .sepia
        )
    ]

    var body: some View {
        ZStack {
            backgroundForPage(page).ignoresSafeArea()

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
                .foregroundStyle(panel.tone == .accent ? Color.white : Theme.Palette.textPrimary)
                .padding(.bottom, 12)

            Text(panel.title)
                .font(.system(.title, design: .serif, weight: .semibold))
                .foregroundStyle(panel.tone == .accent ? Color.white : Theme.Palette.textPrimary)
                .multilineTextAlignment(.center)

            Text(panel.blurb)
                .font(.system(.body))
                .foregroundStyle(panel.tone == .accent ? Color.white.opacity(0.85) : Theme.Palette.textSecondary)
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
                    .fill(i == page
                          ? (pages[page].tone == .accent ? Color.white : Theme.Palette.textPrimary)
                          : (pages[page].tone == .accent ? Color.white.opacity(0.35) : Theme.Palette.textSecondary.opacity(0.35)))
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
                .foregroundStyle(pages[page].tone == .accent ? Theme.Palette.accent : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(pages[page].tone == .accent ? Color.white : Theme.Palette.textPrimary)
                )
        }
    }

    @ViewBuilder
    private func backgroundForPage(_ idx: Int) -> some View {
        switch pages[idx].tone {
        case .ink:    Theme.Palette.appBackground
        case .accent: Theme.Palette.accent
        case .sepia:  Color(red: 0.97, green: 0.93, blue: 0.84)
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
        let tone: Tone
        enum Tone { case ink, accent, sepia }
    }
}
