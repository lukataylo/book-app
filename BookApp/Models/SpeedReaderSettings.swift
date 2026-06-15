import Foundation
import SwiftData

@Model
final class SpeedReaderSettings {
    var id: UUID = UUID()
    var wpm: Int = 350
    var pauseAtPunctuation: Bool = true
    var commaPauseMS: Int = 100
    var periodPauseMS: Int = 250

    init(id: UUID = UUID()) {
        self.id = id
    }
}
