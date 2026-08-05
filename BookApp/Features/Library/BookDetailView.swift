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
    }
    @State private var route: Destination?
    @State private var originalProgress: Double = 0
    /// First two paragraphs of the summary, used as jacket copy. Derived
    /// rather than authored: the summaries already open with a hook and a
    /// through-line, which is exactly what a blurb is for.
    @State private var blurb: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                // Order follows the decision a reader actually makes:
                // what is this (hero) -> is it for me (blurb) -> start
                // (CTA) -> how long have I got (lengths) -> the small print.
                hero
                if !blurb.isEmpty {
                    blurbSection
                }
                continueButton
                variantsSection
                if !categoryRow.isEmpty {
                    categoriesRow
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
            }
        }
        .task {
            // Read progress once when the screen appears — was running on
            // every render via the body's computed-property call, hitting
            // SwiftData each frame.
            if let original = book.originalVariant {
                originalProgress = currentProgress(for: original)
                blurb = Self.openingParagraphs(of: await original.loadText())
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .top, spacing: Theme.Spacing.l) {
                cover
                VStack(alignment: .leading, spacing: 6) {
                    // The jacket sets the series line, so the page leads
                    // with the book's own name rather than repeating
                    // "The Big Ideas in" at title size.
                    if book.title != displayTitle {
                        Text("THE BIG IDEAS IN")
                            .font(.system(.caption2, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Text(displayTitle)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(4)
                    Text(book.author)
                        .font(.system(.subheadline))
                        .foregroundStyle(Theme.Palette.textSecondary)
                    if book.readMinutesEstimate > 0 {
                        // Minutes, not pages: these are summaries, and "4
                        // pages" reads as a defect rather than a feature.
                        Text("3–\(book.readMinutesEstimate) min read")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(Theme.Palette.textSecondary.opacity(0.8))
                            .padding(.top, 2)
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

    private static let seriesPrefix = "The Big Ideas in "

    private var displayTitle: String {
        book.title.hasPrefix(Self.seriesPrefix)
            ? String(book.title.dropFirst(Self.seriesPrefix.count))
            : book.title
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
            Text("Read it your way")
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
        // Bundled re-styles ship with the app, so "10 seconds ago" is both
        // wrong and baffling — describe the voice instead.
        if v.kind == .styled, v.modelUsed.isEmpty, !v.styleReference.isEmpty {
            return v.styleReference
        }
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

    // MARK: - Attribution

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

    // MARK: - Blurb

    private var blurbSection: some View {
        Text(blurb)
            .font(.system(.subheadline))
            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.85))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The first two body paragraphs, skipping markdown headings and the
    /// trailing attribution. Returns "" when the text has no prose yet, so
    /// the caller can omit the section entirely.
    static func openingParagraphs(of text: String, limit: Int = 2) -> String {
        text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .prefix(limit)
            .joined(separator: "\n\n")
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
