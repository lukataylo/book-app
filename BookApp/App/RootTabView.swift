import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: Tab = .library

    enum Tab: Hashable { case library, search, learnings, settings }

    var body: some View {
        TabView(selection: $selection) {
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                .tag(Tab.library)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            LearningsListView()
                .tabItem { Label("Learnings", systemImage: "lightbulb.fill") }
                .tag(Tab.learnings)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .task {
            // Production demo content — runs once on first launch.
            await SeedBooksLoader.runIfNeeded(modelContext: modelContext)
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
