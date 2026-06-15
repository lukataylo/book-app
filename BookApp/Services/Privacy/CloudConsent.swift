import Foundation

/// Tracks the user's one-time, explicit consent to send their content to
/// Anthropic (Claude) before any cloud transformation or cloud teach-back
/// grading runs.
///
/// Apple Guideline 5.1.2(i) (Nov 2025) requires a named, pre-transmission
/// consent gate before user content is sent to a third-party AI. The flag is
/// persisted in `UserDefaults` so the gate is shown once and remembered.
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
