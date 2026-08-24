import SwiftUI
import SwiftData

@main
struct BookAppApp: App {
    let container: ModelContainer?
    let containerError: String?
    /// True when the previous store couldn't be opened and was replaced.
    /// Surfaced to the user rather than swallowed — an empty library needs
    /// an explanation.
    let storeWasReset: Bool
    /// XCUITests pass `-uitesting` so the app skips onboarding and lands
    /// straight on the library, which is the surface we want to drive.
    /// CommandLine.arguments is read once at launch — no runtime overhead
    /// once tests aren't running.
    @State private var onboardingDone: Bool = UserDefaults.standard
        .bool(forKey: OnboardingView.completedKey)
        || CommandLine.arguments.contains("-uitesting")

    init() {
        // Open the real store, resetting it if it can't be opened. The old
        // behaviour — falling back to an in-memory container — hid the
        // failure completely: the app looked fine and lost everything on
        // every launch. See `bookAppRecovering`.
        let (store, didReset) = ModelContainer.bookAppRecovering()
        if let store {
            self.container = store
            self.containerError = nil
            self.storeWasReset = didReset
        } else {
            self.container = nil
            self.containerError = "Epigrapha couldn't load its data store. Reinstalling the app usually fixes this. If the problem persists, file a bug at github.com/lukataylo/book-app/issues."
            self.storeWasReset = false
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ZStack {
                    RootTabView()
                        .tint(Theme.Palette.accent)
                        .background(Theme.Palette.appBackground.ignoresSafeArea())
                        .modelContainer(container)

                    if storeWasReset {
                        StoreResetNotice()
                            .zIndex(2)
                    }
                    if !onboardingDone {
                        OnboardingView(onFinish: { withAnimation(.smooth) { onboardingDone = true } })
                            .transition(.opacity)
                            .zIndex(1)
                    }
                }
            } else {
                ContainerErrorView(message: containerError ?? "Unknown error.")
            }
        }
    }
}

/// One-time banner after a store reset. Deliberately not a blocking
/// alert: the app is usable, the catalog is already re-seeding, and the
/// only thing lost is content the user can re-import.
private struct StoreResetNotice: View {
    @State private var shown = true
    var body: some View {
        if shown {
            VStack {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.clockwise.circle")
                    Text("Your library was rebuilt after an update changed how books are stored. Any books you imported yourself need importing again.")
                        .font(.footnote)
                    Button {
                        shown = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

private struct ContainerErrorView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("Couldn't start Epigrapha")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(message)
                .font(.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.appBackground.ignoresSafeArea())
    }
}
