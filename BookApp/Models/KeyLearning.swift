import Foundation
import SwiftData

@Model
final class KeyLearning {
    var id: UUID = UUID()
    var book: Book?
    var text: String = ""
    var chapterRef: String = ""
    var locator: String = ""
    var starred: Bool = false
    var userEdited: Bool = false
    var createdAt: Date = Date.now
    var tags: [String] = []

    init(
        id: UUID = UUID(),
        book: Book? = nil,
        text: String,
        chapterRef: String = "",
        locator: String = "",
        starred: Bool = false,
        userEdited: Bool = false
    ) {
        self.id = id
        self.book = book
        self.text = text
        self.chapterRef = chapterRef
        self.locator = locator
        self.starred = starred
        self.userEdited = userEdited
        self.createdAt = .now
    }
}
