import SwiftUI
import SwiftData
import AVFoundation

/// TTS controls — the "Listen" sheet from the reader's bottom bar. Voice
/// picker, rate / pitch, highlight color, sleep timer, and play controls.
struct TTSSettingsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var settings = TTSSettings()
    @State private var engine = TTSEngine.shared
    @State private var persistTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section("Voice") {
                    Picker("Voice", selection: Binding(
                        get: { settings.voiceIdentifier },
                        set: { settings.voiceIdentifier = $0; persist() }
                    )) {
                        Text("Default for language").tag("")
                        ForEach(TTSEngine.availableVoices, id: \.identifier) { voice in
                            Text("\(voice.name) — \(voice.language) — \(qualityLabel(voice.quality))")
                                .tag(voice.identifier)
                        }
                    }
                }

                Section("Speed") {
                    HStack {
                        Text("Rate")
                        Slider(
                            value: Binding(
                                get: { settings.rate },
                                set: { settings.rate = $0; persist() }
                            ),
                            in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate)
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
            .navigationTitle("Listen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                load()
                engine.configure(settings: settings)
            }
        }
    }

    private func load() {
        settings = SettingsStore.shared.tts(in: modelContext)
    }

    private func persist() {
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

    private func qualityLabel(_ q: AVSpeechSynthesisVoiceQuality) -> String {
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
