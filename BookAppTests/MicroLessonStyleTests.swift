import Testing
@testable import BookApp

struct MicroLessonStyleTests {

    @Test
    func themeTagPicksMatchingSymbol() {
        #expect(MicroLessonStyle.symbol(forIndex: 0, tags: ["habit formation"]) == "repeat.circle")
        #expect(MicroLessonStyle.symbol(forIndex: 3, tags: ["money", "business"]) == "dollarsign.circle")
    }

    @Test
    func taglessDeckRotatesThroughFallbacks() {
        let a = MicroLessonStyle.symbol(forIndex: 0, tags: [])
        let b = MicroLessonStyle.symbol(forIndex: 1, tags: [])
        #expect(a == MicroLessonStyle.fallbackSymbols[0])
        #expect(b == MicroLessonStyle.fallbackSymbols[1])
        // Wraps around without going out of bounds.
        let wrapped = MicroLessonStyle.symbol(forIndex: MicroLessonStyle.fallbackSymbols.count, tags: [])
        #expect(wrapped == MicroLessonStyle.fallbackSymbols[0])
    }

    @Test
    func matchIsCaseInsensitive() {
        #expect(MicroLessonStyle.symbol(forIndex: 0, tags: ["STOIC acceptance"]) == "leaf")
    }
}
