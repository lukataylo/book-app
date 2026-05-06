import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var apiKey: String = ""
    @State private var keySaved: Bool = false
    @State private var monthlySpend: Double = 0
    @State private var onDeviceStatus: String = "Checking…"
    @State private var onDeviceTestResult: String?
    @State private var testingOnDevice: Bool = false
    @StateObject private var stats = ReadingStats.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading") {
                    HStack {
                        Text("Current streak")
                        Spacer()
                        Text(stats.currentStreak == 1 ? "1 day" : "\(stats.currentStreak) days")
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
                    SecureField("Anthropic API key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    HStack {
                        Button("Save key") {
                            KeychainStore.shared.write(.anthropicAPIKey, value: apiKey)
                            keySaved = true
                            apiKey = ""
                        }
                        Spacer()
                        if let _ = KeychainStore.shared.read(.anthropicAPIKey) {
                            Label("Stored in Keychain", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
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
                    Text("On-device handles short tasks (auto-categorisation, brief learnings). Whole-book compression and re-style need a Claude API key — the on-device context window is too small.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    Text("Cloud transformations send the source book to Anthropic for the duration of the request. Local transformations stay on-device. The router never silently switches between them — every cloud run requires an explicit confirmation in the Transformation Studio.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    HStack { Text("Version"); Spacer(); Text("1.0").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Settings")
            .onAppear { recomputeSpend() }
            .task {
                onDeviceStatus = await LocalProvider().availabilityReport()
            }
        }
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
