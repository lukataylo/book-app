import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: Tab = .read

    // Read → Saved is the product's core loop (read it, keep it). Saved
    // collects the highlights kept out of a book. Search spans both,
    // which is the one thing neither tab can do on its own.
    enum Tab: Hashable { case read, search, saved, settings }

    var body: some View {
        TabView(selection: $selection) {
            LibraryView()
                .tabItem { Label("Read", systemImage: "book.fill") }
                .tag(Tab.read)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                .tag(Tab.saved)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        // `.sidebarAdaptable` (iOS 18+) keeps the iPhone tab-bar look but
        // promotes the same tabs to a NavigationSplitView sidebar on
        // iPad. Native, free, and the destination views render in the
        // detail column with full screen width — no custom split-view
        // refactor required.
        .tabViewStyle(.sidebarAdaptable)
        .task {
            // Summary catalog ("The Big Ideas in …") — per-slug idempotent,
            // so packs added in an update are seeded on next launch.
            await SummaryPackLoader.runIfNeeded(modelContext: modelContext)
            #if DEBUG
            // Dev convenience: any EPUB / PDF dropped into the simulator's
            // Documents/_seed/ folder gets imported on next launch.
            await DevSeed.runIfNeeded(modelContext: modelContext)
            #endif
        }
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        RootTabView().modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
