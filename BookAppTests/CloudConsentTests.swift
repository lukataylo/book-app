import Testing
import Foundation
@testable import BookApp

/// Guideline 5.1.2(i): no book text may reach a third-party AI before the
/// user has been told, by name, that it will.
///
/// These pin the *boundary*, not the call sites. Two call-site gates had
/// already drifted out of sync with the router once — background
/// auto-tagging never asked at all, and the Transformation Studio asked
/// based on its preferred model while the router was free to fall through
/// to the cloud behind it. A rejection here is silent: the app works, it
/// just transmits.
/// `.serialized` because consent is one global flag in UserDefaults:
/// swift-testing runs cases in parallel by default, and two of these
/// mutating it at once made a passing suite fail intermittently.
@Suite(.serialized)
struct CloudConsentTests {

    /// Consent lives in UserDefaults, so save and restore it around each
    /// case.
    private func withConsent(_ granted: Bool, _ body: () async -> Void) async {
        let previous = CloudConsent.granted
        defer { CloudConsent.granted = previous }
        CloudConsent.granted = granted
        await body()
    }

    @Test
    func cloudProviderIsUnavailableWithoutConsent() async {
        await withConsent(false) {
            let provider = ClaudeProvider()
            #expect(await provider.isAvailable() == false)
        }
    }

    /// `isAvailable` keeps `LLMRouter` away, but a caller holding the
    /// provider directly must not be able to transmit either — this is the
    /// last line before the network.
    @Test
    func cloudProviderRefusesToCompleteWithoutConsent() async throws {
        await withConsent(false) {
            let provider = ClaudeProvider()
            let request = LLMRequest(system: "s", user: "u", model: .claudeSonnet5)
            do {
                _ = try await provider.complete(request)
                Issue.record("complete() transmitted without consent")
            } catch let error as LLMError {
                guard case .consentRequired = error else {
                    Issue.record("expected .consentRequired, got \(error)")
                    return
                }
            } catch {
                Issue.record("expected LLMError, got \(error)")
            }
        }
    }

    /// Withdrawing consent has to actually re-close the gate — a one-way
    /// flag would make the Settings toggle a lie.
    @Test
    func withdrawingConsentClosesTheGateAgain() async {
        await withConsent(false) {
            CloudConsent.grant()
            #expect(CloudConsent.granted)
            CloudConsent.granted = false
            let provider = ClaudeProvider()
            #expect(await provider.isAvailable() == false)
        }
    }

    /// Every task the router can plan must list at least one on-device
    /// attempt before a cloud one. Without that, a device with Apple
    /// Intelligence would still reach for the network first.
    @Test
    func everyRoutingPlanTriesOnDeviceFirst() async {
        let router = LLMRouter()
        let tasks: [LLMTask] = [
            .categoryTagging, .shortSummary,
            .compression(targetRatio: 0.5),
            .expansion(targetRatio: 3.0),
            .styleTransfer(reference: "spare and literary"),
            .themeOmission(themes: ["war"]),
            .combined(style: nil, themes: [], targetRatio: 0.5),
        ]
        for task in tasks {
            let plan = await router.plan(for: task, sourceTokens: 1_000)
            #expect(plan.first == .appleFoundation, "\(task) does not try on-device first")
        }
    }
}
