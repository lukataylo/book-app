import Foundation

struct Chunk: Sendable {
    let index: Int
    let total: Int
    let text: String
    let approxTokens: Int
}

/// Token-aware chunker. Splits long manuscripts on chapter / paragraph
/// boundaries while staying under a target input-token budget. Uses a
/// 4-chars≈1-token heuristic — close enough for cost estimation and budget
/// control without shipping a tokenizer.
///
/// Algorithm:
///   1. Split on chapter markers ("Chapter 7", "PART TWO", "1.") if any are
///      present, otherwise on double newlines.
///   2. Greedily pack blocks into a current chunk until the next block would
///      exceed `maxTokens`, then emit and start the next chunk with
///      `overlapTokens` of trailing context from the previous chunk.
///   3. Any block bigger than `maxTokens` is hard-split into windows of
///      `maxTokens` characters so a single huge paragraph never produces a
///      chunk that overflows the model's context window.
enum Chunker {

    /// Approximate tokens for any string. Heuristic: ~4 chars/token for English prose.
    static func tokenEstimate(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    static func chunk(
        _ text: String,
        maxTokens: Int = 80_000,
        overlapTokens: Int = 4_000
    ) -> [Chunk] {
        guard !text.isEmpty else { return [] }
        // Defensive: overlap that meets or exceeds maxTokens would loop forever.
        let safeOverlap = min(max(0, overlapTokens), max(0, maxTokens - 1))
        let charsPerToken = 4
        let maxChars = max(1, maxTokens * charsPerToken)
        let overlapChars = max(0, safeOverlap * charsPerToken)

        // Step 1: pre-split into blocks small enough to pack greedily. Anything
        // larger than the budget is hard-windowed so the packing loop never has
        // to deal with an overflowing block.
        var blocks: [String] = []
        for raw in splitOnChapterBoundaries(text) {
            if tokenEstimate(raw) <= maxTokens {
                blocks.append(raw)
                continue
            }
            // Hard-split oversized block by character window.
            var idx = raw.startIndex
            while idx < raw.endIndex {
                let end = raw.index(idx, offsetBy: maxChars, limitedBy: raw.endIndex) ?? raw.endIndex
                blocks.append(String(raw[idx..<end]))
                idx = end
            }
        }

        // Step 2: greedy packing with overlap on flush.
        var chunks: [String] = []
        var current = ""
        for block in blocks {
            let blockTokens = tokenEstimate(block)
            let nextSize = tokenEstimate(current) + blockTokens
            if current.isEmpty {
                current = block
            } else if nextSize <= maxTokens {
                current += block
            } else {
                chunks.append(current)
                let tail = overlapChars > 0 ? String(current.suffix(overlapChars)) : ""
                current = tail + block
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks.enumerated().map { i, t in
            Chunk(index: i, total: chunks.count, text: t, approxTokens: tokenEstimate(t))
        }
    }

    private static func splitOnChapterBoundaries(_ text: String) -> [String] {
        // Common chapter markers: "Chapter 1", "CHAPTER ONE", "I.", "Part 2",
        // "1\n", etc. A pragmatic regex matches a line starting with one of those.
        let pattern = #"(?m)^(?:Chapter\s+\d+|CHAPTER\s+[A-Z]+|Part\s+\d+|PART\s+[A-Z]+|\d{1,3}\.)\s*$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            if !matches.isEmpty {
                var blocks: [String] = []
                var lastEnd = 0
                for m in matches {
                    let start = m.range.location
                    if start > lastEnd {
                        blocks.append(ns.substring(with: NSRange(location: lastEnd, length: start - lastEnd)))
                    }
                    lastEnd = start
                }
                if lastEnd < ns.length {
                    blocks.append(ns.substring(with: NSRange(location: lastEnd, length: ns.length - lastEnd)))
                }
                return blocks
            }
        }
        // No chapter markers — fall back to paragraph groups (~5 paragraphs each).
        let paras = text.components(separatedBy: "\n\n")
        if paras.count <= 1 { return [text] }
        var blocks: [String] = []
        var buf: [String] = []
        for p in paras {
            buf.append(p)
            if buf.count >= 5 {
                blocks.append(buf.joined(separator: "\n\n"))
                buf.removeAll()
            }
        }
        if !buf.isEmpty { blocks.append(buf.joined(separator: "\n\n")) }
        return blocks.isEmpty ? [text] : blocks
    }
}
