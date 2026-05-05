import SwiftUI
import SwiftData

/// Reader UI matching the second screenshot: clean reflowable text, a thin
/// bottom bar with progress + Read / Listen / Settings / AI tabs.
///
/// Rendering strategy:
/// - PDF: PDFKit's `PDFView` (handled in `PDFReaderView`).
/// - EPUB: paginated reflowable text built from the variant's plain-text
///   body. We don't pull in Readium's full Navigator here so the same view
///   works for transformed variants (which are always plain text, not EPUB).
struct ReaderView: View {
    let book: Book

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ReaderViewModel?
    @State private var settings = ReaderSettings()
    @State private var showsBottomBar: Bool = true

    var body: some View {
        Group {
            if let vm = viewModel {
                content(viewModel: vm)
            } else {
                ProgressView()
                    .onAppear {
                        viewModel = ReaderViewModel(book: book)
                        ensureReaderSettings()
                    }
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsBottomBar.toggle()
                } label: {
                    Image(systemName: showsBottomBar ? "rectangle.bottombar.fill" : "rectangle.bottombar")
                }
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: ReaderViewModel) -> some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: settings.paragraphSpacing) {
                        ForEach(Array(viewModel.paragraphs.enumerated()), id: \.offset) { idx, paragraph in
                            Text(paragraph)
                                .font(Typography.reader(settings.font, size: settings.fontSize))
                                .foregroundStyle(textColor)
                                .lineSpacing((settings.lineSpacing - 1) * settings.fontSize)
                                .id(idx)
                        }
                    }
                    .padding(.horizontal, settings.margin.horizontalPadding)
                    .padding(.vertical, Theme.Spacing.l)
                }
                .onChange(of: viewModel.currentParagraph) { _, newValue in
                    withAnimation { proxy.scrollTo(newValue, anchor: .top) }
                }
            }
            if showsBottomBar {
                bottomBar(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: Binding(
            get: { viewModel.sheet },
            set: { viewModel.sheet = $0 }
        )) { sheet in
            switch sheet {
            case .readerSettings:
                ReaderSettingsSheet(settings: settings)
            case .ttsSettings:
                TTSSettingsSheet()
            case .speedReader:
                SpeedReaderView(paragraphs: viewModel.paragraphs)
            case .transformations:
                TransformationStudioView(book: book, sourceVariant: viewModel.currentVariant)
            case .learnings:
                BookLearningsView(book: book)
            }
        }
    }

    @ViewBuilder
    private func bottomBar(viewModel: ReaderViewModel) -> some View {
        HStack(spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: 2) {
                Text(progressClockText(viewModel: viewModel))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(textColor.opacity(0.6))
            }
            Spacer()
            BarButton(label: "Read", systemImage: "book.fill", active: true) {}
            BarButton(label: "Listen", systemImage: "waveform") {
                viewModel.sheet = .ttsSettings
            }
            BarButton(label: "Speed", systemImage: "bolt.fill") {
                viewModel.sheet = .speedReader
            }
            BarButton(label: "Theme", systemImage: "textformat.size") {
                viewModel.sheet = .readerSettings
            }
            BarButton(label: "AI", systemImage: "wand.and.stars") {
                viewModel.sheet = .transformations
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Theme.Palette.divider),
            alignment: .top
        )
    }

    private func progressClockText(viewModel: ReaderViewModel) -> String {
        let total = max(1, viewModel.paragraphs.count)
        let pct = Double(viewModel.currentParagraph) / Double(total)
        let pages = max(1, book.totalPagesEstimate)
        let currentPage = Int(pct * Double(pages))
        return "Page \(currentPage) of \(pages)"
    }

    private var backgroundColor: Color {
        switch settings.theme {
        case .light: return Color(hex: "FAF7F2")
        case .sepia: return Color(hex: "F4ECD8")
        case .dark:  return Color(hex: "1F1D1A")
        case .black: return .black
        }
    }

    private var textColor: Color {
        switch settings.theme {
        case .light: return Color(hex: "1A1815")
        case .sepia: return Color(hex: "433422")
        case .dark:  return Color(hex: "E5E0D7")
        case .black: return Color(hex: "C8C2B6")
        }
    }

    @MainActor
    private func ensureReaderSettings() {
        let descriptor = FetchDescriptor<ReaderSettings>()
        if let existing = try? modelContext.fetch(descriptor).first {
            settings = existing
        } else {
            let s = ReaderSettings()
            modelContext.insert(s)
            try? modelContext.save()
            settings = s
        }
    }
}

private struct BarButton: View {
    let label: String
    let systemImage: String
    var active: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(active ? Theme.Palette.accent : Theme.Palette.textSecondary)
            .frame(minWidth: 44)
        }
        .buttonStyle(.plain)
    }
}
