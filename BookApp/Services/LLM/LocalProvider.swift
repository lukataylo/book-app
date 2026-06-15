import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device LLM provider backed by Apple's `FoundationModels` framework
/// (free, private, available on Apple Intelligence devices since iOS 26).
/// When the framework or model isn't available the router falls through to
/// the cloud provider.
final actor LocalProvider: LLMProvider {
    let id: LLMProviderID = .foundationModels

    private var foundationReady: Bool?

    func isAvailable() async -> Bool {
        await foundationModelsAvailable()
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        if await foundationModelsAvailable() {
            return try await runFoundationModels(request)
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

    /// Public mirror so the Settings diagnostic can show users why Apple
    /// Intelligence is or isn't responding. Returns one of: "Available",
    /// "Not available", "Apple Intelligence isn't enabled on this device",
    /// or a system-supplied unavailability reason.
    func availabilityReport() async -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return "Available"
            case .unavailable(let reason):
                return reasonText(reason)
            @unknown default:
                return "Unknown availability"
            }
        }
        return "Requires iOS 26 / macOS 26"
        #else
        return "FoundationModels framework isn't linked"
        #endif
    }

    /// Tiny end-to-end test — round-trips a one-sentence prompt to the
    /// on-device model and surfaces either the response text or the error.
    func ping() async -> String {
        guard await foundationModelsAvailable() else {
            return "Unavailable: \(await availabilityReport())"
        }
        let req = LLMRequest(
            system: "Reply with one short sentence.",
            user: "Say hello in five words.",
            cachedSourceText: nil,
            maxOutputTokens: 64,
            temperature: 0.3,
            model: .appleFoundation
        )
        do {
            let resp = try await complete(req)
            return resp.text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private nonisolated func reasonText(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings → Apple Intelligence."
        case .modelNotReady:
            return "The on-device model is still downloading."
        @unknown default:
            return "Apple Intelligence is unavailable."
        }
    }
    #endif

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
}
