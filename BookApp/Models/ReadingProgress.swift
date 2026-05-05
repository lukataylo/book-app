import Foundation
import SwiftData

@Model
final class ReadingProgress {
    var id: UUID = UUID()
    var book: Book?
    var variantID: UUID?
    var locator: String = ""
    var percent: Double = 0
    var currentPage: Int = 0
    var totalPages: Int = 0
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        book: Book? = nil,
        variantID: UUID? = nil,
        locator: String = "",
        percent: Double = 0,
        currentPage: Int = 0,
        totalPages: Int = 0
    ) {
        self.id = id
        self.book = book
        self.variantID = variantID
        self.locator = locator
        self.percent = percent
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.updatedAt = .now
    }
}
