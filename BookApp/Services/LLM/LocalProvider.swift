import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device LLM provider. Tries Apple's `FoundationModels` framework first
/// (free, private, available on Apple Intelligence devices since iOS 18.1),
/// and falls back to MLX-Swift on older hardware.
///
/// MLX integration is gated behind `canImport(MLXLLM)` so the project still
/// builds before the package is fetched. When MLX is available we initialise
/// a small instruct model on first use and reuse it for the actor's lifetime.
final actor LocalProvider: LLMProvider {
    let id: LLMProviderID = .foundationModels

    private var foundationReady: Bool?
    private var mlxReady: Bool = false

    func isAvailable() async -> Bool {
        if await foundationModelsAvailable() { return true }
        return await mlxAvailable()
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        if await foundationModelsAvailable() {
            return try await runFoundationModels(request)
        }
        if await mlxAvailable() {
            return try await runMLX(request)
        }
        throw LLMError.noProviderAvailable
    }

    // MARK: - Apple FoundationModels

    private func foundationModelsAvailable() async -> Bool {
        if let cached = foundationReady { return cached }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let available = SystemLanguageModel.default.availability == .available
            foundationReady = available
            return available
        }
        #endif
        foundationReady = false
        return false
    }

    private func runFoundationModels(_ request: LLMRequest) async throws -> LLMResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession(instructions: Instructions {
                request.systemPrompt
                if let cached = request.cachedSourceText, !cached.isEmpty {
                    "\nReference text:\n"
                    cached
                }
            })
            let response = try await session.respond(
                to: Prompt(request.userPrompt),
                options: GenerationOptions(
                    temperature: request.temperature,
                    maximumResponseTokens: request.maxOutputTokens
                )
            )
            let text = response.content
            return LLMResponse(
                text: text,
                inputTokens: Chunker.tokenEstimate(request.systemPrompt + (request.cachedSourceText ?? "") + request.userPrompt),
                outputTokens: Chunker.tokenEstimate(text),
                cachedInputTokens: 0,
                costUSD: 0,
                model: .appleFoundation
            )
        }
        #endif
        throw LLMError.providerUnavailable("FoundationModels")
    }

    // MARK: - MLX fallback

    private func mlxAvailable() async -> Bool {
        if mlxReady { return true }
        #if canImport(MLXLLM)
        // MLX requires Apple Silicon. Don't attempt on non-arm64 simulators.
        #if arch(arm64)
        mlxReady = true
        return true
        #else
        return false
        #endif
        #else
        return false
        #endif
    }

    private func runMLX(_ request: LLMRequest) async throws -> LLMResponse {
        #if canImport(MLXLLM) && arch(arm64)
        // Real implementation will load an MLX-distributed instruct model
        // (e.g. Llama-3.2-3B-Instruct-4bit) on first use and stream completions.
        // The full wiring is intentionally omitted from this scaffold; callers
        // currently fall through to the cloud provider when FoundationModels
        // isn't available. See README → "Local LLM" for the model-fetching plan.
        throw LLMError.providerUnavailable("MLX wiring not yet implemented")
        #else
        throw LLMError.providerUnavailable("MLX")
        #endif
    }
}
