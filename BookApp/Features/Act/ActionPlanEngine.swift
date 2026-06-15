import Foundation
import SwiftData

/// Generates a 14-day implementation plan for a book — local-first via the
/// router, persisted as `ActionItem` rows that the Act tab renders and
/// `PlannerService` can export to Calendar / Reminders.
@MainActor
struct ActionPlanEngine {
    private let router = LLMRouter.shared

    @discardableResult
    func generate(book: Book, source: String, days: Int = 14, context: ModelContext) async throws -> [ActionItem] {
        let trimmed = String(source.prefix(40_000))
        let (system, user) = PromptTemplates.actionPlan(bookTitle: book.title, source: trimmed, days: days)
        let req = LLMRequest(
            system: system,
            user: user,
            cachedSourceText: nil,
            maxOutputTokens: 3_000,
            temperature: 0.4,
            model: .appleFoundation
        )
        let resp = try await router.run(.actionPlan, request: req)
        let items = parse(resp.text, maxDay: days)
        guard !items.isEmpty else {
            throw LLMError.decodingFailed("The model returned no usable plan steps.")
        }
        let startOrder = book.actionItems?.count ?? 0
        var saved: [ActionItem] = []
        for (idx, item) in items.enumerated() {
            let action = ActionItem(
                book: book,
                title: item.title,
                detail: item.detail,
                kind: item.kind,
                dayOffset: item.day,
                durationMinutes: item.durationMinutes,
                order: startOrder + idx
            )
            context.insert(action)
            saved.append(action)
        }
        try? context.save()
        return saved
    }

    private struct Item {
        let title: String
        let detail: String
        let kind: ActionKind
        let day: Int
        let durationMinutes: Int
    }

    private func parse(_ json: String, maxDay: Int) -> [Item] {
        guard let data = LLMJSON.extractArray(json),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return arr.compactMap {
            guard let title = $0["title"] as? String else { return nil }
            let kind = ActionKind(rawValue: ($0["kind"] as? String) ?? "task") ?? .task
            let day = min(max(($0["day"] as? Int) ?? 1, 1), maxDay)
            return Item(
                title: title,
                detail: ($0["detail"] as? String) ?? "",
                kind: kind,
                day: day,
                durationMinutes: ($0["duration_minutes"] as? Int) ?? 0
            )
        }
    }
}
