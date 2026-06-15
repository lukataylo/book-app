import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

/// Intermediary detail screen between Library → Reader.
///
/// Shows the book hero, reading-progress, and every variant the user has
/// generated (Original + any compressed / expanded / styled / theme-omitted
/// versions). Tapping a variant opens the reader. The "Generate variant"
/// CTA opens the Transformation Studio.
struct BookDetailView: View {
    @Bindable var book: Book

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private enum Destination: Hashable {
        case reader(UUID)         // variant id
        case transform(UUID)      // source variant id
        case cards                // knowledge-card deck (Remember)
        case plan                 // action plan (Act)
    }
    @State private var route: Destination?
    @State private var showLearnings = false
    @State private var originalProgress: Double = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                hero
                if !categoryRow.isEmpty {
                    categoriesRow
                }
                continueButton
                variantsSection
                actionsSection
                if let learnings = book.keyLearnings, !learnings.isEmpty {
                    learningsPreview(learnings)
                }
                if book.isSummaryEdition, !book.sourceAttribution.isEmpty {
                    attributionFooter
                }
                Spacer(minLength: Theme.Spacing.xxl)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.m)
        }
        .background(Theme.Palette.appBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $route) { dest in
            switch dest {
            case .reader(let id):
                if let v = (book.variants ?? []).first(where: { $0.id == id }) {
                    // PDFs render through PDFKit when the user opens the
                    // original variant — preserves layout, embedded
                    // images, equations, page geometry. AI-transformed
                    // variants of a PDF stay in the text reader because
                    // they're plain text by construction.
                    if book.format == .pdf, v.kind == .original {
                        PDFReaderView(book: book, variant: v)
                    } else {
                        ReaderView(book: book, variant: v)
                    }
                }
            case .transform(let id):
                if let v = (book.variants ?? []).first(where: { $0.id == id }) {
                    TransformationStudioView(book: book, sourceVariant: v)
                }
            case .cards:
                CardDeckView(book: book)
            case .plan:
                ActionPlanView(book: book)
            }
        }
        .sheet(isPresented: $showLearnings) {
            BookLearningsView(book: book)
                .presentationDetents([.medium, .large])
        }
        .task {
            // Read progress once when the screen appears — was running on
            // every render via the body's computed-property call, hitting
            // SwiftData each frame.
            if let original = book.originalVariant {
                originalProgress = currentProgress(for: original)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .top, spacing: Theme.Spacing.l) {
                cover
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(4)
                    Text(book.author)
                        .font(.system(.subheadline))
                        .foregroundStyle(Theme.Palette.textSecondary)
                    if book.totalPagesEstimate > 0 {
                        Text("\(book.totalPagesEstimate) pages · \(formatWords(book.totalWordsEstimate))")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(Theme.Palette.textSecondary.opacity(0.8))
                            .padding(.top, 4)
                    }
                    if book.isSummaryEdition {
                        // Surface the independence/non-affiliation up front, next
                        // to the title + author (not just in the closing footer).
                        Label("Independent summary · not affiliated with the author or publisher", systemImage: "info.circle")
                            .font(.system(.caption2, weight: .medium))
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var cover: some View {
        // Unified cover (same resolution + off-thread cache as the shelf),
        // framed at a true 2:3 so designed covers fill without cropping.
        BookCoverView(book: book)
            .frame(width: 110, height: 165)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))
            .shadow(color: Theme.Palette.bookShadow, radius: 8, x: 0, y: 5)
    }

    private var categoryRow: [String] { book.categoryTags + book.detectedThemes.prefix(3) }

    private var categoriesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categoryRow, id: \.self) { tag in
                    Text(tag)
                        .font(.system(.caption2, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().stroke(Theme.Palette.divider, lineWidth: 0.5)
                        )
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
    }

    // MARK: - Continue

    @ViewBuilder
    private var continueButton: some View {
        if let original = book.originalVariant {
            let progress = originalProgress
            Button {
                route = .reader(original.id)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(progress > 0 ? "Continue reading" : "Start reading")
                            .font(.system(.callout, weight: .semibold))
                        if progress > 0 {
                            Text("\(Int(progress * 100))% complete")
                                .font(.system(.caption))
                                .foregroundStyle(Theme.Palette.appBackground.opacity(0.7))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(.caption, weight: .semibold))
                        .opacity(0.6)
                }
                // Inverted ink — accent flips with the color scheme, so the
                // button stays visible on the pure-black dark background.
                .foregroundStyle(Theme.Palette.appBackground)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, 14)
                .background(Theme.Palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Variants

    private var variantsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Variants")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            VStack(spacing: 0) {
                ForEach(allVariants, id: \.id) { variant in
                    Button { route = .reader(variant.id) } label: {
                        variantRow(variant)
                    }
                    .buttonStyle(.plain)
                    if variant.id != allVariants.last?.id {
                        Divider().background(Theme.Palette.divider)
                    }
                }
            }
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
        }
    }

    private var allVariants: [BookVariant] {
        let originals = (book.variants ?? []).filter { $0.kind == .original }
        let generated = (book.variants ?? []).filter { $0.kind != .original }
            .sorted { $0.generatedAt > $1.generatedAt }
        return originals + generated
    }

    // Books-style rows: text + chevron only — no leading glyph parade.
    private func variantRow(_ v: BookVariant) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(v.label.isEmpty ? v.kind.displayName : v.label)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                if v.kind != .original {
                    Text(metadataLine(for: v))
                        .font(.system(.caption2))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.5))
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func metadataLine(for v: BookVariant) -> String {
        var parts: [String] = []
        if v.targetPages > 0 { parts.append("\(v.targetPages) pages") }
        if !v.modelUsed.isEmpty {
            let pretty = LLMModel(rawValue: v.modelUsed)?.displayName ?? v.modelUsed
            parts.append(pretty)
        }
        if v.costUSD > 0 { parts.append(String(format: "$%.2f", v.costUSD)) }
        if parts.isEmpty {
            parts.append(v.generatedAt.formatted(.relative(presentation: .named)))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 0) {
            if !(book.knowledgeCards ?? []).isEmpty {
                Button {
                    route = .cards
                } label: {
                    actionRow(title: "Remember",
                              subtitle: "\(book.knowledgeCards?.count ?? 0) knowledge cards")
                }
                .buttonStyle(.plain)
                Divider().background(Theme.Palette.divider)
            }
            if !(book.actionItems ?? []).isEmpty {
                Button {
                    route = .plan
                } label: {
                    actionRow(title: "Act",
                              subtitle: "14-day plan · \(book.actionItems?.filter(\.completed).count ?? 0)/\(book.actionItems?.count ?? 0) done")
                }
                .buttonStyle(.plain)
                Divider().background(Theme.Palette.divider)
            }
            Button {
                showLearnings = true
            } label: {
                actionRow(title: "Key learnings",
                          subtitle: book.keyLearnings?.isEmpty == false
                            ? "\(book.keyLearnings?.count ?? 0) saved" : "Auto-extract key takeaways")
            }
            .buttonStyle(.plain)
            Divider().background(Theme.Palette.divider)
            Button {
                if let original = book.originalVariant { route = .transform(original.id) }
            } label: {
                actionRow(title: "Transform",
                          subtitle: "Compress, expand, restyle, or omit themes")
            }
            .buttonStyle(.plain)
        }
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous))
    }

    private func actionRow(title: String, subtitle: String) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(subtitle)
                    .font(.system(.caption2))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.5))
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Attribution (summary editions)

    private var attributionFooter: some View {
        Text(book.sourceAttribution)
            .font(.system(.caption2))
            .foregroundStyle(Theme.Palette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.m, style: .continuous)
                    .stroke(Theme.Palette.divider, lineWidth: 0.5)
            )
    }

    // MARK: - Learnings preview

    @ViewBuilder
    private func learningsPreview(_ learnings: [KeyLearning]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Recent learnings")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                ForEach(Array(learnings.prefix(3))) { l in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Theme.Palette.textSecondary.opacity(0.4))
                            .frame(width: 5, height: 5)
                            .padding(.top, 8)
                        Text(l.text)
                            .font(.system(.subheadline))
                            .foregroundStyle(Theme.Palette.textPrimary)
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func currentProgress(for variant: BookVariant) -> Double {
        let bookID = book.id
        let variantID = variant.id
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.book?.id == bookID && $0.variantID == variantID }
        )
        return (try? modelContext.fetch(descriptor).first?.percent) ?? 0
    }

    private func formatWords(_ count: Int) -> String {
        if count >= 1_000_000 { return "\(count / 1_000_000)M words" }
        if count >= 1_000 { return "\(count / 1_000)k words" }
        return "\(count) words"
    }
}
