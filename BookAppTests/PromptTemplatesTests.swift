import Testing
@testable import BookApp

struct PromptTemplatesTests {

    @Test
    func compressionDirectiveMentionsRatio() {
        let (system, _) = PromptTemplates.transformChunk(
            kind: .compressed,
            targetRatio: 0.25,
            styleReference: "",
            omittedThemes: [],
            chunkIndex: 0,
            chunkCount: 4
        )
        #expect(system.contains("25%"))
        #expect(system.contains("Compress"))
    }

    @Test
    func styleTransferReferencesAuthor() {
        let (system, _) = PromptTemplates.transformChunk(
            kind: .styled,
            targetRatio: 1.0,
            styleReference: "Malcolm Gladwell",
            omittedThemes: [],
            chunkIndex: 0,
            chunkCount: 1
        )
        #expect(system.contains("Malcolm Gladwell"))
    }

    @Test
    func themeOmissionListsThemes() {
        let (system, _) = PromptTemplates.transformChunk(
            kind: .themeOmitted,
            targetRatio: 1.0,
            styleReference: "",
            omittedThemes: ["religion", "violence"],
            chunkIndex: 0,
            chunkCount: 1
        )
        #expect(system.contains("religion"))
        #expect(system.contains("violence"))
    }
}
