import Testing
import Foundation
@testable import BookApp

/// The widget snapshot is a small JSON file in the App Group container.
/// If its codec drifts, the home-screen widget silently falls back to
/// the empty state. These tests pin the wire format down.
struct WidgetSnapshotTests {

    @Test
    func roundTripPreservesAllFields() throws {
        let original = WidgetSnapshot(
            bookID: "F0F0F0F0-1234-5678-9ABC-DEF012345678",
            title: "The Republic",
            author: "Plato",
            percent: 0.42,
            coverFilename: "cover.jpg",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetSnapshot.self, from: data)

        #expect(decoded.bookID == original.bookID)
        #expect(decoded.title == original.title)
        #expect(decoded.author == original.author)
        #expect(decoded.percent == original.percent)
        #expect(decoded.coverFilename == original.coverFilename)
        #expect(abs(decoded.updatedAt.timeIntervalSince(original.updatedAt)) < 1.0)
    }

    @Test
    func emptyCoverFilenameYieldsNilURL() {
        // The widget calls coverURL(filename:) for every entry; an empty
        // filename must short-circuit so we don't end up with `…/.jpg`
        // or hitting the App Group container resolution path needlessly.
        #expect(WidgetSnapshot.coverURL(filename: "") == nil)
    }
}
