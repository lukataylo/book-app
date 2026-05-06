import SwiftUI
import SwiftData

/// Manual metadata editor for a Book — title, author, comma-separated tags,
/// and detected themes. The auto-tagger only runs once on import; this is
/// the only way to fix bad results or add to the categories.
struct EditBookMetadataSheet: View {
    @Bindable var book: Book

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var categoriesText: String = ""
    @State private var themesText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Title & author") {
                    TextField("Title", text: $book.title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                    TextField("Author", text: $book.author)
                }

                Section("Categories") {
                    TextField("Self-improvement, Philosophy, …", text: $categoriesText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                    Text("Comma-separated. The first category becomes the home-screen shelf.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Themes") {
                    TextField("habit formation, stoicism, …", text: $themesText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                    Text("Comma-separated. The Transformation Studio's omit-themes picker uses these.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !book.notes.isEmpty || !categoriesText.isEmpty {
                    Section("Notes") {
                        TextEditor(text: $book.notes)
                            .frame(minHeight: 80)
                    }
                }
            }
            .navigationTitle("Edit book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                categoriesText = book.categoryTags.joined(separator: ", ")
                themesText = book.detectedThemes.joined(separator: ", ")
            }
        }
    }

    private func save() {
        book.categoryTags = parseList(categoriesText)
        book.detectedThemes = parseList(themesText)
        try? modelContext.save()
    }

    private func parseList(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
