import Foundation
import PDFKit

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct PDFParser: BookParser {

    func parse(fileURL: URL, imagesDirectory: URL? = nil) async throws -> ParsedBook {
        // PDFParser doesn't extract inline images today — the parameter
        // is kept on the protocol for API symmetry with EPUBParser.
        _ = imagesDirectory
        guard let document = PDFDocument(url: fileURL) else {
            throw ParserError.fileUnreadable("PDFKit refused to open \(fileURL.lastPathComponent)")
        }

        let attrs = document.documentAttributes ?? [:]
        let title = (attrs[PDFDocumentAttribute.titleAttribute] as? String)
            ?? fileURL.deletingPathExtension().lastPathComponent
        let author = (attrs[PDFDocumentAttribute.authorAttribute] as? String) ?? ""

        var chapters: [ParsedChapter] = []
        var bodyParts: [String] = []
        bodyParts.reserveCapacity(document.pageCount)

        if let outline = document.outlineRoot, outline.numberOfChildren > 0 {
            chapters = harvestOutline(outline, document: document)
        }

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let text = page.string ?? ""
            bodyParts.append(text)
        }

        let body = bodyParts.joined(separator: "\n\n")

        if chapters.isEmpty {
            chapters = [ParsedChapter(
                title: "Body",
                text: body,
                locator: "page:1"
            )]
        }

        let cover = renderCover(from: document)

        return ParsedBook(
            title: title,
            author: author,
            languageCode: nil,
            coverData: cover,
            chapters: chapters,
            fullText: body,
            format: .pdf
        )
    }

    private func harvestOutline(_ outline: PDFOutline, document: PDFDocument) -> [ParsedChapter] {
        var result: [ParsedChapter] = []
        for i in 0..<outline.numberOfChildren {
            guard let node = outline.child(at: i) else { continue }
            let title = node.label ?? "Section \(i + 1)"
            let text = textBetween(node: node, sibling: outline.child(at: i + 1), document: document)
            let pageIndex: Int
            if let dest = node.destination, let page = dest.page {
                pageIndex = document.index(for: page)
            } else { pageIndex = 0 }
            result.append(ParsedChapter(
                title: title,
                text: text,
                locator: "page:\(pageIndex + 1)"
            ))
        }
        return result
    }

    private func textBetween(node: PDFOutline, sibling: PDFOutline?, document: PDFDocument) -> String {
        let startPage = node.destination?.page.flatMap { document.index(for: $0) } ?? 0
        let endPage: Int
        if let sib = sibling, let p = sib.destination?.page {
            endPage = document.index(for: p)
        } else {
            endPage = document.pageCount
        }
        var text = ""
        for i in startPage..<min(endPage, document.pageCount) {
            if let page = document.page(at: i) {
                text += (page.string ?? "") + "\n\n"
            }
        }
        return text
    }

    private func renderCover(from document: PDFDocument) -> Data? {
        guard let first = document.page(at: 0) else { return nil }
        let bounds = first.bounds(for: .mediaBox)
        let scale: CGFloat = 2
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            first.draw(with: .mediaBox, to: ctx.cgContext)
        }
        return image.jpegData(compressionQuality: 0.8)
        #elseif canImport(AppKit)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.scaleBy(x: scale, y: scale)
            first.draw(with: .mediaBox, to: ctx)
        }
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        #else
        return nil
        #endif
    }
}
