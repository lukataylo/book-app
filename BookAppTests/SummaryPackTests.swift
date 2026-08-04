import Foundation
import Testing
@testable import BookApp

/// Validates every bundled summary pack — the seed content for the Read
/// tab. Catches malformed JSON, schema drift, and content-rule violations
/// (missing attribution, too-short summaries) before they ship.
struct SummaryPackTests {

    private func loadPacks() throws -> [SummaryPack] {
        // Hosted unit tests: Bundle.main is the app bundle, where the
        // SummaryPacks folder reference lives.
        guard let folder = Bundle.main.url(forResource: "SummaryPacks", withExtension: nil) else {
            Issue.record("SummaryPacks folder missing from the app bundle")
            return []
        }
        let files = try FileManager.default
            .contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "json" }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try files.map { file in
            let pack = try decoder.decode(SummaryPack.self, from: Data(contentsOf: file))
            // The loader's skip-before-decode fast path keys on filename
            // while persistence keys on slug — they must stay identical.
            #expect(pack.slug == file.deletingPathExtension().lastPathComponent,
                    "\(file.lastPathComponent): slug must match filename")
            return pack
        }
    }

    @Test
    func bundleContainsTheLaunchCatalog() throws {
        let packs = try loadPacks()
        #expect(!packs.isEmpty, "catalog must ship at least one pack")
        #expect(Set(packs.map(\.slug)).count == packs.count, "slugs must be unique")
        #expect(Set(packs.map(\.title)).count == packs.count, "titles must be unique")
    }

    /// The catalog ships summaries of public-domain sources only — the
    /// in-copyright titles were pulled before submission. 1930 is the US
    /// public-domain cutoff as of 2026; re-check it when the year rolls.
    @Test
    func everySourceIsOutOfCopyright() throws {
        for pack in try loadPacks() {
            #expect(pack.sourceYear < 1930,
                    "\(pack.slug): \(pack.sourceTitle) (\(pack.sourceYear)) is still in copyright")
        }
    }

    @Test
    func everyPackHasLegalFraming() throws {
        for pack in try loadPacks() {
            #expect(pack.title.hasPrefix("The Big Ideas in"), "\(pack.slug): summary-edition naming convention")
            #expect(pack.attribution.contains("original summary"), "\(pack.slug): attribution must state it's an original summary")
            #expect(pack.attribution.contains("Not affiliated"), "\(pack.slug): attribution must disclaim affiliation")
            #expect(pack.attribution.contains(pack.sourceAuthor), "\(pack.slug): attribution must credit the author")
            #expect(pack.attribution.contains("buy the full book") || pack.attribution.contains("Buy the full book"),
                    "\(pack.slug): attribution must point at the original")
        }
    }

    @Test
    func everyPackHasSubstantiveContent() throws {
        for pack in try loadPacks() {
            let words = pack.summary.split(whereSeparator: { $0.isWhitespace }).count
            #expect(words >= 1_000, "\(pack.slug): summary too short (\(words) words)")
            #expect(pack.summary.contains("# "), "\(pack.slug): summary needs section headings")
            // Every catalog title ships a second, short length tier.
            let gist = pack.summaryShort ?? ""
            let gistWords = gist.split(whereSeparator: { $0.isWhitespace }).count
            #expect(gistWords >= 200 && gistWords <= 450, "\(pack.slug): quick take out of range (\(gistWords) words)")
            #expect(!gist.contains("# "), "\(pack.slug): quick take must be plain paragraphs")
            #expect(pack.learnings.count >= 8, "\(pack.slug): needs ≥ 8 learnings")
            #expect(pack.readMinutes > 0)
            #expect(!pack.categories.isEmpty)
            #expect(!pack.themes.isEmpty)
        }
    }

}
