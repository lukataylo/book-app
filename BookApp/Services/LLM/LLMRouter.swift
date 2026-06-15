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
    /// On-device Apple Foundation Models is now the *first* attempt for
    /// every transformation task: transformation chunks are explicitly
    /// sized to fit its 4K context (see `TransformationEngine.chunkSize`),
    /// so users without a Claude API key still get usable output.
    func plan(for task: LLMTask, sourceTokens: Int) -> [LLMModel] {
        switch task {
        case .categoryTagging, .keyLearningsExtraction, .quizGeneration, .shortSummary:
            return [.appleFoundation, .claudeHaiku4_5]
        case .knowledgeCards, .actionPlan:
            // Structured-JSON output benefits from a stronger cloud fallback
            // than Haiku, but the local-first policy still applies.
            return [.appleFoundation, .claudeSonnet4_6, .claudeHaiku4_5]
        case .compression:
            return [.appleFoundation, .claudeSonnet4_6, .claudeOpus4_7]
        case .expansion(let ratio):
            if ratio >= 3.0 { return [.appleFoundation, .claudeOpus4_7, .claudeSonnet4_6] }
            return [.appleFoundation, .claudeSonnet4_6, .claudeOpus4_7]
        case .styleTransfer:
            return [.appleFoundation, .claudeOpus4_7, .claudeSonnet4_6]
        case .themeOmission:
            return [.appleFoundation, .claudeSonnet4_6, .claudeOpus4_7]
        case .combined:
            return [.appleFoundation, .claudeOpus4_7, .claudeSonnet4_6]
        case .chatWithBook:
            return [.appleFoundation, .claudeSonnet4_6, .claudeHaiku4_5]
        }
    }

    /// Run a request, trying models in fallback order. The caller-provided
    /// `request.model` is used as a hard override when set to something
    /// other than `.claudeSonnet4_6` (the default placeholder).
    func run(_ task: LLMTask, request: LLMRequest, sourceTokens: Int? = nil) async throws -> LLMResponse {
        let plan = self.plan(for: task, sourceTokens: sourceTokens ?? Chunker.tokenEstimate(request.cachedSourceText ?? request.userPrompt))
        var lastError: Error = LLMError.noProviderAvailable

        for model in plan {
            try Task.checkCancellation()
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
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as LLMError {
                lastError = error
                // Fall through to the next provider for any *recoverable*
                // error: missing key (user hasn't pasted one yet), the
                // provider explicitly told us it's unavailable, transient
                // rate limiting, decode failures (cloud sometimes returns
                // partial JSON), or a 5xx from the upstream API. A real
                // user-input or auth failure (4xx other than 401/429) is
                // not the next provider's problem — surface it.
                switch error {
                case .missingAPIKey, .providerUnavailable, .rateLimited, .decodingFailed:
                    continue
                case .http(let code, _) where code >= 500 || code == 401 || code == 429:
                    continue
                case .cancelled:
                    throw error
                default:
                    throw error
                }
            } catch {
                if error is CancellationError { throw error }
                lastError = error
                continue
            }
        }
        throw lastError
    }
}
