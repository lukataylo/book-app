import Testing
@testable import BookApp

struct ChunkerTests {

    @Test
    func chunksRespectMaxTokenBudget() {
        // Realistic-ish book: ~10 chapters of 200 short paragraphs each.
        let para = "Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n\n"
        let chapter = String(repeating: para, count: 200)
        let text = (1...10)
            .map { "Chapter \($0)\n\n\(chapter)" }
            .joined(separator: "\n\n")
        let maxTokens = 1_000
        let chunks = Chunker.chunk(text, maxTokens: maxTokens, overlapTokens: 100)
        #expect(!chunks.isEmpty)
        // Allow a small slack for the carried-over overlap from the previous chunk.
        for c in chunks { #expect(c.approxTokens <= maxTokens + 200) }
    }

    @Test
    func emptyInputProducesEmptyOutput() {
        #expect(Chunker.chunk("").isEmpty)
    }

    @Test
    func singleSmallInputProducesOneChunk() {
        let chunks = Chunker.chunk("Hello world", maxTokens: 100)
        #expect(chunks.count == 1)
        #expect(chunks[0].text == "Hello world")
    }
}
