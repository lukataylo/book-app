import Foundation
import SwiftData

struct TransformationRequest: Sendable {
    let kind: VariantKind
    /// Target length as a ratio of the source. <1 compresses, >1 expands.
    let targetRatio: Double
    let styleReference: String
    let omittedThemes: [String]
    let modelOverride: LLMModel?
}

struct TransformationProgress: Sendable {
    var phase: Phase
    var chunkIndex: Int
    var chunkCount: Int
    var inputTokens: Int
    var outputTokens: Int
    var costUSD: Double
    /// Best-guess remaining wall-clock from per-chunk timing (Apple FM is
    /// 5-15s per chunk, so this matters for the long on-device runs).
    var estimatedSecondsRemaining: Double = 0
    enum Phase: Sendable { case chunking, mapping, seamRewriting, polishing, persisting, done }
}

struct CostEstimate: Sendable {
    let inputTokens: Int
    let estOutputTokens: Int
    let model: LLMModel
    let usd: Double
    let chunkCount: Int
}

/// Map-reduce pipeline for compressing / expanding / re-styling a book.
/// Source text is sent as a `cache_control: ephemeral` block on every chunk
/// call so cost on subsequent transforms stays low while the cache TTL holds.
@MainActor
final class TransformationEngine {

    private let router = LLMRouter.shared
    private let store = BookStore.shared

    /// Per-model chunk budget. Apple FM tops out at ~4K tokens (input +
    /// output combined), so on-device runs use 2K-token chunks with light
    /// overlap. Cloud models stay at 80K to keep round-trips down.
    static func chunkSize(for model: LLMModel) -> (max: Int, overlap: Int) {
        switch model {
        case .appleFoundation: return (max: 2_000, overlap: 200)
        case .mlxLocal:        return (max: 4_000, overlap: 400)
        default:               return (max: 80_000, overlap: 4_000)
        }
    }

    /// Estimate cost before kicking off the real run. Uses Anthropic's
    /// list price; the local provider returns 0. The chunk count is
    /// model-dependent because chunk size scales with the model's
    /// context window.
    func estimate(source: String, request: TransformationRequest) -> CostEstimate {
        let model = request.modelOverride ?? defaultModel(for: request)
        let (maxTok, overlap) = Self.chunkSize(for: model)
        let chunks = Chunker.chunk(source, maxTokens: maxTok, overlapTokens: overlap)
        let inputTokens = chunks.reduce(0) { $0 + $1.approxTokens }
        let outputTokens = max(1, Int(Double(inputTokens) * request.targetRatio))
        let price = model.price
        let usd = (Double(inputTokens) * price.inputPerM + Double(outputTokens) * price.outputPerM) / 1_000_000
        return CostEstimate(
            inputTokens: inputTokens,
            estOutputTokens: outputTokens,
            model: model,
            usd: usd,
            chunkCount: chunks.count
        )
    }

    /// Run the transformation. The `progress` callback fires on every phase
    /// change so the UI can show a granular progress bar. Returns the new
    /// `BookVariant`, persisted into the same `ModelContext`.
    func run(
        on book: Book,
        sourceText: String,
        sourceVariant: BookVariant,
        request: TransformationRequest,
        context: ModelContext,
        progress: @MainActor (TransformationProgress) -> Void
    ) async throws -> BookVariant {
        let model = request.modelOverride ?? defaultModel(for: request)
        let routedTask = self.task(for: request)
        let (maxTok, overlap) = Self.chunkSize(for: model)
        let chunks = Chunker.chunk(sourceText, maxTokens: maxTok, overlapTokens: overlap)
        let startTime = Date.now
        progress(TransformationProgress(phase: .chunking, chunkIndex: 0, chunkCount: chunks.count, inputTokens: 0, outputTokens: 0, costUSD: 0))

        var transformedChunks: [String] = []
        transformedChunks.reserveCapacity(chunks.count)
        var totalInput = 0, totalOutput = 0, totalCost = 0.0

        for chunk in chunks {
            let (system, user) = PromptTemplates.transformChunk(
                kind: request.kind,
                targetRatio: request.targetRatio,
                styleReference: request.styleReference,
                omittedThemes: request.omittedThemes,
                chunkIndex: chunk.index,
                chunkCount: chunk.total
            )
            let req = LLMRequest(
                system: system,
                user: user,
                cachedSourceText: chunk.text,
                maxOutputTokens: max(1024, Int(Double(chunk.approxTokens) * request.targetRatio * 1.2)),
                temperature: temperature(for: request.kind),
                model: model
            )
            try Task.checkCancellation()
            let resp = try await router.run(routedTask, request: req, sourceTokens: chunk.approxTokens)
            transformedChunks.append(resp.text)
            totalInput += resp.inputTokens + resp.cachedInputTokens
            totalOutput += resp.outputTokens
            totalCost += resp.costUSD
            // ETA from average wall-clock per finished chunk.
            let done = chunk.index + 1
            let elapsed = Date.now.timeIntervalSince(startTime)
            let avg = elapsed / Double(max(1, done))
            let remaining = avg * Double(chunks.count - done)
            progress(TransformationProgress(
                phase: .mapping, chunkIndex: done, chunkCount: chunks.count,
                inputTokens: totalInput, outputTokens: totalOutput, costUSD: totalCost,
                estimatedSecondsRemaining: remaining
            ))
        }

        // Reduce: rewrite seams between consecutive chunks so the output flows.
        if transformedChunks.count > 1 {
            for i in 0..<(transformedChunks.count - 1) {
                progress(TransformationProgress(
                    phase: .seamRewriting, chunkIndex: i + 1, chunkCount: transformedChunks.count - 1,
                    inputTokens: totalInput, outputTokens: totalOutput, costUSD: totalCost
                ))
                let left = transformedChunks[i]
                let right = transformedChunks[i + 1]
                let leftTail = String(left.suffix(800))
                let rightHead = String(right.prefix(800))
                let (sys, _) = PromptTemplates.seamRewrite()
                let req = LLMRequest(
                    system: sys,
                    user: "PASSAGE A (end):\n\(leftTail)\n\nPASSAGE B (start):\n\(rightHead)",
                    maxOutputTokens: 2_048,
                    temperature: 0.3,
                    model: model
                )
                let resp = try await router.run(routedTask, request: req)
                totalInput += resp.inputTokens + resp.cachedInputTokens
                totalOutput += resp.outputTokens
                totalCost += resp.costUSD
                if let parsed = parseSeam(resp.text) {
                    transformedChunks[i] = String(left.dropLast(leftTail.count)) + parsed.left
                    transformedChunks[i + 1] = parsed.right + String(right.dropFirst(rightHead.count))
                }
            }
        }

        let merged = transformedChunks.joined(separator: "\n\n")

        progress(TransformationProgress(
            phase: .persisting, chunkIndex: chunks.count, chunkCount: chunks.count,
            inputTokens: totalInput, outputTokens: totalOutput, costUSD: totalCost
        ))

        let targetPages = Int(Double(book.totalPagesEstimate) * request.targetRatio)
        let newVariant = BookVariant(
            book: book,
            kind: request.kind,
            contentText: merged,
            targetPages: targetPages,
            styleReference: request.styleReference,
            omittedThemes: request.omittedThemes,
            modelUsed: model.rawValue,
            sourceVariantID: sourceVariant.id
        )
        newVariant.inputTokens = totalInput
        newVariant.outputTokens = totalOutput
        newVariant.costUSD = totalCost

        // Stash the body on disk too so downstream consumers can stream it.
        if let (_, bookmark) = try? store.saveVariant(text: merged, bookID: book.id, variantID: newVariant.id) {
            newVariant.contentBookmark = bookmark
        }

        context.insert(newVariant)
        try context.save()

        progress(TransformationProgress(
            phase: .done, chunkIndex: chunks.count, chunkCount: chunks.count,
            inputTokens: totalInput, outputTokens: totalOutput, costUSD: totalCost
        ))
        return newVariant
    }

    // MARK: - Helpers

    /// Apple-Intelligence-aware default. The studio refreshes
    /// `localAvailableHint` from `LocalProvider().isAvailable()` on
    /// appear, so users with an Apple Intelligence-capable device get
    /// on-device transformations without a Claude API key.
    var localAvailableHint: Bool = false

    private func defaultModel(for request: TransformationRequest) -> LLMModel {
        if localAvailableHint {
            return .appleFoundation
        }
        switch request.kind {
        case .styled:        return .claudeOpus4_7
        case .expanded where request.targetRatio >= 3: return .claudeOpus4_7
        case .compressed where request.targetRatio >= 0.30: return .appleFoundation
        default:             return .claudeSonnet4_6
        }
    }

    private func task(for request: TransformationRequest) -> LLMTask {
        switch request.kind {
        case .compressed:   return .compression(targetRatio: request.targetRatio)
        case .expanded:     return .expansion(targetRatio: request.targetRatio)
        case .styled:       return .styleTransfer(reference: request.styleReference)
        case .themeOmitted: return .themeOmission(themes: request.omittedThemes)
        case .original:     return .shortSummary
        }
    }

    private func temperature(for kind: VariantKind) -> Double {
        switch kind {
        case .compressed:   return 0.3
        case .expanded:     return 0.55
        case .styled:       return 0.7
        case .themeOmitted: return 0.3
        case .original:     return 0.0
        }
    }

    private func parseSeam(_ json: String) -> (left: String, right: String)? {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let left = payload["left"] as? String,
              let right = payload["right"] as? String else {
            return nil
        }
        return (left, right)
    }
}
