import SwiftUI
import SwiftData

@main
struct BookAppApp: App {
    let container: ModelContainer

    init() {
        // Try CloudKit-backed container first; fall back to in-memory if
        // CloudKit setup fails (simulator without iCloud, missing entitlement,
        // etc). The app stays usable; sync resumes once the user signs in.
        if let cloud = try? ModelContainer.bookApp() {
            self.container = cloud
        } else if let mem = try? ModelContainer.bookAppPreview() {
            self.container = mem
        } else {
            // Fatal only if neither container can load — the schema itself is broken.
            fatalError("BookApp: unable to construct any ModelContainer.")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(Theme.Palette.accent)
                .background(Theme.Palette.appBackground.ignoresSafeArea())
        }
        .modelContainer(container)
    }
}
