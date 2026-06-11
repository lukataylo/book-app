import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: Tab = .library

    enum Tab: Hashable { case library, memories, learn, search, bookmarks, settings }

    var body: some View {
        TabView(selection: $selection) {
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                .tag(Tab.library)

            MemoriesView()
                .tabItem { Label("Memories", systemImage: "brain.head.profile") }
                .tag(Tab.memories)

            LearningTreeView()
                .tabItem { Label("Learn", systemImage: "graduationcap.fill") }
                .tag(Tab.learn)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)

            BookmarksGalleryView()
                .tabItem { Label("Bookmarks", systemImage: "bookmark.fill") }
                .tag(Tab.bookmarks)

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
            // Production demo content — runs once on first launch.
            await SeedBooksLoader.runIfNeeded(modelContext: modelContext)
            // Backfill: mirror existing learnings → annotations so users
            // who installed before v11 see a populated Bookmarks tab on
            // upgrade. Idempotent.
            AnnotationBackfill.runIfNeeded(modelContext: modelContext)
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
