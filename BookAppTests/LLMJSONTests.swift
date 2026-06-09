import Testing
@testable import BookApp

struct LLMJSONTests {

    @Test
    func extractsBareArray() {
        let data = LLMJSON.extractArray(#"[{"a": 1}]"#)
        #expect(data != nil)
        #expect(String(data: data!, encoding: .utf8) == #"[{"a": 1}]"#)
    }

    @Test
    func stripsMarkdownFences() {
        let fenced = """
        ```json
        [{"title": "x"}]
        ```
        """
        let data = LLMJSON.extractArray(fenced)
        #expect(data != nil)
        #expect(String(data: data!, encoding: .utf8)?.contains("\"title\"") == true)
        #expect(String(data: data!, encoding: .utf8)?.contains("```") == false)
    }

    @Test
    func skipsPreambleAndAfterword() {
        let chatty = "Here are your cards:\n[{\"q\": 1}]\nHope that helps!"
        let data = LLMJSON.extractArray(chatty)
        #expect(data != nil)
        #expect(String(data: data!, encoding: .utf8) == #"[{"q": 1}]"#)
    }

    @Test
    func returnsNilWithoutAnArray() {
        #expect(LLMJSON.extractArray("no json here") == nil)
        #expect(LLMJSON.extractArray("{\"object\": true}") == nil)
        #expect(LLMJSON.extractArray("") == nil)
    }
}
