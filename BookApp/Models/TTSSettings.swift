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

    init(id: UUID = UUID()) {
        self.id = id
    }
}
