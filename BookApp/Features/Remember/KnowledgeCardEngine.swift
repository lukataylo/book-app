import Foundation
import SwiftData

/// Generates a deck of knowledge cards for a book that doesn't have one —
/// local-first via the router, persisted as `KnowledgeCard` rows.
@MainActor
struct KnowledgeCardEngine {
    private let router = LLMRouter.shared

    @discardableResult
    func generate(book: Book, source: String, count: Int = 10, context: ModelContext) async throws -> [KnowledgeCard] {
        let trimmed = String(source.prefix(40_000))
        let (system, user) = PromptTemplates.knowledgeCards(bookTitle: book.title, source: trimmed, count: count)
        let req = LLMRequest(
            system: system,
            user: user,
            cachedSourceText: nil,
            maxOutputTokens: 3_000,
            temperature: 0.4,
            model: .appleFoundation
        )
        let resp = try await router.run(.knowledgeCards, request: req)
        let items = parse(resp.text)
        guard !items.isEmpty else {
            throw LLMError.decodingFailed("The model returned no usable cards.")
        }
        let startOrder = book.knowledgeCards?.count ?? 0
        var saved: [KnowledgeCard] = []
        for (idx, item) in items.enumerated() {
            let card = KnowledgeCard(
                book: book,
                title: item.title,
                body: item.body,
                category: item.category,
                order: startOrder + idx,
                source: "generated"
            )
            context.insert(card)
            saved.append(card)
        }
        try? context.save()
        return saved
    }

    private struct Item { let title: String; let body: String; let category: String }

    private func parse(_ json: String) -> [Item] {
        guard let data = LLMJSON.extractArray(json),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return arr.compactMap {
            guard let title = $0["title"] as? String,
                  let body = $0["body"] as? String else { return nil }
            return Item(title: title, body: body, category: ($0["category"] as? String) ?? "Insight")
        }
    }
}
