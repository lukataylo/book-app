import SwiftUI
import SwiftData

struct RootTabView: View {
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
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        RootTabView().modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
