import SwiftUI
import SwiftData

/// Combined Highlights + Bookmarks browser for the current book. Reader
/// toolbar opens this; tapping a row jumps the reader to that paragraph.
struct MarkingsSheet: View {
    let book: Book
    let onJump: (Int) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .highlights

    enum Tab: String, CaseIterable, Identifiable {
        case highlights, bookmarks
        var id: String { rawValue }
        var label: String {
            switch self {
            case .highlights: return "Highlights"
            case .bookmarks:  return "Bookmarks"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { t in Text(t.label).tag(t) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 6)

                List {
                    switch tab {
                    case .highlights: highlightRows
                    case .bookmarks:  bookmarkRows
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var highlightRows: some View {
        let items = (book.annotations ?? []).sorted { $0.createdAt > $1.createdAt }
        if items.isEmpty {
            placeholder("Long-press a paragraph and choose Highlight to start collecting passages here.")
        } else {
            ForEach(items) { ann in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: ann.color.hex))
                            .frame(width: 8, height: 8)
                        Text(ann.createdAt.formatted(.relative(presentation: .named)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Text(ann.quotedText)
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(5)
                    if !ann.note.isEmpty {
                        Text(ann.note)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        modelContext.delete(ann)
                        try? modelContext.save()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bookmarkRows: some View {
        let items = (book.bookmarks ?? []).sorted { $0.createdAt > $1.createdAt }
        if items.isEmpty {
            placeholder("Long-press a paragraph and choose Bookmark to drop a marker you can return to.")
        } else {
            ForEach(items) { bm in
                Button {
                    onJump(bm.paragraphIndex)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(bm.label.isEmpty ? "Paragraph \(bm.paragraphIndex + 1)" : bm.label)
                                .font(.system(size: 14, weight: .semibold, design: .serif))
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Spacer()
                            Text(bm.createdAt.formatted(.relative(presentation: .named)))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        if !bm.snippet.isEmpty {
                            Text(bm.snippet)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        modelContext.delete(bm)
                        try? modelContext.save()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func placeholder(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
