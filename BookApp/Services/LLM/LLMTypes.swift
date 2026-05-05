import Foundation

enum LLMTask: Sendable {
    case categoryTagging
    case keyLearningsExtraction
    case quizGeneration
    case shortSummary
    case compression(targetRatio: Double)
    case expansion(targetRatio: Double)
    case styleTransfer(reference: String)
    case themeOmission(themes: [String])
    case combined(style: String?, themes: [String], targetRatio: Double?)
    case chatWithBook(question: String)
}

enum LLMProviderID: String, Sendable, Codable {
    case foundationModels
    case mlx
    case anthropic
}

enum LLMModel: String, Sendable, Codable {
    case appleFoundation     = "apple-foundation"
    case mlxLocal            = "mlx-local"
    case claudeSonnet4_6     = "claude-sonnet-4-6"
    case claudeOpus4_7       = "claude-opus-4-7"
    case claudeHaiku4_5      = "claude-haiku-4-5-20251001"

    var displayName: String {
        switch self {
        case .appleFoundation: return "Apple Foundation Models"
        case .mlxLocal:        return "MLX (on-device)"
        case .claudeSonnet4_6: return "Claude Sonnet 4.6"
        case .claudeOpus4_7:   return "Claude Opus 4.7"
        case .claudeHaiku4_5:  return "Claude Haiku 4.5"
        }
    }

    var providerID: LLMProviderID {
        switch self {
        case .appleFoundation: return .foundationModels
        case .mlxLocal:        return .mlx
        default:               return .anthropic
        }
    }

    /// Approximate per-million-token prices in USD.
    /// Used only for cost estimates; cloud spend is recorded from API responses.
    var price: (inputPerM: Double, outputPerM: Double) {
        switch self {
        case .appleFoundation, .mlxLocal: return (0, 0)
        case .claudeHaiku4_5:             return (1.0, 5.0)
        case .claudeSonnet4_6:            return (3.0, 15.0)
        case .claudeOpus4_7:              return (15.0, 75.0)
        }
    }
}

struct LLMRequest: Sendable {
    var systemPrompt: String
    var userPrompt: String
    var cachedSourceText: String?
    var maxOutputTokens: Int
    var temperature: Double
    var model: LLMModel

    init(
        system: String,
        user: String,
        cachedSourceText: String? = nil,
        maxOutputTokens: Int = 4096,
        temperature: Double = 0.7,
        model: LLMModel
    ) {
        self.systemPrompt = system
        self.userPrompt = user
        self.cachedSourceText = cachedSourceText
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.model = model
    }
}

struct LLMResponse: Sendable {
    var text: String
    var inputTokens: Int
    var outputTokens: Int
    var cachedInputTokens: Int
    var costUSD: Double
    var model: LLMModel

    var totalTokens: Int { inputTokens + outputTokens + cachedInputTokens }
}

enum LLMError: Error, LocalizedError {
    case noProviderAvailable
    case missingAPIKey
    case providerUnavailable(String)
    case rateLimited
    case decodingFailed(String)
    case http(Int, String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noProviderAvailable:        return "No language model is available on this device or account."
        case .missingAPIKey:              return "Add your Anthropic API key in Settings → AI."
        case .providerUnavailable(let m): return "Provider unavailable: \(m)"
        case .rateLimited:                return "Rate limited — try again in a moment."
        case .decodingFailed(let m):      return "Couldn't decode the model's response: \(m)"
        case .http(let code, let body):   return "HTTP \(code): \(body)"
        case .cancelled:                  return "Request cancelled."
        }
    }
}

protocol LLMProvider: Sendable {
    var id: LLMProviderID { get }
    func isAvailable() async -> Bool
    func complete(_ request: LLMRequest) async throws -> LLMResponse
}
