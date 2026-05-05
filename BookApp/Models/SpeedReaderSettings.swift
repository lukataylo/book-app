import Foundation
import SwiftData

enum SpeedReaderMode: String, Codable, CaseIterable, Sendable {
    case paragraphAndWord
    case wordFocus
    case rsvp

    var displayName: String {
        switch self {
        case .paragraphAndWord: return "Paragraph + Word"
        case .wordFocus:        return "Word Focus"
        case .rsvp:             return "RSVP"
        }
    }
}

@Model
final class SpeedReaderSettings {
    var id: UUID = UUID()
    var modeRaw: String = SpeedReaderMode.paragraphAndWord.rawValue
    var wpm: Int = 350
    var focusPoint: Double = 0.35
    var pauseAtPunctuation: Bool = true
    var commaPauseMS: Int = 100
    var periodPauseMS: Int = 250
    var paragraphPauseMS: Int = 400
    var chunkSize: Int = 1
    var highlightColorHex: String = "#FFE082"

    init(id: UUID = UUID()) {
        self.id = id
    }

    var mode: SpeedReaderMode {
        get { SpeedReaderMode(rawValue: modeRaw) ?? .paragraphAndWord }
        set { modeRaw = newValue.rawValue }
    }
}
