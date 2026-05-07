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
    /// Identifies the content currently loaded into the engine so callers
    /// can detect "Listen tab tapped on a different book than the one we
    /// were narrating". Without this, `togglePlayback` would resume the
    /// previous book's paragraphs at the previous index — confusing at
    /// best, and crash-prone when the old `currentParagraph` no longer
    /// exists in the new content.
    private var loadedKey: String?
    // Now-playing metadata for lock-screen / control-centre.
    private var nowPlayingTitle: String = "BookApp"
    private var nowPlayingAuthor: String = ""
    private var nowPlayingCoverData: Data?

    // Resume-after-relaunch persistence keys.
    private let resumeBookKey      = "TTS.resumeBookID"
    private let resumeVariantKey   = "TTS.resumeVariantID"
    private let resumeParagraphKey = "TTS.resumeParagraph"
    private let resumeTimeKey      = "TTS.resumeTimestamp"

    override init() {
        super.init()
        synth.delegate = self
        configureRemoteControls()
        configureAudioInterruptionHandling()
        configureRouteChangeHandling()
        // Audio session is configured + activated lazily on first play —
        // doing it at init() can race with app launch and silently fail.
    }

    func configure(settings: TTSSettings) {
        self.settings = settings
    }

    /// Optional metadata for the lock-screen / control-centre card. Caller
    /// passes the book's cover/title/author when starting playback so iOS
    /// shows real artwork instead of a generic title.
    func configureNowPlaying(title: String, author: String, coverData: Data?) {
        self.nowPlayingTitle = title
        self.nowPlayingAuthor = author
        self.nowPlayingCoverData = coverData
    }

    var hasLoadedContent: Bool { !paragraphs.isEmpty }

    /// True iff the engine's currently-loaded paragraphs come from the
    /// given book + variant. The reader uses this when the user taps the
    /// Listen tab to decide whether to keep narrating what's already
    /// playing or restart with the visible book's content.
    func isLoadedFor(bookID: UUID, variantID: UUID) -> Bool {
        loadedKey == "\(bookID.uuidString)/\(variantID.uuidString)"
    }

    /// Live rate (0.0…1.0 in AVSpeech units). Reading-app UI usually maps
    /// this onto "1×" / "1.5×" labels.
    var currentRate: Double { settings.rate }

    /// Single entry-point for the reader's Listen button. Pass the book +
    /// variant ID so the engine can tell whether the caller is asking it
    /// to toggle the *current* narration or start one for fresh content
    /// (e.g. user opened a different book and tapped Listen).
    func togglePlayback(bookID: UUID, variantID: UUID, paragraphs rawParagraphs: [String]) {
        let key = "\(bookID.uuidString)/\(variantID.uuidString)"
        if loadedKey != nil, loadedKey != key {
            // Switching content — stop the old utterance before loading
            // the new one. Not stopping first means `synth.speak` runs
            // while a previous utterance is still being cancelled, which
            // is the iOS 18 race that surfaces as a hard crash inside
            // AVSpeechSynthesizer.
            stop()
            play(bookID: bookID, variantID: variantID, paragraphs: rawParagraphs)
            return
        }
        if isPlaying {
            pause()
        } else if hasLoadedContent {
            resume()
        } else {
            play(bookID: bookID, variantID: variantID, paragraphs: rawParagraphs)
        }
    }

    func play(bookID: UUID, variantID: UUID, paragraphs rawParagraphs: [String], startAt index: Int = 0) {
        let cleaned = rawParagraphs
            .map { Self.stripHeadingMarker($0) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .filter { !($0.hasPrefix("[img:") && $0.hasSuffix("]")) }
        guard !cleaned.isEmpty else {
            lastError = "Nothing to read in this section."
            return
        }
        // Drain the synth before starting fresh — protects against a
        // pending speak/stop cycle from the previous book.
        synth.stopSpeaking(at: .immediate)
        self.paragraphs = cleaned
        self.currentParagraph = max(0, min(index, cleaned.count - 1))
        self.loadedKey = "\(bookID.uuidString)/\(variantID.uuidString)"
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
        currentText = ""
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
        notifyParagraphChanged()
    }

    /// Hook fired whenever `currentParagraph` advances. Subscribers can
    /// persist resume state from outside the engine without having to
    /// poll on a timer.
    var onParagraphChange: (@MainActor (Int) -> Void)?

    private func notifyParagraphChanged() {
        if let hook = onParagraphChange {
            Task { @MainActor in hook(currentParagraph) }
        }
    }

    func skipBackward() {
        // First tap restarts the current paragraph. Second tap (within ~2s
        // back at the start) jumps to the previous paragraph. Mirrors the
        // way music players treat the back button.
        if currentRange.location < 6 && currentParagraph > 0 {
            synth.stopSpeaking(at: .immediate)
            currentParagraph -= 1
            speakCurrent()
            notifyParagraphChanged()
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
        persistSettingsChange()
    }

    /// Mini-player rate / pitch / voice tweaks update the live `settings`
    /// instance but were never written back to SwiftData — a force-quit
    /// would lose the change. Push the model context to save (best
    /// effort; the settings row is a singleton so we don't need to
    /// re-resolve it).
    private func persistSettingsChange() {
        let ctx = settings.modelContext
        Task { @MainActor in
            try? ctx?.save()
        }
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
        guard let text = paragraphs[safe: currentParagraph] else {
            isPlaying = false
            updateNowPlaying()
            return
        }
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
            //
            // Options note: `.duckOthers` + `.interruptSpokenAudioAndMixWithOthers`
            // are mutually exclusive — passing both threw on iOS 18 and
            // crashed Listen on first tap. `.duckOthers` alone is the
            // right behaviour for narration over background music.
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers]
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

    /// Subscribe to system audio-interruption events (incoming phone call,
    /// Siri, FaceTime, another app starting playback). Without this the
    /// synth keeps "speaking" silently while the system has taken away
    /// our audio focus, and on resume the user sees a paused state with
    /// no obvious way back to where they were.
    private func configureAudioInterruptionHandling() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            // Extract the Sendable primitives from `note.userInfo` *outside*
            // the Task — `[AnyHashable: Any]` isn't Sendable, so capturing
            // it across an actor hop trips Swift 6's strict-concurrency
            // checker and refuses to compile.
            guard let info = note.userInfo,
                  let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            let optsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                switch type {
                case .began:
                    if self.isPlaying { self.pause() }
                case .ended:
                    let opts = optsRaw.map {
                        AVAudioSession.InterruptionOptions(rawValue: $0)
                    } ?? []
                    if opts.contains(.shouldResume), self.hasLoadedContent {
                        self.resume()
                    }
                @unknown default:
                    break
                }
            }
        }
        #endif
    }

    /// Pause when a route change indicates the previous output went away
    /// (AirPods unplugged, Bluetooth speaker disconnected). Apple's HIG
    /// requires this — `routeChangeReason` `.oldDeviceUnavailable` should
    /// stop playback so audio doesn't suddenly blast out of the iPhone
    /// speaker into the user's pocket.
    private func configureRouteChangeHandling() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            guard let info = note.userInfo,
                  let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
            guard reason == .oldDeviceUnavailable else { return }
            Task { @MainActor in
                if self.isPlaying { self.pause() }
            }
        }
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
            MPMediaItemPropertyTitle: nowPlayingTitle,
            MPMediaItemPropertyArtist: nowPlayingAuthor.isEmpty ? "BookApp" : nowPlayingAuthor,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        #if canImport(UIKit)
        // Defensive: malformed cover data or zero-size images would crash
        // `MPMediaItemArtwork(boundsSize:)`. Skip artwork in those cases —
        // Listen still works, the lock-screen just falls back to the
        // generic icon.
        if let data = nowPlayingCoverData,
           let image = UIImage(data: data),
           image.size.width > 0,
           image.size.height > 0 {
            let art = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = art
        }
        #endif
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Resume persistence

    /// Snapshot the currently-playing position to UserDefaults so a future
    /// app launch can offer "Resume listening". Called whenever paragraph
    /// changes during playback.
    func persistResumePoint(bookID: UUID, variantID: UUID?) {
        let defaults = UserDefaults.standard
        defaults.set(bookID.uuidString, forKey: resumeBookKey)
        defaults.set(variantID?.uuidString, forKey: resumeVariantKey)
        defaults.set(currentParagraph, forKey: resumeParagraphKey)
        defaults.set(Date.now.timeIntervalSince1970, forKey: resumeTimeKey)
    }

    /// Last-saved resume point, if any. Older than 7 days is ignored
    /// (avoid offering "Resume" for a session you started a month ago).
    static func resumePoint() -> ResumePoint? {
        let defaults = UserDefaults.standard
        guard let bookString = defaults.string(forKey: "TTS.resumeBookID"),
              let bookID = UUID(uuidString: bookString) else { return nil }
        let ts = defaults.double(forKey: "TTS.resumeTimestamp")
        let variant = defaults.string(forKey: "TTS.resumeVariantID").flatMap(UUID.init)
        let para = defaults.integer(forKey: "TTS.resumeParagraph")
        let age = Date.now.timeIntervalSince1970 - ts
        guard age >= 0, age < 7 * 24 * 60 * 60 else { return nil }
        return ResumePoint(bookID: bookID, variantID: variant, paragraph: para)
    }

    static func clearResumePoint() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "TTS.resumeBookID")
        defaults.removeObject(forKey: "TTS.resumeVariantID")
        defaults.removeObject(forKey: "TTS.resumeParagraph")
        defaults.removeObject(forKey: "TTS.resumeTimestamp")
    }

    struct ResumePoint: Sendable {
        let bookID: UUID
        let variantID: UUID?
        let paragraph: Int
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
