import Foundation
import Testing
import SwiftData
@testable import BookApp

/// A model that exists only in the "old" schema. Stands in for the five
/// types the App Store scope-down deleted (KnowledgeCard, ActionItem,
/// ReviewSession, ReviewLog, StreakState).
@Model
final class RetiredModel {
    var id: UUID = UUID()
    var note: String = ""
    init(note: String) { self.note = note }
}

/// Opening a store written by an older schema is the upgrade path every
/// existing install takes. These pin down what actually happens, because
/// the app's recovery behaviour depends on it.
@MainActor
struct StoreRecoveryTests {

    private func tempStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "recovery-\(UUID().uuidString).store")
    }

    /// Writes a store containing an entity the current schema doesn't
    /// know about, then reopens it with the production schema.
    @Test
    func storeFromARetiredSchemaStillOpens() throws {
        let url = tempStoreURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let old = Schema([Book.self, BookVariant.self, KeyLearning.self,
                          Annotation.self, ReadingProgress.self, Bookmark.self,
                          ReaderSettings.self, TTSSettings.self,
                          SpeedReaderSettings.self, RetiredModel.self])
        let oldContainer = try ModelContainer(
            for: old,
            configurations: [ModelConfiguration(url: url, cloudKitDatabase: .none)]
        )
        oldContainer.mainContext.insert(Book(title: "Kept", author: "A", format: .unknown))
        oldContainer.mainContext.insert(RetiredModel(note: "goes away"))
        try oldContainer.mainContext.save()

        // Reopen with the shipping schema, which no longer declares
        // RetiredModel. Core Data's lightweight migration drops the table.
        let reopened = try ModelContainer(
            for: ModelContainer.bookAppSchema,
            configurations: [ModelConfiguration(url: url, cloudKitDatabase: .none)]
        )
        let books = try reopened.mainContext.fetch(FetchDescriptor<Book>())
        #expect(books.count == 1, "dropping an entity must not lose the surviving rows")
        #expect(books.first?.title == "Kept")
    }

    /// The production and preview containers must register the same types,
    /// or a bug only reproduces in one of them.
    @Test
    func previewAndProductionShareOneSchema() throws {
        let preview = try ModelContainer.bookAppPreview()
        #expect(preview.schema.entities.count == ModelContainer.bookAppSchema.entities.count)
    }
}
