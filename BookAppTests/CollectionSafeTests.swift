import Testing
@testable import BookApp

/// Bounds-safe subscript is load-bearing for the reader: TTS,
/// speed-reader, and chapter resolution all index into mutable
/// paragraph/word arrays whose size can change under them. Coverage here
/// is deliberately exhaustive because a single missed edge case turns
/// into a real-device crash.
struct CollectionSafeTests {

    @Test
    func validIndexReturnsElement() {
        let xs = ["a", "b", "c"]
        #expect(xs[safe: 0] == "a")
        #expect(xs[safe: 2] == "c")
    }

    @Test
    func negativeIndexReturnsNil() {
        let xs = ["a"]
        #expect(xs[safe: -1] == nil)
    }

    @Test
    func indexBeyondEndReturnsNil() {
        let xs = ["a", "b"]
        #expect(xs[safe: 2] == nil)
        #expect(xs[safe: 99] == nil)
    }

    @Test
    func emptyArrayAlwaysReturnsNil() {
        let xs: [Int] = []
        #expect(xs[safe: 0] == nil)
        #expect(xs[safe: -1] == nil)
    }

    @Test
    func worksOnSubstringsToo() {
        // Speed reader uses split() which returns Substring — verify the
        // generic Collection extension picks it up.
        let words = "alpha beta gamma".split(separator: " ")
        #expect(words[safe: 0].map(String.init) == "alpha")
        #expect(words[safe: 5].map(String.init) == nil)
    }
}
