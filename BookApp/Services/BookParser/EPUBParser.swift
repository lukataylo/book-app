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

    func parse(fileURL: URL, imagesDirectory: URL? = nil) async throws -> ParsedBook {
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
            let extracted = Self.extractChapter(html: html)
            // Skip empty / image-only spine entries (cover.xhtml, blank pages).
            guard extracted.body.split(whereSeparator: { $0.isWhitespace }).count >= 20 else { continue }
            // Skip Project-Gutenberg license boilerplate that nobody wants to read.
            if Self.looksLikeBoilerplate(extracted.body) { continue }

            // Only emit a `# Heading` marker when we actually parsed a real
            // heading. Filename-style spine hrefs (`1232-h-1.htm`,
            // hash-prefixed slugs) make terrible chapter titles when shown
            // verbatim, so we leave them out of the body and only keep them
            // for the chapters index.
            let titleForIndex = extracted.heading
                ?? parsed.titleForHref[spineRef]
                ?? URL(fileURLWithPath: spineRef).deletingPathExtension().lastPathComponent
            chapters.append(ParsedChapter(
                title: titleForIndex,
                text: extracted.body,
                locator: spineRef
            ))
            if let h = extracted.heading {
                fullText += "# \(h)\n\n\(extracted.body)\n\n"
            } else {
                fullText += "\(extracted.body)\n\n"
            }
        }

        // Cover: the OPF's <meta name="cover" content="ITEM_ID" /> points at a
        // manifest item; manifest item id → href.
        var coverData: Data?
        if let coverHref = parsed.coverHref {
            let resolved = resolve(href: coverHref, base: opfBase)
            coverData = try? await readEntry(archive, path: resolved)
        }

        // Pull every manifest entry whose href looks like an image. If
        // `imagesDirectory` was supplied we stream bytes directly to
        // `<dir>/<leaf>` and emit a filename-only `ParsedImage`, so an
        // image-heavy book never holds the full set in memory.
        // Otherwise (no directory) we fall back to buffering bytes for
        // compatibility with the legacy ImportService path.
        if let imagesDirectory {
            try? FileManager.default.createDirectory(
                at: imagesDirectory, withIntermediateDirectories: true
            )
        }
        var images: [ParsedImage] = []
        var seenNames = Set<String>()
        let imageExts: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "svg"]
        for href in parsed.imageHrefs {
            let leaf = (href as NSString).lastPathComponent
            let ext = (leaf as NSString).pathExtension.lowercased()
            guard imageExts.contains(ext), !seenNames.contains(leaf) else { continue }
            let resolved = resolve(href: href, base: opfBase)
            guard let bytes = try? await readEntry(archive, path: resolved) else { continue }
            if let imagesDirectory {
                let dest = imagesDirectory.appendingPathComponent(leaf)
                do {
                    try bytes.write(to: dest, options: .atomic)
                    images.append(ParsedImage(filename: leaf, data: nil))
                } catch {
                    // Disk write failed — keep bytes in-memory so the
                    // importer can retry the write on its side.
                    images.append(ParsedImage(filename: leaf, data: bytes))
                }
            } else {
                images.append(ParsedImage(filename: leaf, data: bytes))
            }
            seenNames.insert(leaf)
        }

        return ParsedBook(
            title: parsed.title.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : parsed.title,
            author: parsed.author,
            languageCode: parsed.language,
            coverData: coverData,
            chapters: chapters,
            fullText: fullText,
            format: .epub,
            images: images
        )
        #else
        throw ParserError.unsupportedFormat("EPUB parser requires ReadiumZIPFoundation (transitively pulled in by Readium)")
        #endif
    }

    /// Strip HTML tags + entities. Returns clean prose with paragraph breaks
    /// (`\n\n`) but no in-paragraph hard breaks — `<br>` becomes a space, not
    /// a newline, so prose flows correctly. Headings are preserved as their
    /// own paragraphs (caller adds the `#` prefix when stitching the body).
    static func htmlToPlainText(_ html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<head[\s\S]*?</head>"#, with: "", options: .regularExpression)
        // Inline images: replace each <img> with a paragraph-level marker the
        // reader can pick up to render the image. Filename only — the importer
        // writes images flat into <bookFolder>/images/.
        s = s.replacingOccurrences(
            of: #"<img\b[^>]*\bsrc\s*=\s*['"]([^'"]+)['"][^>]*/?>"#,
            with: "\n\n[img:$1]\n\n",
            options: .regularExpression
        )
        // Block-closing tags become paragraph breaks.
        let blocks = ["</p>", "</div>", "</section>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>", "</li>", "</blockquote>"]
        for tag in blocks {
            s = s.replacingOccurrences(of: tag, with: "\n\n", options: .caseInsensitive)
        }
        // <br> within prose: collapse to a space, not a newline. Keeps lines flowing.
        s = s.replacingOccurrences(of: "<br[^>]*>", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities: [String: String] = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&apos;": "'", "&#39;": "'", "&mdash;": "—",
            "&ndash;": "–", "&hellip;": "…", "&ldquo;": "\u{201C}", "&rdquo;": "\u{201D}",
            "&lsquo;": "\u{2018}", "&rsquo;": "\u{2019}"
        ]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        // Collapse runs of horizontal whitespace and newlines.
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: " *\\n *", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        // Lone newlines inside a paragraph become spaces — `\n\n` paragraph
        // breaks survive because neither of their two newlines is "lone".
        // Without this, hard-wrapped source HTML (Project Gutenberg ships
        // `<p>` content split over many physical lines) renders with a
        // visible break after every line.
        s = s.replacingOccurrences(of: "(?<!\\n)\\n(?!\\n)", with: " ", options: .regularExpression)
        // Project Gutenberg HTML often wraps every visual line in its own
        // `<p>` tag, which produces a cascade of half-sentence paragraphs
        // after our `</p>` → `\n\n` substitution. Merge any "paragraph"
        // that doesn't end with sentence-terminating punctuation into the
        // next one.
        s = mergeFragmentedParagraphs(s)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Joins consecutive paragraphs whose first does not end with `.`, `!`,
    /// `?`, `:`, `”`, `"`, `…`, or a closing quote so the running text
    /// reflows like prose instead of a per-line dump.
    private static func mergeFragmentedParagraphs(_ text: String) -> String {
        let parts = text.components(separatedBy: "\n\n")
        guard parts.count > 1 else { return text }
        let terminals: Set<Character> = [".", "!", "?", ":", "”", "\"", "…", "’", "'", ")"]
        var out: [String] = []
        var buffer = ""
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            // Headings (start with "# "), image markers, and very long
            // paragraphs always end a paragraph regardless of trailing
            // punctuation.
            let isHeading = trimmed.hasPrefix("# ")
            let isImage = trimmed.hasPrefix("[img:") && trimmed.hasSuffix("]")
            if isHeading || isImage {
                if !buffer.isEmpty { out.append(buffer); buffer = "" }
                out.append(trimmed)
                continue
            }
            buffer = buffer.isEmpty ? trimmed : "\(buffer) \(trimmed)"
            if let last = trimmed.last, terminals.contains(last), buffer.count > 40 {
                out.append(buffer)
                buffer = ""
            }
        }
        if !buffer.isEmpty { out.append(buffer) }
        return out.joined(separator: "\n\n")
    }

    /// Extract `(heading, body)` from a chapter's HTML.
    /// Heading is taken from the first `<h1>`/`<h2>`/`<h3>`. The body is the
    /// rest of the chapter with the heading element removed so the rendered
    /// page doesn't show the title twice.
    static func extractChapter(html: String) -> (heading: String?, body: String) {
        let pattern = #"<h([1-3])[^>]*>([\s\S]*?)</h\1>"#
        var heading: String?
        var bodyHTML = html
        let ns = html as NSString
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) {
            let raw = ns.substring(with: match.range(at: 2))
            let cleaned = htmlToPlainText(raw)
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty, cleaned.count <= 120 {
                heading = cleaned
                // Strip the entire heading tag from the HTML so it isn't
                // rendered again in the body.
                bodyHTML = ns.replacingCharacters(in: match.range, with: "")
            }
        }
        var body = htmlToPlainText(bodyHTML)
        // Final guard: if the first plain-text paragraph matches the heading,
        // drop it (some EPUBs put the title both in <h1> and in a sibling <p>).
        if let h = heading {
            let normHeading = h.lowercased().filter { !$0.isWhitespace }
            let paragraphs = body.components(separatedBy: "\n\n")
            if let first = paragraphs.first {
                let normFirst = first.lowercased().filter { !$0.isWhitespace }
                if normFirst == normHeading {
                    body = paragraphs.dropFirst().joined(separator: "\n\n")
                }
            }
        }
        return (heading, body)
    }

    /// Heuristic: spine entries that are just Project Gutenberg license / preamble.
    static func looksLikeBoilerplate(_ text: String) -> Bool {
        let head = text.prefix(800).lowercased()
        let signals = [
            "project gutenberg",
            "this ebook is for the use of anyone",
            "you may copy it, give it away or re-use",
            "start of the project gutenberg ebook",
            "end of the project gutenberg ebook",
            "produced by",
            "transcriber's note"
        ]
        let hits = signals.reduce(0) { $0 + (head.contains($1) ? 1 : 0) }
        return hits >= 2
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
        /// Manifest hrefs whose media-type is an image (or whose extension
        /// looks like one when media-type is missing).
        var imageHrefs: [String] = []
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
        result.imageHrefs = delegate.imageHrefs
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
    var imageHrefs: [String] = []

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
                let mediaType = (attributeDict["media-type"] ?? "").lowercased()
                if mediaType.hasPrefix("image/") {
                    imageHrefs.append(href)
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
