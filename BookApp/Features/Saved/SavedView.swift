import SwiftUI
import SwiftData

/// Saved tab — everything the user chose to keep, in one place under one
/// navigation identity: the Learnings list and Bookmarks gallery as
/// segments. One NavigationStack owns the bar; the segmented control lives
/// pinned beneath the title so switching segments never tears down
/// navigation or search state oddly.
struct SavedView: View {
    private enum Segment: String, CaseIterable, Identifiable {
        case learnings  = "Learnings"
        case highlights = "Highlights"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .learnings

    var body: some View {
        NavigationStack {
            Group {
                switch segment {
                case .learnings:
                    LearningsListView()
                case .highlights:
                    BookmarksGalleryView()
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Saved content", selection: $segment) {
                    ForEach(Segment.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.s)
                .background(Theme.Palette.appBackground)
            }
            .navigationTitle("Saved")
            .background(Theme.Palette.appBackground.ignoresSafeArea())
        }
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        SavedView().modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
