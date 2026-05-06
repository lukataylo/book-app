import SwiftUI
import SwiftData

@main
struct BookAppApp: App {
    let container: ModelContainer?
    let containerError: String?
    @State private var onboardingDone: Bool = UserDefaults.standard
        .bool(forKey: OnboardingView.completedKey)

    init() {
        // Try CloudKit-backed container first; fall back to in-memory if
        // CloudKit setup fails (simulator without iCloud, missing entitlement,
        // etc). If neither works we surface a recoverable error rather than
        // crashing — the user can at least read the message and reinstall.
        if let cloud = try? ModelContainer.bookApp() {
            self.container = cloud
            self.containerError = nil
        } else if let mem = try? ModelContainer.bookAppPreview() {
            self.container = mem
            self.containerError = nil
        } else {
            self.container = nil
            self.containerError = "BookApp couldn't load its data store. Reinstalling the app usually fixes this. If the problem persists, file a bug at github.com/lukataylo/book-app/issues."
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

private struct ContainerErrorView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("Couldn't start BookApp")
                .font(.system(size: 22, weight: .semibold, design: .serif))
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
