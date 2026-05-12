import Foundation
import SwiftData

@Model
final class TTSSettings {
    var id: UUID = UUID()
    var voiceIdentifier: String = ""
    var rate: Double = 0.5
    var pitch: Double = 1.0
    var volume: Double = 1.0
    var highlightColorHex: String = "#FFE082"
    var autoPageFlip: Bool = true
    var pauseAtPunctuation: Bool = false
    var sleepTimerMinutes: Int = 0
    /// When true (default), TTS ducks other audio and stays out of the
    /// lock-screen now-playing card — convenient when you want to keep
    /// a podcast/music quietly running underneath. Turn it off to make
    /// TTS the primary audio source: other audio pauses, and the
    /// lock-screen mini-player shows the book cover + play/skip controls.
    var mixWithOtherAudio: Bool = true

    init(id: UUID = UUID()) {
        self.id = id
    }
}
