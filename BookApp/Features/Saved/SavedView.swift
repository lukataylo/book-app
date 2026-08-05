import SwiftUI
import SwiftData

/// Saved tab — the highlights and bookmarks kept out of a book, in one
/// place. Previously a segmented control over Learnings and Highlights;
/// learnings were retired because highlighting is the same gesture with a
/// better home, and two sibling views each declaring their own
/// `.searchable` on one NavigationStack was a genuine source of instability.
struct SavedView: View {
    var body: some View {
        NavigationStack {
            BookmarksGalleryView()
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
