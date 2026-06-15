import SwiftUI
import SwiftData

/// Leech management. A card that keeps failing is auto-suspended by the
/// scheduler (spec §3c) so it stops silently haunting the daily loop. This
/// screen lets the user see those stuck cards and bring one back into the
/// deck with a clean slate (lapses reset) once they've had another look.
struct SuspendedCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<KeyLearning> { $0.isSuspended },
        sort: \KeyLearning.lastReviewedAt, order: .reverse
    )
    private var suspended: [KeyLearning]

    @State private var rephrasing: UUID?

    var body: some View {
        Group {
            if suspended.isEmpty {
                ContentUnavailableView(
                    "Nothing stuck",
                    systemImage: "checkmark.circle",
                    description: Text("Cards that keep tripping you up are set aside here so they don't dominate your reviews. You have none right now.")
                )
            } else {
                ScrollView {
                    VStack(spacing: Theme.Spacing.s) {
                        ForEach(suspended) { card in
                            row(card)
                        }
                    }
                    .padding(Theme.Spacing.l)
                }
            }
        }
        .background(Theme.Palette.appBackground.ignoresSafeArea())
        .navigationTitle("Stuck cards")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ card: KeyLearning) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let title = card.book?.title, !title.isEmpty {
                Text(title)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }
            Text(card.promptText)
                .font(.system(.callout, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.leading)
            HStack(spacing: Theme.Spacing.s) {
                Text("Missed \(card.lapses) time\(card.lapses == 1 ? "" : "s")")
                    .font(.system(.caption2))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                // Rewrite a stubborn card into a clearer one (and bring it
                // back) — uses the model when one is reachable.
                Button {
                    Task { await rephrase(card) }
                } label: {
                    if rephrasing == card.id {
                        ProgressView()
                    } else {
                        Text("Rephrase")
                            .font(.system(.subheadline, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .tint(Theme.Palette.textPrimary)
                .disabled(rephrasing != nil)
                Button {
                    MemoryStore(context: modelContext).reinstate(card)
                } label: {
                    Text("Bring back")
                        .font(.system(.subheadline, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(Theme.Palette.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .glassCard(cornerRadius: Theme.Radius.m)
    }

    /// Rewrite a leech into a clearer card, then reinstate it. If no model is
    /// reachable the card is simply reinstated unchanged.
    private func rephrase(_ card: KeyLearning) async {
        rephrasing = card.id
        defer { rephrasing = nil }
        let idea = card.back.isEmpty ? card.text : card.back
        if let cloze = try? await CardGenerator().reformulate(idea: idea, failedAttempts: []) {
            card.front = cloze.front
            card.back = cloze.back
            card.clozeMask = cloze.clozeMask
        }
        MemoryStore(context: modelContext).reinstate(card)
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        NavigationStack { SuspendedCardsView() }
            .modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
