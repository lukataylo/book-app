import SwiftUI
import SwiftData

/// Global learnings tab — every learning across every book, filterable.
struct LearningsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KeyLearning.createdAt, order: .reverse) private var learnings: [KeyLearning]
    @State private var query = ""
    @State private var starredOnly = false

    // Hosted inside the Saved tab's NavigationStack (it was its own tab
    // before the Read/Remember/Act redesign), so no stack of its own —
    // searchable + toolbar attach to the parent's bar.
    var body: some View {
        Group {
            List {
                Toggle("Starred only", isOn: $starredOnly)
                    .listRowBackground(Color.clear)
                ForEach(filtered) { learning in
                    LearningRow(learning: learning)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(learning)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                learning.starred.toggle()
                                try? modelContext.save()
                            } label: {
                                Label(learning.starred ? "Unstar" : "Star", systemImage: "star.fill")
                            }
                            .tint(.yellow)
                        }
                }
            }
            .searchable(text: $query, prompt: "Search learnings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Export to Markdown", action: exportMarkdown)
                        Button("Export to JSON",     action: exportJSON)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var filtered: [KeyLearning] {
        var items = learnings
        if starredOnly { items = items.filter { $0.starred } }
        if !query.isEmpty {
            let q = query.lowercased()
            items = items.filter {
                $0.text.lowercased().contains(q)
                || ($0.book?.title.lowercased().contains(q) ?? false)
                || $0.tags.contains(where: { $0.lowercased().contains(q) })
            }
        }
        return items
    }

    private func exportMarkdown() {
        let body = filtered.map { learning in
            let book = learning.book?.title ?? "Untitled"
            return "## \(book)\n\n- \(learning.text)\n"
        }.joined(separator: "\n")
        share(text: body, suggestedName: "learnings.md")
    }

    private func exportJSON() {
        let payload = filtered.map { learning in
            [
                "id": learning.id.uuidString,
                "book": learning.book?.title ?? "",
                "text": learning.text,
                "chapter": learning.chapterRef,
                "starred": learning.starred,
                "createdAt": ISO8601DateFormatter().string(from: learning.createdAt)
            ] as [String: Any]
        }
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
           let text = String(data: data, encoding: .utf8) {
            share(text: text, suggestedName: "learnings.json")
        }
    }

    private func share(text: String, suggestedName: String) {
        // Write to a temp file so the share sheet has something to attach.
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedName)
        try? text.write(to: tmp, atomically: true, encoding: .utf8)
        // Hand off to the platform share sheet.
        ShareCoordinator.shared.share(item: tmp)
    }
}

private struct LearningRow: View {
    let learning: KeyLearning
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(learning.text)
                .font(.body)
            HStack(spacing: 8) {
                if let title = learning.book?.title {
                    Label(title, systemImage: "book.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !learning.chapterRef.isEmpty {
                    Text(learning.chapterRef)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if learning.starred {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Per-book learnings — invoked from the reader's "AI" sheet flow.
struct BookLearningsView: View {
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @State private var isExtracting = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await runExtraction() }
                    } label: {
                        Label("Extract key learnings", systemImage: "sparkles")
                    }
                    .disabled(isExtracting)
                }
                Section("Learnings") {
                    if let learnings = book.keyLearnings, !learnings.isEmpty {
                        ForEach(learnings.sorted(by: { $0.createdAt > $1.createdAt })) { l in
                            LearningRow(learning: l)
                        }
                    } else {
                        Text("No learnings yet").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(book.title)
            .alert("Extraction failed", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func runExtraction() async {
        // `loadText()` resolves both the legacy in-row contentText and
        // the new disk-backed body, so this works through the migration.
        guard let variant = book.originalVariant else { return }
        let text = await variant.loadText()
        guard !text.isEmpty else { return }
        isExtracting = true
        defer { isExtracting = false }
        do {
            _ = try await ExtractionEngine().extract(book: book, source: text, context: modelContext)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
