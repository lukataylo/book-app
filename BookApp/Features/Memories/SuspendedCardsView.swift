import SwiftUI
import SwiftData

/// Leech / suspended-card management (spec §3c). Cards that kept failing left
/// the daily loop; here the user can reformulate them into a clearer card,
/// reinstate them as-is, or retire them for good. A leech should leave the
/// loop, not haunt it.
struct SuspendedCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<KeyLearning> { $0.isScheduled && $0.isSuspended })
    private var suspended: [KeyLearning]

    /// IDs currently being reformulated, so each row can show its own spinner.
    @State private var working: Set<UUID> = []

    private var store: MemoryStore { MemoryStore(context: modelContext) }

    var body: some View {
        NavigationStack {
            Group {
                if suspended.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle("Suspended")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(suspended) { card in
                    row(card)
                }
            } footer: {
                Text("These cards kept failing and left the daily loop. Reformulate to retry with a clearer card, or retire one you no longer need.")
            }
        }
    }

    @ViewBuilder
    private func row(_ card: KeyLearning) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(card.promptText)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.xs) {
                Label(reasonLabel(card.suspendedReason), systemImage: "pause.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if card.lapses > 0 {
                    Text("· \(card.lapses) lapses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: Theme.Spacing.s) {
                if working.contains(card.id) {
                    ProgressView()
                } else {
                    Button("Reformulate") { reformulate(card) }
                        .buttonStyle(.borderless)
                    Button("Reinstate") { store.reinstate(card) }
                        .buttonStyle(.borderless)
                    Button("Retire", role: .destructive) { retire(card) }
                        .buttonStyle(.borderless)
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(.top, Theme.Spacing.xxs)
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }

    private var empty: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Nothing suspended")
                .font(.title3.weight(.semibold))
            Text("Cards that keep failing land here so they stop haunting your daily review.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    /// Send the idea plus failed attempts to the LLM for a clearer cloze, write
    /// it back, then reinstate with a clean run (spec §3c step 2).
    private func reformulate(_ card: KeyLearning) {
        let idea = card.text
        let failed = card.lastExplanation.isEmpty ? [] : [card.lastExplanation]
        working.insert(card.id)
        Task {
            defer { working.remove(card.id) }
            do {
                let cloze = try await CardGenerator().reformulate(idea: idea, failedAttempts: failed)
                card.front = cloze.front
                card.back = cloze.back
                card.clozeMask = cloze.clozeMask
                card.cardKind = .cloze
                store.reinstate(card)
            } catch {
                // Leave the card suspended on failure; the user can retry,
                // reinstate as-is, or retire it.
            }
        }
    }

    private func retire(_ card: KeyLearning) {
        card.isSuspended = true
        card.suspendedReason = .retired
        card.isScheduled = false
        try? modelContext.save()
    }

    private func reasonLabel(_ reason: SuspendReason) -> String {
        switch reason {
        case .leech:      return "Kept failing"
        case .userPaused: return "Paused"
        case .retired:    return "Retired"
        case .none:       return "Suspended"
        }
    }
}

#Preview {
    if let container = try? ModelContainer.bookAppPreview() {
        SuspendedCardsView().modelContainer(container)
    } else {
        Text("Preview container failed to load.")
    }
}
