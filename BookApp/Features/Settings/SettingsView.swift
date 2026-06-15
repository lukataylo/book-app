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

    // Daily Review preferences live on the single StreakState record.
    @State private var streak: StreakState?
    @State private var confirmReset = false
    @State private var resetDone = false

    private static let privacyPolicyURL = URL(string: "https://lukataylo.github.io/book-app/privacy")
    private static let supportURL = URL(string: "mailto:luka.dadiani@me.com")

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

                if let streak {
                    @Bindable var streak = streak
                    Section("Daily Review") {
                        Stepper(value: $streak.dailyLimit, in: 5...50, step: 5) {
                            HStack {
                                Text("Cards per day")
                                Spacer()
                                Text("\(streak.dailyLimit)").foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                        .onChange(of: streak.dailyLimit) { save() }

                        Toggle("Daily reminder", isOn: Binding(
                            get: { streak.remindersEnabled },
                            set: { on in
                                streak.remindersEnabled = on
                                save()
                                Task { await applyReminder(enabled: on, minute: streak.reminderMinuteOfDay) }
                            }
                        ))

                        if streak.remindersEnabled {
                            DatePicker(
                                "Time",
                                selection: Binding(
                                    get: { dateFromMinute(streak.reminderMinuteOfDay) },
                                    set: { newDate in
                                        streak.reminderMinuteOfDay = minuteFromDate(newDate)
                                        save()
                                        NotificationScheduler.scheduleDailyReview(minuteOfDay: streak.reminderMinuteOfDay)
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                        Text("One gentle nudge a day when cards are due. No account, no server; scheduled on this device.")
                            .font(.caption)
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
                    Text("On-device handles short tasks (auto-categorisation, brief learnings). Whole-book compression and re-style need a Claude API key; the on-device context window is too small.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    Text("Cloud transformations send the source book to Anthropic for that request only. Local transformations stay on-device. The first cloud run asks your permission before any text leaves your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Diagnostics") {
                    DiagnosticsRow()
                }

                Section("Data") {
                    Button("Reset all content", role: .destructive) {
                        confirmReset = true
                    }
                    Text("Deletes every book, card, highlight, and review from this device. The starter library reloads next launch.")
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
                recomputeSpend()
                hasKey = KeychainStore.shared.read(.anthropicAPIKey) != nil
                streak = MemoryStore(context: modelContext).streakState()
            }
            .task {
                onDeviceStatus = await LocalProvider().availabilityReport()
                // If the user revoked notifications in iOS Settings, the
                // toggle would otherwise still read ON — reconcile it.
                if let streak, streak.remindersEnabled {
                    let status = await NotificationScheduler.authorizationStatus()
                    if status == .denied {
                        streak.remindersEnabled = false
                        save()
                    }
                }
            }
            .alert("Reset all content?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { resetAllContent() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your books, saved cards, highlights, and review history on this device.")
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

    private func save() { try? modelContext.save() }

    private func dateFromMinute(_ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
    }

    private func minuteFromDate(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 9) * 60 + (c.minute ?? 0)
    }

    private func applyReminder(enabled: Bool, minute: Int) async {
        if enabled {
            let granted = await NotificationScheduler.requestAuthorization()
            if granted {
                NotificationScheduler.scheduleDailyReview(minuteOfDay: minute)
            } else if let streak {
                // Permission denied — reflect reality in the toggle.
                streak.remindersEnabled = false
                save()
            }
        } else {
            NotificationScheduler.cancelDailyReview()
        }
    }

    /// Delete all user + catalog content and clear the seed flags so the
    /// starter library re-seeds on the next launch.
    private func resetAllContent() {
        try? modelContext.delete(model: Book.self)
        try? modelContext.delete(model: KnowledgeCard.self)
        try? modelContext.delete(model: KeyLearning.self)
        try? modelContext.delete(model: ActionItem.self)
        try? modelContext.delete(model: Annotation.self)
        try? modelContext.delete(model: Bookmark.self)
        try? modelContext.delete(model: ReadingProgress.self)
        try? modelContext.delete(model: BookVariant.self)
        try? modelContext.delete(model: ReviewSession.self)
        try? modelContext.delete(model: ReviewLog.self)
        try? modelContext.delete(model: StreakState.self)
        try? modelContext.save()
        // Reclaim the on-disk blobs (covers, variant text, images, originals)
        // so they don't leak across resets.
        BookStore.shared.deleteAllBookFiles()
        for key in ["SummaryPacks.loadedSlugs-v2", "SeedBooks.completed-v1",
                    "Annotations.backfill-v1", "CoverArt.seedBackfill-v1"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        NotificationScheduler.cancelDailyReview()
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
