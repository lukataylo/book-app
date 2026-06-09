import Foundation

/// Tolerant extraction of JSON payloads from model output. Small local
/// models in particular like to wrap JSON in ``` fences or add a line of
/// preamble; a successful-but-malformed response never reaches the router's
/// provider-fallback path, so the parsers need to do the cleanup themselves.
enum LLMJSON {
    /// Returns the bytes of the first top-level `[...]` array in `text`,
    /// stripping markdown code fences first. `nil` when no array exists.
    static func extractArray(_ text: String) -> Data? {
        var cleaned = text
        if cleaned.contains("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
        }
        guard let start = cleaned.firstIndex(of: "["),
              let end = cleaned.lastIndex(of: "]"),
              start < end else { return nil }
        return String(cleaned[start...end]).data(using: .utf8)
    }
}
