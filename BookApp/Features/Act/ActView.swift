import SwiftUI
import SwiftData

/// Act tab — turn a book into a plan. Each book gets a 14-day implementation
/// plan (curated for summary editions, LLM-generated for anything else) whose
/// steps can be checked off in-app or exported to Calendar and Reminders.
/// Visually a sibling of the Remember tab: editorial serif header, glass
/// tiles, same grid rhythm.
struct ActView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.title) private var books: [Book]

    @State private var selectedBook: Book?
    @State private var generatingBookID: UUID?
    @State private var errorText: String?
    @State private var query = ""

    private func applyQuery(_ list: [Book]) -> [Book] {
        guard !query.isEmpty else { return list }
        let q = query.lowercased()
        return list.filter {
            $0.title.lowercased().contains(q) || $0.author.lowercased().contains(q)
        }
    }

    var body: some View {
        // Computed once per body evaluation — `.searchable` re-runs body per
        // keystroke and the catalog is 80 books. `originalVariant != nil`
        // avoids materializing summary text just to test for it.
        let plans = applyQuery(books.filter { !($0.actionItems ?? []).isEmpty })
        let candidates = applyQuery(books.filter {
            ($0.actionItems ?? []).isEmpty && $0.originalVariant != nil
        })

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    header
                    if plans.isEmpty && candidates.isEmpty {
                        if query.isEmpty {
                            emptyState
                        } else {
                            noMatches
                        }
                    } else {
                        planList(plans)
                        if !candidates.isEmpty {
                            generateSection(candidates)
                        }
                    }
                    Spacer(minLength: Theme.Spacing.xxl)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.m)
            }
            .background(Theme.Palette.appBackground.ignoresSafeArea())
            .searchable(text: $query, prompt: "Search plans")
            .navigationDestination(item: $selectedBook) { book in
                ActionPlanView(book: book)
            }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Act")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Fourteen days per book. Check steps off here, or send them to your calendar.")
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    private func planList(_ plans: [Book]) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            ForEach(plans, id: \.id) { book in
                Button { selectedBook = book } label: {
                    planTile(book)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func planTile(_ book: Book) -> some View {
        let items = book.actionItems ?? []
        let done = items.filter(\.completed).count
        let exported = items.filter(\.exportedToSystem).count
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .top) {
                Text(book.title)
                    .font(.system(.callout, design: .serif, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary.opacity(0.5))
            }
            ProgressView(value: items.isEmpty ? 0 : Double(done) / Double(items.count))
                .tint(Theme.Palette.accent)
            HStack(spacing: 10) {
                Text("\(done)/\(items.count) done")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .monospacedDigit()
                if exported > 0 {
                    Text("\(exported) scheduled")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer()
            }
        }
        .padding(Theme.Spacing.m)
        .glassCard(cornerRadius: Theme.Radius.l)
    }

    private func generateSection(_ candidates: [Book]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Start a plan")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            VStack(spacing: 0) {
                ForEach(candidates, id: \.id) { book in
                    Button {
                        Task { await generate(for: book) }
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            Image(systemName: generatingBookID == book.id ? "hourglass" : "sparkles")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.title)
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                    .lineLimit(1)
                                Text(generatingBookID == book.id
                                     ? "Building your 14-day plan…"
                                     : "Generate a 14-day plan")
                                    .font(.system(.caption2))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, Theme.Spacing.m)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(generatingBookID != nil)
                    if book.id != candidates.last?.id {
                        Divider().background(Theme.Palette.divider)
                    }
                }
            }
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        }
    }

    private var noMatches: some View {
        Text("No plans match \"\(query)\".")
            .font(.system(.subheadline))
            .foregroundStyle(Theme.Palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xl)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checklist")
                .font(.system(.largeTitle, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.7))
            Text("Nothing to act on yet")
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Open a summary in the Read tab — every book can become a 14-day plan.")
                .font(.system(.subheadline))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
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
