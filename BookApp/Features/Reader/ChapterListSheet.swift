import SwiftUI

/// Table-of-contents sheet for the reader. Built from the `# Heading` markers
/// the parser embeds in `BookVariant.contentText`, so it stays in sync with
/// whatever variant is currently being read (the original AND any
/// transformed version retain their chapter structure).
struct ChapterListSheet: View {
    struct ChapterMark: Hashable {
        let title: String
        let paragraphIndex: Int
    }

    let chapters: [ChapterMark]
    let currentParagraph: Int
    let onSelect: (ChapterMark) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if chapters.isEmpty {
                    Text("No chapters in this variant.")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(chapters.enumerated()), id: \.offset) { idx, chapter in
                        Button {
                            onSelect(chapter)
                            dismiss()
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(idx + 1)")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                                    .frame(width: 28, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chapter.title)
                                        .font(.system(size: 16, weight: .semibold, design: .serif))
                                        .foregroundStyle(Theme.Palette.textPrimary)
                                        .lineLimit(2)
                                    if isCurrent(chapter) {
                                        Text("Reading now")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(Theme.Palette.accent)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.textSecondary.opacity(0.5))
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Chapters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func isCurrent(_ chapter: ChapterMark) -> Bool {
        guard let next = chapters.first(where: { $0.paragraphIndex > chapter.paragraphIndex }) else {
            return chapter.paragraphIndex <= currentParagraph
        }
        return chapter.paragraphIndex <= currentParagraph
            && next.paragraphIndex > currentParagraph
    }
}
