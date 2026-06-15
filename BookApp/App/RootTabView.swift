import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selection: Tab = .read

    // Read → Remember → Act is the product's core loop (learn it, keep it,
    // live it). Saved collects everything kept (cards, learnings,
    // highlights); Search moved into the Read tab's toolbar.
    enum Tab: Hashable { case read, remember, saved, act, settings }

    var body: some View {
        TabView(selection: $selection) {
            LibraryView()
                .tabItem { Label("Read", systemImage: "book.fill") }
                .tag(Tab.read)

            RememberView()
                .tabItem { Label("Remember", systemImage: "square.stack.fill") }
                .tag(Tab.remember)

            SavedView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }
                .tag(Tab.saved)

            ActView()
                .tabItem { Label("Act", systemImage: "checklist") }
                .tag(Tab.act)

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
            // Summary catalog ("The Big Ideas in …") — per-slug idempotent,
            // so packs added in an update are seeded on next launch.
            await SummaryPackLoader.runIfNeeded(modelContext: modelContext)
            // Backfill: mirror existing learnings → annotations so users
            // who installed before v11 see a populated Bookmarks tab on
            // upgrade. Idempotent.
            AnnotationBackfill.runIfNeeded(modelContext: modelContext)
            // Move legacy in-row blobs (Book.coverData,
            // BookVariant.contentText) onto disk. Idempotent, gated by
            // its own UserDefaults flag.
            BlobMigration.runIfNeeded(modelContext: modelContext)
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
