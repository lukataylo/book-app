import Foundation
import SwiftData

/// Local-first extraction of key learnings from a book. Hands the source text
/// to the router (which prefers on-device models for this task) and persists
/// the parsed JSON array as `KeyLearning` rows linked to the book.
@MainActor
struct ExtractionEngine {
    private let router = LLMRouter.shared

    @discardableResult
    func extract(book: Book, source: String, count: Int = 10, context: ModelContext) async throws -> [KeyLearning] {
        let trimmed = String(source.prefix(40_000))
        let (system, user) = PromptTemplates.keyLearnings(book: trimmed, count: count)
        let req = LLMRequest(
            system: system,
            user: user,
            cachedSourceText: nil,
            maxOutputTokens: 1_500,
            temperature: 0.3,
            model: .appleFoundation
        )
        let resp = try await router.run(.keyLearningsExtraction, request: req)
        let items = parse(resp.text)
        var saved: [KeyLearning] = []
        for item in items {
            let learning = KeyLearning(
                book: book,
                text: item.text,
                chapterRef: item.chapter
            )
            context.insert(learning)
            saved.append(learning)
        }
        try? context.save()
        return saved
    }

    private struct Item { let text: String; let chapter: String }

    private func parse(_ json: String) -> [Item] {
        guard let data = json.data(using: .utf8) else { return [] }
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return arr.compactMap {
                guard let t = $0["text"] as? String else { return nil }
                return Item(text: t, chapter: ($0["chapter"] as? String) ?? "")
            }
        }
        // Fallback: line-by-line, useful when the local model returns plain text.
        return json.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-•*0123456789. ")))
            return trimmed.isEmpty ? nil : Item(text: trimmed, chapter: "")
        }
    }
}
