import Foundation
import AVFoundation
import Observation
import MediaPlayer

#if canImport(UIKit)
import UIKit
#endif

/// Wraps `AVSpeechSynthesizer` and exposes the spoken word range to the UI
/// so the reader/speed-reader can highlight the current word in real time.
///
/// Lock-screen + remote command center integration (`MPNowPlayingInfoCenter`)
/// makes the play/pause/skip buttons in CarPlay and on the lock screen work
/// while the app is backgrounded. Background audio capability is enabled in
/// Info.plist (`audio` background mode).
@Observable
@MainActor
final class TTSEngine: NSObject {
    static let shared = TTSEngine()

    var isPlaying: Bool = false
    var currentParagraph: Int = 0
    var currentRange: NSRange = NSRange(location: 0, length: 0)
    var currentText: String = ""
    var sleepFiresAt: Date?

    private let synth = AVSpeechSynthesizer()
    private var paragraphs: [String] = []
    private var settings: TTSSettings = TTSSettings()
    private var sleepTimer: Timer?

    override init() {
        super.init()
        synth.delegate = self
        configureAudioSession()
        configureRemoteControls()
    }

    func configure(settings: TTSSettings) {
        self.settings = settings
    }

    /// Whether playback can be resumed without restarting from the top.
    var hasLoadedContent: Bool { !paragraphs.isEmpty }

    /// Single entry-point used by the reader's Listen button: pause if
    /// playing, resume if paused on something we already loaded, or kick
    /// off a fresh play with the given paragraphs.
    func togglePlayback(paragraphs: [String]) {
        if isPlaying {
            pause()
        } else if hasLoadedContent {
            resume()
        } else {
            play(paragraphs: paragraphs)
        }
    }

    func play(paragraphs: [String], startAt index: Int = 0) {
        self.paragraphs = paragraphs
        self.currentParagraph = max(0, min(index, paragraphs.count - 1))
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
        if synth.isPaused { synth.continueSpeaking() } else { speakCurrent() }
        isPlaying = true
        updateNowPlaying()
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        isPlaying = false
        currentRange = NSRange(location: 0, length: 0)
        sleepTimer?.invalidate()
        sleepFiresAt = nil
    }

    func skipForward() {
        guard currentParagraph + 1 < paragraphs.count else { stop(); return }
        synth.stopSpeaking(at: .immediate)
        currentParagraph += 1
        speakCurrent()
    }

    func skipBackward() {
        guard currentParagraph > 0 else { return }
        synth.stopSpeaking(at: .immediate)
        currentParagraph -= 1
        speakCurrent()
    }

    func startSleepTimer(minutes: Int) {
        sleepTimer?.invalidate()
        guard minutes > 0 else { sleepFiresAt = nil; return }
        sleepFiresAt = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
    }

    static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().sorted { $0.name < $1.name }
    }

    // MARK: - Private

    private func speakCurrent() {
        guard currentParagraph < paragraphs.count else {
            isPlaying = false
            return
        }
        let text = paragraphs[currentParagraph]
        currentText = text
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = Float(settings.rate)
        utterance.pitchMultiplier = Float(settings.pitch)
        utterance.volume = Float(settings.volume)
        if !settings.voiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: settings.voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        }
        if settings.pauseAtPunctuation {
            utterance.preUtteranceDelay = 0
            utterance.postUtteranceDelay = 0.15
        }
        synth.speak(utterance)
    }

    private func configureAudioSession() {
        #if canImport(UIKit)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Non-fatal: TTS still plays, lock-screen integration may be limited.
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
            self.skipForward()
        }
    }
}
