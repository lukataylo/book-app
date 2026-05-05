import Foundation

#if canImport(ReadiumZIPFoundation)
import ReadiumZIPFoundation
#endif

/// Minimal in-house EPUB parser.
///
/// EPUB is a ZIP file with a known structure:
///
/// 1. `mimetype` — must be `application/epub+zip` (we don't enforce; iCloud
///    sometimes hands us re-zipped files).
/// 2. `META-INF/container.xml` — points at the package document (`.opf`).
/// 3. The OPF lists manifest items + spine ordering.
/// 4. Each spine item is an XHTML file; we strip tags to plain text for the
///    LLM stack and TTS.
///
/// We use the version of ZIPFoundation that Readium pulls in transitively
/// (`ReadiumZIPFoundation`) to keep the dependency footprint small and avoid
/// the SemVer collision between weichsel/ZIPFoundation 0.x and Readium's 3.x
/// fork. The full Readium navigator (paginated rendering with themes /
/// fonts) is wired separately in `ReaderView` for EPUBs that the user opens
/// in the dedicated EPUB renderer.
struct EPUBParser: BookParser {

    func parse(fileURL: URL) async throws -> ParsedBook {
        #if canImport(ReadiumZIPFoundation)
        let archive: Archive
        do {
            archive = try await Archive(url: fileURL, accessMode: .read)
        } catch {
            throw ParserError.fileUnreadable("Couldn't open EPUB archive: \(fileURL.lastPathComponent)")
        }
        guard let containerData = try? await readEntry(archive, path: "META-INF/container.xml") else {
            throw ParserError.decodingFailed("META-INF/container.xml missing")
        }
        guard let opfPath = parseContainer(data: containerData) else {
            throw ParserError.decodingFailed("OPF path not found in container.xml")
        }
        guard let opfData = try? await readEntry(archive, path: opfPath) else {
            throw ParserError.decodingFailed("OPF not found at \(opfPath)")
        }

        let opfBase = (opfPath as NSString).deletingLastPathComponent
        let parsed = parseOPF(data: opfData, basePath: opfBase)

        var chapters: [ParsedChapter] = []
        var fullText = ""

        for spineRef in parsed.spineHrefs {
            let resolved = resolve(href: spineRef, base: opfBase)
            guard let raw = try? await readEntry(archive, path: resolved) else { continue }
            let html = String(data: raw, encoding: .utf8) ?? String(data: raw, encoding: .isoLatin1) ?? ""
            let plain = Self.htmlToPlainText(html)
            chapters.append(ParsedChapter(
                title: parsed.titleForHref[spineRef] ?? URL(fileURLWithPath: spineRef).deletingPathExtension().lastPathComponent,
                text: plain,
                locator: spineRef
            ))
            fullText += plain + "\n\n"
        }

        // Cover: the OPF's <meta name="cover" content="ITEM_ID" /> points at a
        // manifest item; manifest item id → href.
        var coverData: Data?
        if let coverHref = parsed.coverHref {
            let resolved = resolve(href: coverHref, base: opfBase)
            coverData = try? await readEntry(archive, path: resolved)
        }

        return ParsedBook(
            title: parsed.title.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : parsed.title,
            author: parsed.author,
            languageCode: parsed.language,
            coverData: coverData,
            chapters: chapters,
            fullText: fullText,
            format: .epub
        )
        #else
        throw ParserError.unsupportedFormat("EPUB parser requires ReadiumZIPFoundation (transitively pulled in by Readium)")
        #endif
    }

    /// Strip HTML tags + entities. Good enough for plain-text TTS / LLM input.
    /// (Full EPUB rendering with themes is delegated to the navigator.)
    static func htmlToPlainText(_ html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: "", options: .regularExpression)
        let blocks = ["</p>", "</div>", "</section>", "</h1>", "</h2>", "</h3>", "</h4>", "</li>"]
        for tag in blocks {
            s = s.replacingOccurrences(of: tag, with: "\n\n", options: .caseInsensitive)
        }
        s = s.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities: [String: String] = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&apos;": "'", "&#39;": "'", "&mdash;": "—",
            "&ndash;": "–", "&hellip;": "…", "&ldquo;": "\u{201C}", "&rdquo;": "\u{201D}",
            "&lsquo;": "\u{2018}", "&rsquo;": "\u{2019}"
        ]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    #if canImport(ReadiumZIPFoundation)
    private func readEntry(_ archive: Archive, path: String) async throws -> Data {
        guard let entry = try await archive.get(path) else {
            throw ParserError.decodingFailed("Entry not found: \(path)")
        }
        // Consumer is `@Sendable (Data) async throws -> Void`, so we can
        // await the actor inside the closure to accumulate chunks in order.
        let collector = DataCollector()
        _ = try await archive.extract(entry) { chunk in
            await collector.append(chunk)
        }
        return await collector.data
    }

    private actor DataCollector {
        var data = Data()
        func append(_ chunk: Data) { data.append(chunk) }
    }
    #endif

    private func parseContainer(data: Data) -> String? {
        let parser = XMLParser(data: data)
        let delegate = ContainerDelegate()
        parser.delegate = delegate
        parser.parse()
        return delegate.opfPath
    }

    private struct OPFResult {
        var title = ""
        var author = ""
        var language: String?
        var coverHref: String?
        var spineHrefs: [String] = []
        var titleForHref: [String: String] = [:]
    }

    private func parseOPF(data: Data, basePath: String) -> OPFResult {
        let parser = XMLParser(data: data)
        let delegate = OPFDelegate()
        parser.delegate = delegate
        parser.parse()

        var result = OPFResult()
        result.title = delegate.title
        result.author = delegate.author
        result.language = delegate.language
        if let coverID = delegate.coverID {
            result.coverHref = delegate.manifest[coverID]
        }
        for itemref in delegate.spine {
            if let href = delegate.manifest[itemref] {
                result.spineHrefs.append(href)
            }
        }
        return result
    }

    private func resolve(href: String, base: String) -> String {
        if base.isEmpty { return href }
        return (base as NSString).appendingPathComponent(href)
    }
}

private final class ContainerDelegate: NSObject, XMLParserDelegate {
    var opfPath: String?
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "rootfile" {
            opfPath = attributeDict["full-path"]
        }
    }
}

private final class OPFDelegate: NSObject, XMLParserDelegate {
    var title = ""
    var author = ""
    var language: String?
    var manifest: [String: String] = [:] // id -> href
    var spine: [String] = []
    var coverID: String?

    private var current: String = ""
    private var captureBuffer: String = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        current = elementName.lowercased()
        captureBuffer = ""
        switch current {
        case "item":
            if let id = attributeDict["id"], let href = attributeDict["href"] {
                manifest[id] = href
                if attributeDict["properties"]?.contains("cover-image") == true {
                    coverID = id
                }
            }
        case "itemref":
            if let idref = attributeDict["idref"] { spine.append(idref) }
        case "meta":
            if (attributeDict["name"] ?? "") == "cover", let content = attributeDict["content"] {
                coverID = content
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        captureBuffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let tag = elementName.lowercased()
        let value = captureBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch tag {
        case "dc:title", "title":
            if !value.isEmpty, title.isEmpty { title = value }
        case "dc:creator", "creator":
            if !value.isEmpty, author.isEmpty { author = value }
        case "dc:language", "language":
            if !value.isEmpty, language == nil { language = value }
        default:
            break
        }
        captureBuffer = ""
    }
}
