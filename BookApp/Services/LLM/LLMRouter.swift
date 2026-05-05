import Foundation

/// Decides which provider + model handles each task. See plan §"LLM routing rules".
///
/// The router is the only place that knows about provider availability — every
/// caller (TransformationEngine, ExtractionEngine, etc.) just hands it a task and
/// gets back a finished `LLMResponse`. If the preferred provider isn't available
/// it falls through to the next one in the chain (local → cloud, or vice versa).
final actor LLMRouter {
    static let shared = LLMRouter()

    private let local: LocalProvider
    private let cloud: ClaudeProvider

    init(local: LocalProvider = LocalProvider(), cloud: ClaudeProvider = ClaudeProvider()) {
        self.local = local
        self.cloud = cloud
    }

    /// Routing policy — one place to read off the table from the plan.
    func plan(for task: LLMTask, sourceTokens: Int) -> [LLMModel] {
        switch task {
        case .categoryTagging, .keyLearningsExtraction, .quizGeneration, .shortSummary:
            return [.appleFoundation, .mlxLocal, .claudeHaiku4_5]

        case .compression(let ratio):
            if ratio >= 0.30, sourceTokens < 50_000 {
                return [.appleFoundation, .mlxLocal, .claudeSonnet4_6]
            }
            return [.claudeSonnet4_6, .claudeOpus4_7]

        case .expansion(let ratio):
            if ratio >= 3.0 { return [.claudeOpus4_7, .claudeSonnet4_6] }
            return [.claudeSonnet4_6, .claudeOpus4_7]

        case .styleTransfer:
            return [.claudeOpus4_7, .claudeSonnet4_6]

        case .themeOmission:
            return [.claudeSonnet4_6, .claudeOpus4_7]

        case .combined(_, _, let ratio):
            if let r = ratio, r >= 3.0 { return [.claudeOpus4_7, .claudeSonnet4_6] }
            return [.claudeOpus4_7, .claudeSonnet4_6]

        case .chatWithBook:
            return [.claudeSonnet4_6, .claudeHaiku4_5]
        }
    }

    /// Run a request, trying models in fallback order. The caller-provided
    /// `request.model` is used as a hard override when set to something
    /// other than `.claudeSonnet4_6` (the default placeholder).
    func run(_ task: LLMTask, request: LLMRequest, sourceTokens: Int? = nil) async throws -> LLMResponse {
        let plan = self.plan(for: task, sourceTokens: sourceTokens ?? Chunker.tokenEstimate(request.cachedSourceText ?? request.userPrompt))
        var lastError: Error = LLMError.noProviderAvailable

        for model in plan {
            let provider: LLMProvider
            switch model.providerID {
            case .foundationModels, .mlx: provider = local
            case .anthropic:              provider = cloud
            }
            guard await provider.isAvailable() else { continue }
            var attempt = request
            attempt.model = model
            do {
                return try await provider.complete(attempt)
            } catch let error as LLMError {
                lastError = error
                if case .missingAPIKey = error, model.providerID == .anthropic { continue }
                if case .providerUnavailable = error { continue }
                throw error
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError
    }
}
