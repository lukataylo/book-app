import Testing
@testable import BookApp

struct LLMJSONTests {

    @Test
    func extractsBareArray() throws {
        let data = try #require(LLMJSON.extractArray(#"[{"a": 1}]"#))
        #expect(String(data: data, encoding: .utf8) == #"[{"a": 1}]"#)
    }

    @Test
    func stripsMarkdownFences() throws {
        let fenced = """
        ```json
        [{"title": "x"}]
        ```
        """
        let data = try #require(LLMJSON.extractArray(fenced))
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"title\""))
        #expect(!text.contains("```"))
    }

    @Test
    func skipsPreambleAndAfterword() throws {
        let chatty = "Here are your cards:\n[{\"q\": 1}]\nHope that helps!"
        let data = try #require(LLMJSON.extractArray(chatty))
        #expect(String(data: data, encoding: .utf8) == #"[{"q": 1}]"#)
    }

    @Test
    func returnsNilWithoutAnArray() {
        #expect(LLMJSON.extractArray("no json here") == nil)
        #expect(LLMJSON.extractArray("{\"object\": true}") == nil)
        #expect(LLMJSON.extractArray("") == nil)
    }
}
