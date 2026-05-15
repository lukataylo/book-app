import SwiftUI

/// Live, case-insensitive search across the current variant's paragraphs.
/// Matches show as a list of snippets with the query highlighted; tapping
/// a result jumps the reader to that paragraph and dismisses the sheet.
struct SearchInBookSheet: View {
    let paragraphs: [String]
    let onJump: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if !query.isEmpty {
                    Text(matchCountSummary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                }

                List {
                    ForEach(matches, id: \.paragraphIndex) { match in
                        Button {
                            onJump(match.paragraphIndex)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(highlightedSnippet(for: match))
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                    .lineLimit(3)
                                Text(String(localized: "Paragraph \(match.paragraphIndex + 1)",
                                            comment: "Search result row — paragraph index"))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search in this book")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Localized summary line. Uses Apple's `.inflect` plural rules so
    /// translators can write "1 match" / "X matches" once per language
    /// in the xcstrings catalog.
    private var matchCountSummary: LocalizedStringKey {
        if matches.isEmpty {
            return "No matches in this variant."
        }
        return "^[\(matches.count) match](inflect: true)"
    }

    private struct Match {
        let paragraphIndex: Int
        let text: String
        let range: Range<String.Index>
    }

    private var matches: [Match] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        var results: [Match] = []
        for (idx, p) in paragraphs.enumerated() {
            let body = p.hasPrefix("# ") ? String(p.dropFirst(2)) : p
            if let range = body.range(of: q, options: .caseInsensitive) {
                results.append(Match(paragraphIndex: idx, text: body, range: range))
            }
            if results.count >= 200 { break }   // sane cap for large books
        }
        return results
    }

    /// Build a ~120-character window around the match with the matched
    /// substring rendered bold.
    private func highlightedSnippet(for match: Match) -> AttributedString {
        let body = match.text
        let windowChars = 60
        let beforeStart = body.index(match.range.lowerBound,
                                     offsetBy: -windowChars,
                                     limitedBy: body.startIndex) ?? body.startIndex
        let afterEnd = body.index(match.range.upperBound,
                                  offsetBy: windowChars,
                                  limitedBy: body.endIndex) ?? body.endIndex
        let prefix = beforeStart > body.startIndex ? "…" : ""
        let suffix = afterEnd < body.endIndex ? "…" : ""
        let window = body[beforeStart..<afterEnd]

        var attr = AttributedString(prefix + String(window) + suffix)
        if let attrRange = attr.range(of: String(body[match.range])) {
            attr[attrRange].font = .system(size: 14, weight: .semibold)
            attr[attrRange].backgroundColor = Theme.Palette.textPrimary.opacity(0.08)
        }
        return attr
    }
}
