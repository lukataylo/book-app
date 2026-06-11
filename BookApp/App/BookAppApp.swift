import SwiftUI
import SwiftData

@main
struct BookAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    let container: ModelContainer?
    let containerError: String?
    /// XCUITests pass `-uitesting` so the app skips onboarding and lands
    /// straight on the library, which is the surface we want to drive.
    /// CommandLine.arguments is read once at launch — no runtime overhead
    /// once tests aren't running.
    @State private var onboardingDone: Bool = UserDefaults.standard
        .bool(forKey: OnboardingView.completedKey)
        || CommandLine.arguments.contains("-uitesting")

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
        // Subscribe to MetricKit for crash + hang diagnostics. Apple
        // delivers payloads roughly once a day; we drop them into the
        // app's caches folder so the user can export them from Settings
        // without us shipping a third-party crash SDK.
        MetricsLog.shared.start()
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
                .task { refreshMemories() }
            } else {
                ContainerErrorView(message: containerError ?? "Unknown error.")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshMemories() }
        }
    }

    /// Keep the "Today's Memory" widget and the daily reminder in step with the
    /// deck on launch and whenever the app returns to the foreground. Best
    /// effort: no StreakState means reminders are off and we just refresh the
    /// snapshot at the default cap.
    @MainActor
    private func refreshMemories() {
        guard let container else { return }
        let context = container.mainContext
        let descriptor = FetchDescriptor<StreakState>()
        if let streak = (try? context.fetch(descriptor))?.first {
            MemoryReminders.refresh(context: context, streak: streak)
        } else {
            MemorySnapshotWriter.refresh(context: context)
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
