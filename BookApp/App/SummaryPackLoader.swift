import Foundation
import SwiftData

/// Loads the bundled catalog of original BookApp summaries ("The Big Ideas
/// in …") — the Read tab's summary-first content.
///
/// `BookApp/Resources/SummaryPacks/<slug>.json` contains, per title: catalog
/// metadata, the legally-safe summary text, curated key learnings, a deck of
/// knowledge cards (Remember tab) and a 14-day action plan (Act tab).
///
/// Unlike `SeedBooksLoader` there is no EPUB to import: the summary IS the
/// content, stored as the book's `.original` variant so the reader, TTS,
/// speed-reading and transformation features all work on it unchanged.
///
/// Idempotency is per-slug (a UserDefaults string array), so packs added in
/// a later app update are picked up without re-seeding existing ones.
@MainActor
enum SummaryPackLoader {

    private static let resourceFolder = "SummaryPacks"
    private static let loadedSlugsKey = "SummaryPacks.loadedSlugs-v1"

    static func runIfNeeded(modelContext: ModelContext) {
        guard let folderURL = bundledFolderURL() else { return }
        let files: [URL]
        do {
            files = try FileManager.default
                .contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            return
        }

        var loaded = Set(UserDefaults.standard.stringArray(forKey: loadedSlugsKey) ?? [])
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let pack = try? decoder.decode(SummaryPack.self, from: data) else {
                print("[SummaryPacks] failed to decode \(file.lastPathComponent)")
                continue
            }
            guard !loaded.contains(pack.slug) else { continue }
            seed(pack: pack, context: modelContext)
            loaded.insert(pack.slug)
        }

        UserDefaults.standard.set(Array(loaded).sorted(), forKey: loadedSlugsKey)
    }

    private static func seed(pack: SummaryPack, context: ModelContext) {
        let book = Book(title: pack.title, author: pack.sourceAuthor, format: .epub)
        book.isSummaryEdition = true
        book.sourceAttribution = pack.attribution
        book.readMinutesEstimate = pack.readMinutes
        book.categoryTags = pack.categories
        book.detectedThemes = pack.themes

        // The reader renders the attribution as the summary's first
        // paragraph so the legal framing travels with the text itself.
        let contentText = pack.attribution + "\n\n" + pack.summary
        let words = contentText.split(whereSeparator: { $0.isWhitespace }).count
        book.totalWordsEstimate = words
        book.totalPagesEstimate = max(words / 250, 1)
        context.insert(book)

        let variant = BookVariant(book: book, kind: .original, contentText: contentText)
        variant.label = "Summary"
        context.insert(variant)

        // Curated learnings — mirrored as Annotations so the highlights
        // gallery is populated, matching SeedBooksLoader's behaviour.
        let palette: [AnnotationColor] = [.yellow, .blue, .pink, .green, .purple]
        for (idx, entry) in pack.learnings.enumerated() {
            let learning = KeyLearning(book: book, text: entry.text, chapterRef: entry.chapter)
            context.insert(learning)
            let annotation = Annotation(
                book: book,
                variantID: nil,
                quotedText: entry.text,
                note: entry.chapter,
                color: palette[idx % palette.count]
            )
            context.insert(annotation)
        }

        for (idx, card) in pack.cards.enumerated() {
            context.insert(KnowledgeCard(
                book: book,
                title: card.title,
                body: card.body,
                category: card.category,
                order: idx,
                source: "seed"
            ))
        }

        for (idx, action) in pack.actions.enumerated() {
            context.insert(ActionItem(
                book: book,
                title: action.title,
                detail: action.detail,
                kind: ActionKind(rawValue: action.kind) ?? .task,
                dayOffset: action.day,
                durationMinutes: action.durationMinutes,
                order: idx
            ))
        }

        do { try context.save() } catch {
            print("[SummaryPacks] save failed for \(pack.slug): \(error)")
        }
    }

    private static func bundledFolderURL() -> URL? {
        if let url = Bundle.main.url(forResource: resourceFolder, withExtension: nil) {
            return url
        }
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        let candidate = URL(fileURLWithPath: resourcePath)
            .appendingPathComponent(resourceFolder, isDirectory: true)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}

// MARK: - <slug>.json schema (decoded with .convertFromSnakeCase)

struct SummaryPack: Decodable {
    let slug: String
    let title: String
    let sourceTitle: String
    let sourceAuthor: String
    let sourceYear: Int
    let categories: [String]
    let themes: [String]
    let readMinutes: Int
    let attribution: String
    let summary: String
    let learnings: [PackLearning]
    let cards: [PackCard]
    let actions: [PackAction]

    struct PackLearning: Decodable {
        let text: String
        let chapter: String
    }

    struct PackCard: Decodable {
        let title: String
        let body: String
        let category: String
    }

    struct PackAction: Decodable {
        let title: String
        let detail: String
        let kind: String
        let day: Int
        let durationMinutes: Int
    }
}
