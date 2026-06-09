import SwiftUI
import SwiftData

/// Act tab — turn a book into a plan. Each book gets a 14-day implementation
/// plan (curated for summary editions, LLM-generated for anything else) whose
/// steps can be checked off in-app or exported to Calendar and Reminders.
struct ActView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.title) private var books: [Book]

    @State private var generatingBookID: UUID?
    @State private var errorText: String?

    private var plans: [Book] {
        books.filter { !($0.actionItems ?? []).isEmpty }
    }

    private var candidates: [Book] {
        books.filter {
            ($0.actionItems ?? []).isEmpty
            && !($0.originalVariant?.contentText.isEmpty ?? true)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if plans.isEmpty && candidates.isEmpty {
                    ContentUnavailableView(
                        "Nothing to act on yet",
                        systemImage: "checklist",
                        description: Text("Open a summary in the Read tab — every book can become a 14-day plan.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    if !plans.isEmpty {
                        Section("Your plans") {
                            ForEach(plans, id: \.id) { book in
                                NavigationLink {
                                    ActionPlanView(book: book)
                                } label: {
                                    planRow(book)
                                }
                            }
                        }
                    }
                    if !candidates.isEmpty {
                        Section("Start a plan") {
                            ForEach(candidates, id: \.id) { book in
                                Button {
                                    Task { await generate(for: book) }
                                } label: {
                                    HStack(spacing: Theme.Spacing.m) {
                                        Image(systemName: generatingBookID == book.id ? "hourglass" : "sparkles")
                                            .foregroundStyle(Theme.Palette.textSecondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(book.title)
                                                .foregroundStyle(Theme.Palette.textPrimary)
                                                .lineLimit(1)
                                            Text(generatingBookID == book.id
                                                 ? "Building your 14-day plan…"
                                                 : "Generate a 14-day plan")
                                                .font(.caption)
                                                .foregroundStyle(Theme.Palette.textSecondary)
                                        }
                                    }
                                }
                                .disabled(generatingBookID != nil)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Act")
            .alert("Couldn't build the plan", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func planRow(_ book: Book) -> some View {
        let items = book.actionItems ?? []
        let done = items.filter(\.completed).count
        let exported = items.filter(\.exportedToSystem).count
        return VStack(alignment: .leading, spacing: 4) {
            Text(book.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(2)
            HStack(spacing: 8) {
                Text("\(done)/\(items.count) done")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
                if exported > 0 {
                    Label("\(exported) scheduled", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            ProgressView(value: items.isEmpty ? 0 : Double(done) / Double(items.count))
                .tint(Theme.Palette.accent)
        }
        .padding(.vertical, 2)
    }

    private func generate(for book: Book) async {
        guard let text = book.originalVariant?.contentText, !text.isEmpty else { return }
        generatingBookID = book.id
        defer { generatingBookID = nil }
        do {
            _ = try await ActionPlanEngine().generate(book: book, source: text, context: modelContext)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        ActView().modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
