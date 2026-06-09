import Foundation
import Testing
@testable import BookApp

/// Validates every bundled summary pack — the seed content for the
/// Read / Remember / Act experience. Catches malformed JSON, schema drift,
/// and content-rule violations (missing attribution, empty decks/plans)
/// before they ship.
struct SummaryPackTests {

    private static let allowedCardCategories: Set<String> = [
        "Principle", "Mental Model", "Habit", "Insight", "Warning", "Practice"
    ]

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
        return try files.map { try decoder.decode(SummaryPack.self, from: Data(contentsOf: $0)) }
    }

    @Test
    func bundleContainsTheLaunchCatalog() throws {
        let packs = try loadPacks()
        #expect(packs.count >= 8)
        #expect(Set(packs.map(\.slug)).count == packs.count, "slugs must be unique")
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
            #expect(pack.learnings.count >= 8, "\(pack.slug): needs ≥ 8 learnings")
            #expect(pack.readMinutes > 0)
            #expect(!pack.categories.isEmpty)
            #expect(!pack.themes.isEmpty)
        }
    }

    @Test
    func everyPackHasAValidCardDeck() throws {
        for pack in try loadPacks() {
            #expect(pack.cards.count >= 8, "\(pack.slug): needs ≥ 8 cards")
            for card in pack.cards {
                #expect(!card.title.isEmpty)
                #expect(!card.body.isEmpty)
                #expect(Self.allowedCardCategories.contains(card.category),
                        "\(pack.slug): unknown card category \(card.category)")
            }
        }
    }

    @Test
    func everyPackHasAValidActionPlan() throws {
        for pack in try loadPacks() {
            #expect(pack.actions.count >= 8, "\(pack.slug): needs ≥ 8 plan steps")
            var lastDay = 0
            for action in pack.actions {
                #expect(!action.title.isEmpty)
                #expect(action.day >= 1 && action.day <= 14, "\(pack.slug): day out of range")
                #expect(action.day >= lastDay, "\(pack.slug): days must be ascending")
                lastDay = action.day
                let kind = ActionKind(rawValue: action.kind)
                #expect(kind != nil, "\(pack.slug): unknown action kind \(action.kind)")
                if kind == .event {
                    #expect(action.durationMinutes > 0, "\(pack.slug): events need a duration")
                }
            }
            let kinds = Set(pack.actions.map(\.kind))
            #expect(kinds.contains("task") && kinds.contains("event"),
                    "\(pack.slug): plan should mix tasks and events")
        }
    }
}
