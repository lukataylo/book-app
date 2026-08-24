import Foundation

/// Anthropic Messages API client with prompt caching.
///
/// Cached source text is sent as a system block with `cache_control: ephemeral`
/// so subsequent transforms of the same book within the 5-minute TTL pay ~10%
/// of the input-token price for that block.
final actor ClaudeProvider: LLMProvider {
    let id: LLMProviderID = .anthropic

    /// Hard-coded URL is well-formed but we still avoid the `!` so a
    /// future typo can't crash the app — the fallback is provider
    /// unavailability, not termination.
    private static let endpointURL: URL = {
        URL(string: "https://api.anthropic.com/v1/messages") ?? URL(fileURLWithPath: "/")
    }()

    private let session: URLSession
    private let endpoint: URL
    private let apiVersion = "2023-06-01"

    init(session: URLSession? = nil) {
        // Default session has no per-request timeout. Long Claude calls
        // can run 60+ s, but we still need an upper bound so a hung
        // network connection doesn't keep a Task alive forever and
        // prevent cancellation. 120s request / 180s resource is the same
        // shape Anthropic's own SDK ships.
        if let provided = session {
            self.session = provided
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 120
            cfg.timeoutIntervalForResource = 180
            cfg.waitsForConnectivity = true
            cfg.httpMaximumConnectionsPerHost = 4
            self.session = URLSession(configuration: cfg)
        }
        self.endpoint = Self.endpointURL
    }

    /// Unavailable without a key *or* without consent, so `LLMRouter`
    /// skips this provider the same way it skips a device with no Apple
    /// Intelligence. Guideline 5.1.2(i): nothing reaches a third-party AI
    /// until the user has been told, by name, that it will.
    func isAvailable() async -> Bool {
        CloudConsent.granted && KeychainStore.shared.read(.anthropicAPIKey) != nil
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        // Belt and braces: `isAvailable` already keeps the router away,
        // but a caller holding a provider directly must not be able to
        // transmit either. This is the last line before the network.
        guard CloudConsent.granted else {
            throw LLMError.consentRequired
        }
        guard let apiKey = KeychainStore.shared.read(.anthropicAPIKey) else {
            throw LLMError.missingAPIKey
        }

        var systemBlocks: [[String: Any]] = [
            ["type": "text", "text": request.systemPrompt]
        ]
        if let cached = request.cachedSourceText, !cached.isEmpty {
            systemBlocks.append([
                "type": "text",
                "text": cached,
                "cache_control": ["type": "ephemeral"]
            ])
        }

        // No `temperature`: sampling parameters are rejected with a 400
        // on Sonnet 5 / Opus 5. Thinking is left unset too — both models
        // run adaptive thinking by default when the field is absent.
        let body: [String: Any] = [
            "model": request.model.rawValue,
            "max_tokens": request.maxOutputTokens,
            "system": systemBlocks,
            "messages": [
                ["role": "user", "content": request.userPrompt]
            ]
        ]

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.providerUnavailable("No HTTP response")
        }
        if http.statusCode == 429 { throw LLMError.rateLimited }
        if !(200..<300).contains(http.statusCode) {
            let snippet = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.http(http.statusCode, snippet)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw LLMError.decodingFailed("not a JSON object")
        }

        // A safety classifier can decline the request: HTTP 200, empty
        // text, `stop_reason: "refusal"`. Without this check the caller
        // sees a silently blank transformation.
        if (json["stop_reason"] as? String) == "refusal" {
            let detail = (json["stop_details"] as? [String: Any])?["explanation"] as? String
            throw LLMError.refused(detail ?? "The model declined this request.")
        }

        let contentArray = json["content"] as? [[String: Any]] ?? []
        let text = contentArray
            .compactMap { ($0["type"] as? String) == "text" ? ($0["text"] as? String) : nil }
            .joined()

        let usage = json["usage"] as? [String: Any] ?? [:]
        let input = usage["input_tokens"] as? Int ?? 0
        let cached = (usage["cache_read_input_tokens"] as? Int)
            ?? (usage["cache_creation_input_tokens"] as? Int)
            ?? 0
        let output = usage["output_tokens"] as? Int ?? 0

        let price = request.model.price
        let cost = (Double(input) * price.inputPerM
                    + Double(cached) * price.inputPerM * 0.1
                    + Double(output) * price.outputPerM) / 1_000_000

        return LLMResponse(
            text: text,
            inputTokens: input,
            outputTokens: output,
            cachedInputTokens: cached,
            costUSD: cost,
            model: request.model
        )
    }
}
