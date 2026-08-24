import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var apiKey: String = ""
    @State private var hasKey: Bool = false
    @State private var monthlySpend: Double = 0
    @State private var onDeviceStatus: String = "Checking…"
    @State private var onDeviceTestResult: String?
    @State private var testingOnDevice: Bool = false
    @StateObject private var stats = ReadingStats.shared

    @State private var confirmReset = false
    @State private var resetDone = false
    @State private var cloudConsent: Bool = CloudConsent.granted

    // Published by .github/workflows/pages.yml. Trailing slashes match the
    // Jekyll permalinks exactly — App Review follows these links, and a
    // redirect that fails is the same as a dead page.
    private static let privacyPolicyURL = URL(string: "https://lukataylo.github.io/book-app/privacy/")
    // A support *page*, not a mailto: — Review expects somewhere a user can
    // land, and a mailto put a personal address in the shipped binary.
    private static let supportURL = URL(string: "https://lukataylo.github.io/book-app/support/")

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading") {
                    HStack {
                        Text("Current streak")
                        Spacer()
                        // ^[…](inflect: true) is Apple's automatic-grammar
                        // morphology — translators write "1 day" and the
                        // system pluralises per locale rules.
                        Text("^[\(stats.currentStreak) day](inflect: true)")
                            .foregroundStyle(stats.currentStreak > 0 ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("This week")
                        Spacer()
                        Text(formatMinutes(stats.minutesThisWeek))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("All time")
                        Spacer()
                        Text(formatMinutes(stats.minutesAllTime))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Section("AI") {
                    Text("Cloud features use your own Anthropic account, billed directly by Anthropic. Get a key at console.anthropic.com. Everything else works without one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Anthropic API key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    HStack {
                        Button("Save key") {
                            KeychainStore.shared.write(.anthropicAPIKey, value: apiKey)
                            apiKey = ""
                            hasKey = true
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                        Spacer()
                        if hasKey {
                            Label("Stored in Keychain", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    if hasKey {
                        Button("Remove key", role: .destructive) {
                            KeychainStore.shared.delete(.anthropicAPIKey)
                            hasKey = false
                        }
                    }
                    Text("Your key stays on this device in the iOS Keychain. It is sent only to api.anthropic.com when you run a Cloud transformation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("Spend this month")
                        Spacer()
                        Text(String(format: "$%.2f", monthlySpend))
                            .monospacedDigit()
                    }
                }

                Section("On-device model") {
                    HStack {
                        Text("Apple Intelligence")
                        Spacer()
                        Text(onDeviceStatus)
                            .foregroundStyle(onDeviceStatus == "Available"
                                             ? .green
                                             : Theme.Palette.textSecondary)
                            .font(.callout)
                    }
                    Button {
                        Task { await runOnDeviceTest() }
                    } label: {
                        HStack {
                            if testingOnDevice {
                                ProgressView().scaleEffect(0.8)
                                    .padding(.trailing, 6)
                            } else {
                                Image(systemName: "sparkles")
                                    .padding(.trailing, 4)
                            }
                            Text(testingOnDevice ? "Testing…" : "Test on-device model")
                        }
                    }
                    .disabled(testingOnDevice)
                    if let result = onDeviceTestResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Text("On-device handles short tasks (auto-categorisation, short rewrites). Whole-book compression and re-style need a Claude API key; the on-device context window is too small.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    // Guideline 5.1.2(i) consent has to be withdrawable,
                    // not just grantable — and the Studio's consent sheet
                    // tells the user this control is here. Turning it off
                    // makes `ClaudeProvider` report unavailable, so the
                    // router stops routing anything to the cloud at all.
                    Toggle("Allow sending text to Anthropic", isOn: $cloudConsent)
                        .onChange(of: cloudConsent) { _, allowed in
                            CloudConsent.granted = allowed
                        }
                    Text("Cloud transformations send the source book to Anthropic (api.anthropic.com) for that request only, under your own API key. On-device transformations never leave your device, and nothing is ever sent to Epigrapha. Turn this off and cloud features stop entirely — on-device features keep working.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    Button("Reset all content", role: .destructive) {
                        confirmReset = true
                    }
                    Text("Deletes every book and highlight from this device. The starter library reloads next launch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    NavigationLink {
                        AcknowledgementsView()
                    } label: {
                        Text("Acknowledgements & licenses")
                    }
                    if let url = Self.privacyPolicyURL {
                        Link("Privacy Policy", destination: url)
                    }
                    if let url = Self.supportURL {
                        Link("Contact support", destination: url)
                    }
                    HStack { Text("Version"); Spacer(); Text(appVersion).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                cloudConsent = CloudConsent.granted
                recomputeSpend()
                hasKey = KeychainStore.shared.read(.anthropicAPIKey) != nil
            }
            .task {
                onDeviceStatus = await LocalProvider().availabilityReport()
            }
            .alert("Reset all content?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { resetAllContent() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your books and highlights on this device.")
            }
            .alert("Content reset", isPresented: $resetDone) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Relaunch the app to reload the starter library.")
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    /// Delete all user + catalog content and clear the seed flags so the
    /// starter library re-seeds on the next launch.
    private func resetAllContent() {
        try? modelContext.delete(model: Book.self)
        try? modelContext.delete(model: Annotation.self)
        try? modelContext.delete(model: Bookmark.self)
        try? modelContext.delete(model: ReadingProgress.self)
        try? modelContext.delete(model: BookVariant.self)
        try? modelContext.save()
        // Reclaim the on-disk blobs (covers, variant text, images, originals)
        // so they don't leak across resets.
        BookStore.shared.deleteAllBookFiles()
        // The loader owns its own key — see SummaryPackLoader.resetSeedFlag.
        SummaryPackLoader.resetSeedFlag()
        resetDone = true
    }

    private func runOnDeviceTest() async {
        testingOnDevice = true
        defer { testingOnDevice = false }
        let provider = LocalProvider()
        let result = await provider.ping()
        onDeviceTestResult = result
        // Refresh status in case availability flipped (e.g. model just finished downloading).
        onDeviceStatus = await provider.availabilityReport()
    }

    @MainActor
    private func recomputeSpend() {
        let descriptor = FetchDescriptor<BookVariant>()
        let variants = (try? modelContext.fetch(descriptor)) ?? []
        let cal = Calendar.current
        let now = Date.now
        monthlySpend = variants
            .filter { cal.isDate($0.generatedAt, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.costUSD }
    }

    private func formatMinutes(_ mins: Int) -> String {
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60
        let m = mins % 60
        return m == 0 ? "\(h) h" : "\(h)h \(m)m"
    }
}
