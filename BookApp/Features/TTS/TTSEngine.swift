import Foundation
import AVFoundation
import Observation
import MediaPlayer

#if canImport(UIKit)
import UIKit
#endif

/// Wraps `AVSpeechSynthesizer` for the reader.
///
/// Responsibilities:
///   - Activate the audio session before each playback start (not just at
///     init), so the very first tap of Listen actually produces sound even
///     when the session hasn't been touched yet.
///   - Strip `# Heading` markers from spoken text — the synthesizer would
///     otherwise read out "hash chapter VII…".
///   - Robust voice resolution: saved-id → currentLanguageCode → any
///     English voice → first installed voice. Empty `voiceIdentifier` is
///     no longer fatal.
///   - Skip empty paragraphs automatically so an empty `\n\n` block doesn't
///     silently fast-forward the queue.
///   - Live rate / pitch / voice changes — the active utterance restarts
///     from the start of its paragraph at the new setting so the user
///     hears the change immediately.
///   - `restartCurrentParagraph()` for the "rewind" button.
///
/// Lock-screen + remote command center integration (`MPNowPlayingInfoCenter`)
/// keeps play/pause/skip working when the app is backgrounded.
@Observable
@MainActor
final class TTSEngine: NSObject {
    static let shared = TTSEngine()

    var isPlaying: Bool = false
    var currentParagraph: Int = 0
    var currentRange: NSRange = NSRange(location: 0, length: 0)
    var currentText: String = ""
    var sleepFiresAt: Date?
    /// Surface the most recent failure so callers can show a helpful toast
    /// instead of the user staring at silent buttons.
    var lastError: String?

    private let synth = AVSpeechSynthesizer()
    private var paragraphs: [String] = []   // already cleaned of `# ` markers
    private var settings: TTSSettings = TTSSettings()
    private var sleepTimer: Timer?

    override init() {
        super.init()
        synth.delegate = self
        configureRemoteControls()
        // Audio session is configured + activated lazily on first play —
        // doing it at init() can race with app launch and silently fail.
    }

    func configure(settings: TTSSettings) {
        self.settings = settings
    }

    var hasLoadedContent: Bool { !paragraphs.isEmpty }

    /// Live rate (0.0…1.0 in AVSpeech units). Reading-app UI usually maps
    /// this onto "1×" / "1.5×" labels.
    var currentRate: Double { settings.rate }

    /// Single entry-point for the reader's Listen button.
    func togglePlayback(paragraphs rawParagraphs: [String]) {
        if isPlaying {
            pause()
        } else if hasLoadedContent {
            resume()
        } else {
            play(paragraphs: rawParagraphs)
        }
    }

    func play(paragraphs rawParagraphs: [String], startAt index: Int = 0) {
        let cleaned = rawParagraphs
            .map { Self.stripHeadingMarker($0) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !cleaned.isEmpty else {
            lastError = "Nothing to read in this section."
            return
        }
        self.paragraphs = cleaned
        self.currentParagraph = max(0, min(index, cleaned.count - 1))
        activateAudioSession()
        speakCurrent()
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        synth.pauseSpeaking(at: .word)
        isPlaying = false
        updateNowPlaying()
    }

    func resume() {
        // If the synth is paused mid-utterance just continue. Otherwise
        // re-speak the current paragraph from the top.
        activateAudioSession()
        if synth.isPaused {
            synth.continueSpeaking()
        } else {
            speakCurrent()
        }
        isPlaying = true
        updateNowPlaying()
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        isPlaying = false
        currentRange = NSRange(location: 0, length: 0)
        sleepTimer?.invalidate()
        sleepFiresAt = nil
        deactivateAudioSession()
    }

    /// Restart the paragraph that's currently playing (or queued) from the
    /// top — wired to a "rewind" / restart button in the mini-player.
    func restartCurrentParagraph() {
        synth.stopSpeaking(at: .immediate)
        speakCurrent()
        isPlaying = true
        updateNowPlaying()
    }

    func skipForward() {
        guard currentParagraph + 1 < paragraphs.count else { stop(); return }
        synth.stopSpeaking(at: .immediate)
        currentParagraph += 1
        speakCurrent()
    }

    func skipBackward() {
        // First tap restarts the current paragraph. Second tap (within ~2s
        // back at the start) jumps to the previous paragraph. Mirrors the
        // way music players treat the back button.
        if currentRange.location < 6 && currentParagraph > 0 {
            synth.stopSpeaking(at: .immediate)
            currentParagraph -= 1
            speakCurrent()
        } else {
            restartCurrentParagraph()
        }
    }

    /// Apply a new rate / pitch / voice immediately by stopping the current
    /// utterance and re-speaking from the top of the current paragraph.
    func applyLiveSettingChange() {
        guard isPlaying else { return }
        synth.stopSpeaking(at: .immediate)
        speakCurrent()
    }

    /// Cycles through 0.4 → 0.5 → 0.6 → 0.7 → 0.4 … so a single tap on the
    /// rate badge in the mini-player feels obvious.
    func cycleRate() {
        let preset: Float = Float(settings.rate)
        let next: Float
        switch preset {
        case ..<0.45: next = 0.5
        case ..<0.55: next = 0.6
        case ..<0.65: next = 0.7
        default:      next = 0.4
        }
        settings.rate = Double(next)
        applyLiveSettingChange()
    }

    func startSleepTimer(minutes: Int) {
        sleepTimer?.invalidate()
        guard minutes > 0 else { sleepFiresAt = nil; return }
        sleepFiresAt = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
    }

    /// All speech voices grouped by language, sorted by quality (premium
    /// first) then by name. Used by the voice picker.
    static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().sorted {
            if $0.language != $1.language { return $0.language < $1.language }
            if $0.quality != $1.quality   { return $0.quality.rawValue > $1.quality.rawValue }
            return $0.name < $1.name
        }
    }

    /// Pretty label for a voice — "Samantha (Enhanced) · en-US".
    static func label(for voice: AVSpeechSynthesisVoice) -> String {
        let q: String
        switch voice.quality {
        case .premium: q = " · Premium"
        case .enhanced: q = " · Enhanced"
        default: q = ""
        }
        return "\(voice.name)\(q) · \(voice.language)"
    }

    // MARK: - Private

    private static func stripHeadingMarker(_ text: String) -> String {
        text.hasPrefix("# ") ? String(text.dropFirst(2)) : text
    }

    private func speakCurrent() {
        guard currentParagraph < paragraphs.count else {
            isPlaying = false
            updateNowPlaying()
            return
        }
        let text = paragraphs[currentParagraph]
        currentText = text
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = clampedRate(settings.rate)
        utterance.pitchMultiplier = Float(max(0.5, min(2.0, settings.pitch)))
        utterance.volume = Float(max(0.0, min(1.0, settings.volume)))
        utterance.voice = resolvedVoice()
        if settings.pauseAtPunctuation {
            utterance.preUtteranceDelay = 0
            utterance.postUtteranceDelay = 0.15
        }
        synth.speak(utterance)
    }

    private func clampedRate(_ raw: Double) -> Float {
        let v = Float(raw)
        return min(max(v, AVSpeechUtteranceMinimumSpeechRate),
                   AVSpeechUtteranceMaximumSpeechRate)
    }

    private func resolvedVoice() -> AVSpeechSynthesisVoice? {
        if !settings.voiceIdentifier.isEmpty,
           let v = AVSpeechSynthesisVoice(identifier: settings.voiceIdentifier) {
            return v
        }
        if let v = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode()) {
            return v
        }
        if let english = AVSpeechSynthesisVoice.speechVoices()
            .first(where: { $0.language.hasPrefix("en") }) {
            return english
        }
        return AVSpeechSynthesisVoice.speechVoices().first
    }

    private func activateAudioSession() {
        #if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        do {
            // `.playback` overrides silent-mode so the user actually hears
            // narration. `.spokenAudio` mode triggers the right ducking
            // behaviour against music apps.
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
            lastError = nil
        } catch {
            lastError = "Audio unavailable: \(error.localizedDescription)"
        }
        #endif
    }

    private func deactivateAudioSession() {
        #if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }

    private func configureRemoteControls() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipForward() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipBackward() }
            return .success
        }
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentText.prefix(80).description,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        info[MPMediaItemPropertyArtist] = "BookApp"
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

extension TTSEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.currentRange = characterRange
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // didFinish fires for empty/cancelled utterances too — only
            // advance if the user is still in playing mode (manual stops
            // already updated state).
            guard self.isPlaying else { return }
            self.skipForward()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        // Do nothing — caller has already set new state.
    }
}
