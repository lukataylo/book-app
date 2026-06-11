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

    // Memory reminders (spec §3d). Backed by the single StreakState record,
    // which we lazily create on first appearance if one doesn't exist.
    @State private var streak: StreakState?
    @State private var remindersEnabled: Bool = false
    @State private var reminderTime: Date = SettingsView.midnight
    @State private var dailyLimit: Int = 20

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

                Section("Memories") {
                    Toggle("Daily reminder", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { _, enabled in
                            handleRemindersToggle(enabled)
                        }
                    if remindersEnabled {
                        DatePicker(
                            "Time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: reminderTime) { _, newValue in
                            streak?.reminderMinuteOfDay = SettingsView.minuteOfDay(from: newValue)
                            persistAndRefresh()
                        }
                    }
                    Stepper(value: $dailyLimit, in: 5...50, step: 1) {
                        HStack {
                            Text("Cards per day")
                            Spacer()
                            Text("\(dailyLimit)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: dailyLimit) { _, newValue in
                        streak?.dailyLimit = newValue
                        persistAndRefresh()
                    }
                    Text("One gentle nudge a day, off until you turn it on. We never count days or push you to keep a streak.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    Text("On-device handles short tasks (auto-categorisation, brief learnings). Whole-book compression and re-style need a Claude API key — the on-device context window is too small.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    Text("Cloud transformations send the source book to Anthropic for the duration of the request. Local transformations stay on-device. The router never silently switches between them — every cloud run requires an explicit confirmation in the Transformation Studio.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Diagnostics") {
                    DiagnosticsRow()
                }

                Section("About") {
                    HStack { Text("Version"); Spacer(); Text("1.0").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                recomputeSpend()
                loadStreakState()
            }
            .task {
                onDeviceStatus = await LocalProvider().availabilityReport()
            }
        }
    }

    // MARK: - Memory reminders

    /// Fetch the single StreakState record (insert if none) and mirror it into
    /// the local @State the controls bind to.
    @MainActor
    private func loadStreakState() {
        let descriptor = FetchDescriptor<StreakState>()
        let existing = (try? modelContext.fetch(descriptor))?.first
        let state: StreakState
        if let existing {
            state = existing
        } else {
            state = StreakState()
            modelContext.insert(state)
            try? modelContext.save()
        }
        streak = state
        remindersEnabled = state.remindersEnabled
        reminderTime = SettingsView.date(fromMinuteOfDay: state.reminderMinuteOfDay)
        dailyLimit = state.dailyLimit
    }

    private func handleRemindersToggle(_ enabled: Bool) {
        guard let streak else { return }
        // Loading the saved state into the toggle can fire this onChange; skip
        // when nothing actually changed so we don't re-request auth on open.
        guard streak.remindersEnabled != enabled else { return }
        streak.remindersEnabled = enabled
        if enabled {
            Task {
                await MemoryReminders.requestAuthorization()
                persistAndRefresh()
            }
        } else {
            persistAndRefresh()
        }
    }

    /// Save the StreakState edits and reschedule the reminder + widget.
    private func persistAndRefresh() {
        guard let streak else { return }
        try? modelContext.save()
        MemoryReminders.refresh(context: modelContext, streak: streak)
    }

    private static let midnight = Calendar.current.startOfDay(for: .now)

    private static func minuteOfDay(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private static func date(fromMinuteOfDay minute: Int) -> Date {
        let clamped = max(0, min(minute, 24 * 60 - 1))
        return Calendar.current.date(
            bySettingHour: clamped / 60,
            minute: clamped % 60,
            second: 0,
            of: .now
        ) ?? midnight
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

/// Lightweight surface for the locally-stored MetricKit payloads — lets
/// the user see whether the app has captured any crashes/hangs and share
/// them out for a bug report. Apple delivers payloads in a daily batch,
/// so an empty list here usually just means "no incidents in the last
/// 24h", not "diagnostics aren't working".
private struct DiagnosticsRow: View {
    @State private var files: [URL] = []
    @State private var shareItem: URL?

    var body: some View {
        Group {
            if files.isEmpty {
                Text("No diagnostics captured. MetricKit reports arrive in a daily batch, so check back tomorrow if the app crashed today.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(files, id: \.self) { url in
                    Button {
                        shareItem = url
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                    .buttonStyle(.plain)
                }
                Button(role: .destructive) {
                    MetricsLog.clearAll()
                    refresh()
                } label: {
                    Label("Clear diagnostics", systemImage: "trash")
                }
            }
        }
        .onAppear { refresh() }
        .sheet(item: $shareItem) { url in
            ShareSheet(items: [url])
        }
    }

    private func refresh() {
        files = MetricsLog.storedFiles()
    }
}

/// Minimal UIActivityViewController bridge — used by DiagnosticsRow to
/// hand a payload file off to Mail / Messages / Files for a bug report.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
