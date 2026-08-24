import Foundation

/// Tracks the user's one-time, explicit consent to send their content to
/// Anthropic before anything leaves the device.
///
/// Apple Guideline 5.1.2(i) (Nov 2025) requires a named, pre-transmission
/// consent gate before user content reaches a third-party AI. The flag is
/// persisted in `UserDefaults` so the gate is shown once and remembered.
///
/// Enforcement lives in `ClaudeProvider`, not at the call sites. That is
/// deliberate: the provider is the only code in the app that opens a
/// connection to `api.anthropic.com`, so gating it there means no feature
/// — present or future — can transmit a book by forgetting to ask. Two
/// call-site gates had already drifted out of sync with the router before
/// this moved: background auto-tagging never asked at all, and the
/// Transformation Studio asked based on its *preferred* model while the
/// router was free to fall through to the cloud behind it.
enum CloudConsent {
    /// `UserDefaults` key. Versioned so the gate can be re-shown if the
    /// disclosure copy materially changes.
    private static let key = "CloudAI.consentGranted-v1"

    /// Whether the user has granted consent to transmit content to Anthropic.
    static var granted: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// Records that the user explicitly allowed cloud transmission.
    static func grant() {
        granted = true
    }
}
