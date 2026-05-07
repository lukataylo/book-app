import SwiftUI
import SwiftData
import AVFoundation

/// TTS controls — opens from the reader's voice button. Voice picker,
/// rate / pitch, highlight colour, sleep timer, and play controls.
///
/// Voices are loaded asynchronously and cached: `AVSpeechSynthesisVoice
/// .speechVoices()` walks the system's installed-voices catalogue
/// synchronously, which iOS 18 has been known to either hang on
/// (speech daemon busy / mid-download) or crash through with a
/// daemon-disconnect trap. Calling it from `body` while the sheet
/// presents was a reproducible "click TTS, app crashes" path. Loading
/// off the main actor and capping the list at 80 entries (sorted by
/// quality so Premium / Enhanced come first) keeps the picker
/// responsive without losing the useful voices.
struct TTSSettingsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var settings: TTSSettings?
    @State private var engine = TTSEngine.shared
    @State private var voices: [VoiceDescriptor] = []
    @State private var voicesLoaded: Bool = false
    @State private var persistTask: Task<Void, Never>?

    private struct VoiceDescriptor: Identifiable, Hashable, Sendable {
        let id: String         // identifier
        let name: String
        let language: String
        let qualityLabel: String
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Listen")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .task { await loadEverything() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let settings {
            Form {
                voiceSection(settings: settings)
                speedSection(settings: settings)
                highlightSection(settings: settings)
                sleepSection(settings: settings)
                playbackSection
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func voiceSection(settings: TTSSettings) -> some View {
        Section("Voice") {
            Picker("Voice", selection: Binding(
                get: { settings.voiceIdentifier },
                set: { settings.voiceIdentifier = $0; persist() }
            )) {
                Text("Default for language").tag("")
                if !voicesLoaded {
                    Text("Loading voices…").tag("__loading__")
                } else {
                    ForEach(voices) { voice in
                        Text("\(voice.name) — \(voice.language) — \(voice.qualityLabel)")
                            .tag(voice.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func speedSection(settings: TTSSettings) -> some View {
        Section("Speed") {
            HStack {
                Text("Rate")
                let rateMin = Double(AVSpeechUtteranceMinimumSpeechRate)
                let rateMax = Double(AVSpeechUtteranceMaximumSpeechRate)
                Slider(
                    value: Binding(
                        get: { settings.rate },
                        set: { settings.rate = $0; persist() }
                    ),
                    in: rateMin...rateMax
                )
                Text(String(format: "%.2f", settings.rate))
                    .monospacedDigit()
            }
            HStack {
                Text("Pitch")
                Slider(
                    value: Binding(
                        get: { settings.pitch },
                        set: { settings.pitch = $0; persist() }
                    ),
                    in: 0.5...2.0
                )
                Text(String(format: "%.2f", settings.pitch))
                    .monospacedDigit()
            }
            Toggle("Pause at punctuation", isOn: Binding(
                get: { settings.pauseAtPunctuation },
                set: { settings.pauseAtPunctuation = $0; persist() }
            ))
        }
    }

    @ViewBuilder
    private func highlightSection(settings: TTSSettings) -> some View {
        Section("Highlight") {
            HighlightColorPicker(hex: Binding(
                get: { settings.highlightColorHex },
                set: { settings.highlightColorHex = $0; persist() }
            ))
            Toggle("Auto-flip page", isOn: Binding(
                get: { settings.autoPageFlip },
                set: { settings.autoPageFlip = $0; persist() }
            ))
        }
    }

    @ViewBuilder
    private func sleepSection(settings: TTSSettings) -> some View {
        Section("Sleep timer") {
            Picker("Stop after", selection: Binding(
                get: { settings.sleepTimerMinutes },
                set: { settings.sleepTimerMinutes = $0; persist() }
            )) {
                Text("Off").tag(0)
                Text("5 min").tag(5)
                Text("15 min").tag(15)
                Text("30 min").tag(30)
                Text("1 hour").tag(60)
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.sleepTimerMinutes) { _, m in
                engine.startSleepTimer(minutes: m)
            }
        }
    }

    @ViewBuilder
    private var playbackSection: some View {
        Section {
            HStack {
                Spacer()
                Button {
                    engine.isPlaying ? engine.pause() : engine.resume()
                } label: {
                    Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.Palette.accent)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
    }

    // MARK: - Async load

    /// Resolve settings + voice catalogue without blocking the open
    /// animation. Settings are cheap (SwiftData fetch on the main actor);
    /// the voice list is the slow part — we walk it on a detached task
    /// because `AVSpeechSynthesisVoice.speechVoices()` does a synchronous
    /// hop into the system speech daemon and can stall the main runloop
    /// for hundreds of milliseconds on iOS 18.
    private func loadEverything() async {
        let resolved = SettingsStore.shared.tts(in: modelContext)
        settings = resolved
        engine.configure(settings: resolved)

        let descriptors: [VoiceDescriptor] = await Task.detached(priority: .userInitiated) {
            let raw = AVSpeechSynthesisVoice.speechVoices()
            // Sort: Premium > Enhanced > Standard, then by language, then name.
            let sorted = raw.sorted {
                if $0.quality != $1.quality {
                    return $0.quality.rawValue > $1.quality.rawValue
                }
                if $0.language != $1.language { return $0.language < $1.language }
                return $0.name < $1.name
            }
            return sorted.prefix(80).map {
                VoiceDescriptor(
                    id: $0.identifier,
                    name: $0.name,
                    language: $0.language,
                    qualityLabel: Self.qualityLabel($0.quality)
                )
            }
        }.value

        voices = descriptors
        voicesLoaded = true
    }

    private func persist() {
        guard let settings else { return }
        engine.configure(settings: settings)
        // Pickers / steppers in this sheet fire many times per gesture.
        // Coalesce the SwiftData save so we don't block the main thread
        // on CloudKit sync mid-drag.
        persistTask?.cancel()
        persistTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            try? modelContext.save()
        }
    }

    private static func qualityLabel(_ q: AVSpeechSynthesisVoiceQuality) -> String {
        switch q {
        case .default:  return "Standard"
        case .enhanced: return "Enhanced"
        case .premium:  return "Premium"
        @unknown default: return "—"
        }
    }
}

private struct HighlightColorPicker: View {
    @Binding var hex: String

    private let palette = ["#FFE082", "#FFAB91", "#A5D6A7", "#90CAF9", "#CE93D8"]

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(palette, id: \.self) { p in
                Circle()
                    .fill(Color(hex: p))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(p == hex ? 1 : 0), lineWidth: 2)
                    )
                    .onTapGesture { hex = p }
            }
        }
    }
}
