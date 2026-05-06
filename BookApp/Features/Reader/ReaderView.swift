import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Reader UI — clean reflowable text with a glassy floating control bar,
/// tap-to-page zones, and a scroll-progress indicator at the top.
///
/// Block parser:
///   - lines starting with `# ` are rendered as chapter headings (large serif)
///   - everything else is body prose (chosen ReaderFont)
///   - empty lines become paragraph gaps
///
/// Page navigation:
///   - tap the left third of the screen → previous viewport
///   - tap the right third → next viewport
///   - tap the centre → toggle the controls (chrome on / off)
struct ReaderView: View {
    let book: Book
    let variant: BookVariant?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ReaderViewModel?
    @State private var settings = ReaderSettings()
    @State private var showsChrome: Bool = true
    @State private var scrollProgress: Double = 0
    @State private var contentHeight: CGFloat = 1
    @State private var viewportHeight: CGFloat = 1
    @State private var scrollPosition = ScrollPosition()
    @State private var ttsEngine = TTSEngine.shared
    @State private var savedToast: String?
    @State private var persistTask: Task<Void, Never>?
    @State private var mode: ReaderMode = .read
    @StateObject private var stats = ReadingStats.shared

    init(book: Book, variant: BookVariant? = nil) {
        self.book = book
        self.variant = variant
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                content(viewModel: vm)
            } else {
                ProgressView()
                    .onAppear {
                        viewModel = ReaderViewModel(book: book, variant: variant)
                        ensureReaderSettings()
                    }
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(showsChrome ? .visible : .hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)        // <- tab bar OFF in the reader
        .toolbar {
            // System back chevron is added automatically by NavigationStack —
            // we only customise the centre title so the parent screen's title
            // doesn't bleed in.
            ToolbarItem(placement: .principal) {
                Text(book.title)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(textColor.opacity(0.85))
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel?.sheet = .chapters
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(textColor.opacity(0.85))
                }
                .accessibilityLabel("Chapters")
            }
        }
        .statusBarHidden(!showsChrome)
        .preferredColorScheme(settings.theme == .dark || settings.theme == .black ? .dark : .light)
        .onAppear { stats.start() }
        .onDisappear { stats.stop() }
    }

    @ViewBuilder
    private func content(viewModel: ReaderViewModel) -> some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: settings.paragraphSpacing) {
                        ForEach(Array(blocksWithContext.enumerated()), id: \.offset) { idx, item in
                            blockView(item.block, isFirstAfterHeading: item.firstAfterHeading)
                                .id(idx)
                        }
                        // Bottom spacer so content can scroll above the bar.
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, settings.margin.horizontalPadding)
                    .padding(.top, Theme.Spacing.l)
                    .frame(maxWidth: 720, alignment: .leading)         // measure cap
                    .frame(maxWidth: .infinity, alignment: .center)    // centre on iPad
                    .scrollTargetLayout()
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ContentHeightKey.self, value: geo.size.height)
                        }
                    )
                }
                .modifier(PagingModifier(enabled: settings.paginatedScroll))
                .onPreferenceChange(ContentHeightKey.self) { contentHeight = max(1, $0) }
                .scrollPositionTracking(progress: $scrollProgress, container: $viewportHeight)
                .scrollPosition($scrollPosition)
                .onChange(of: viewModel.currentParagraph) { _, newValue in
                    withAnimation { proxy.scrollTo(newValue, anchor: .top) }
                }
                .onChange(of: scrollProgress) { _, newValue in
                    // Debounce progress writes — every observable scroll tick
                    // shouldn't pound the model context. We persist after the
                    // scroll has come to rest (handled by debounce task).
                    schedulePersistProgress(percent: newValue)
                }
            }

            // When the chrome is hidden the whole content area becomes a
            // tap target to bring it back. While chrome is visible we don't
            // attach gestures to the body so the bar's buttons receive every
            // touch cleanly.
            if !showsChrome {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.18)) { showsChrome = true }
                    }
            }

            // Top progress hairline.
            VStack(spacing: 0) {
                ProgressBar(progress: scrollProgress, tint: textColor.opacity(0.6))
                    .frame(height: 2)
                    .opacity(showsChrome ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: showsChrome)
                Spacer()
            }
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .top)

            if showsChrome {
                bottomBar(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }

            if let toast = savedToast {
                Text(toast)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 110)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(3)
                    .accessibilityLabel(toast)
            }
        }
        .onChange(of: viewModel.sheet) { old, new in
            // If the user dismissed the speed-reader sheet (swipe-down),
            // revert the mode pill to Read so the bar reflects reality.
            if mode == .speed && old == .speedReader && new == nil {
                mode = .read
            }
        }
        .sheet(item: Binding(
            get: { viewModel.sheet },
            set: { viewModel.sheet = $0 }
        )) { sheet in
            switch sheet {
            case .readerSettings:
                ReaderSettingsSheet(settings: settings)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.regularMaterial)
            case .ttsSettings:
                TTSSettingsSheet()
                    .presentationDetents([.medium])
                    .presentationBackground(.regularMaterial)
            case .speedReader:
                SpeedReaderView(paragraphs: viewModel.paragraphs)
            case .transformations:
                TransformationStudioView(book: book, sourceVariant: viewModel.currentVariant)
                    .presentationDetents([.medium, .large])
            case .chapters:
                ChapterListSheet(
                    chapters: viewModel.chapters.map {
                        ChapterListSheet.ChapterMark(title: $0.title, paragraphIndex: $0.paragraphIndex)
                    },
                    currentParagraph: viewModel.currentParagraph
                ) { chapter in
                    viewModel.currentParagraph = chapter.paragraphIndex
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Block model

    enum Block: Hashable {
        case heading(String)
        case paragraph(String)
    }

    /// All blocks in reading order, paired with whether they are the first
    /// paragraph after a `# Heading` (for drop-cap rendering).
    private var blocksWithContext: [(block: Block, firstAfterHeading: Bool)] {
        guard let viewModel else { return [] }
        var result: [(Block, Bool)] = []
        var prevWasHeading = false
        for p in viewModel.paragraphs {
            if p.hasPrefix("# ") {
                let title = String(p.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                result.append((.heading(title), false))
                prevWasHeading = true
            } else {
                result.append((.paragraph(p), prevWasHeading))
                prevWasHeading = false
            }
        }
        return result
    }

    @ViewBuilder
    private func blockView(_ block: Block, isFirstAfterHeading: Bool) -> some View {
        switch block {
        case .heading(let text):
            Text(text)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(textColor)
                .padding(.top, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xs)
        case .paragraph(let text):
            Text(paragraphAttributed(text, dropCap: isFirstAfterHeading && settings.dropCaps))
                .lineSpacing((settings.lineSpacing - 1) * settings.fontSize)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .contextMenu {
                    Button {
                        saveLearning(text: text)
                    } label: {
                        Label("Save as Learning", systemImage: "lightbulb.fill")
                    }
                    Button {
                        saveAnnotation(text: text)
                    } label: {
                        Label("Highlight", systemImage: "highlighter")
                    }
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Label("Copy paragraph", systemImage: "doc.on.doc")
                    }
                }
        }
    }

    /// Build the paragraph as an `AttributedString` so the body font + drop
    /// cap can co-exist on the same `Text` view (avoids HStack drop-cap
    /// hacks that don't reflow with the rest of the line).
    private func paragraphAttributed(_ text: String, dropCap: Bool) -> AttributedString {
        var attr = AttributedString(text)
        attr.font = Typography.reader(settings.font, size: settings.fontSize)
        attr.foregroundColor = textColor
        guard dropCap, !text.isEmpty else { return attr }
        let firstStart = attr.startIndex
        let firstEnd   = attr.index(firstStart, offsetByCharacters: 1)
        attr[firstStart..<firstEnd].font = .system(
            size: settings.fontSize * 2.4,
            weight: .semibold,
            design: .serif
        )
        attr[firstStart..<firstEnd].foregroundColor = textColor
        return attr
    }

    // MARK: - Save actions

    private func saveLearning(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let learning = KeyLearning(
            book: book,
            text: String(trimmed.prefix(500)),
            chapterRef: currentChapterTitle(),
            userEdited: true
        )
        modelContext.insert(learning)
        try? modelContext.save()
        showToast("Saved to learnings")
    }

    private func saveAnnotation(text: String) {
        let annotation = Annotation(
            book: book,
            variantID: viewModel?.currentVariant.id,
            quotedText: String(text.prefix(800)),
            note: "",
            color: .yellow
        )
        modelContext.insert(annotation)
        try? modelContext.save()
        showToast("Highlight saved")
    }

    private func currentChapterTitle() -> String {
        guard let vm = viewModel else { return "" }
        let chapters = vm.chapters
        guard !chapters.isEmpty else { return "" }
        let current = vm.currentParagraph
        let active = chapters.last(where: { $0.paragraphIndex <= current })
        return active?.title ?? ""
    }

    /// Debounced reading-progress persist. Cancels any in-flight write and
    /// queues a fresh one 600ms in the future. The first scroll tick of a
    /// session also bumps `lastOpenedAt` so the library sort is meaningful.
    private func schedulePersistProgress(percent: Double) {
        guard let vm = viewModel else { return }
        persistTask?.cancel()
        let pct = max(0, min(1, percent))
        persistTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            vm.updateProgress(
                percent: pct,
                locator: "scroll:\(Int(pct * 1_000_000))",
                in: modelContext
            )
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.18)) { savedToast = message }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeIn(duration: 0.2)) { savedToast = nil }
        }
    }

    // MARK: - TTS controls

    /// Tap on Listen — reuse the user's saved voice + rate + pitch + sleep
    /// timer rather than starting from blank defaults each time.
    private func toggleListen(viewModel: ReaderViewModel) {
        let descriptor = FetchDescriptor<TTSSettings>()
        let saved = (try? modelContext.fetch(descriptor).first) ?? {
            let s = TTSSettings()
            modelContext.insert(s)
            try? modelContext.save()
            return s
        }()
        ttsEngine.configure(settings: saved)
        ttsEngine.togglePlayback(paragraphs: viewModel.paragraphs)
    }

    // MARK: - Bottom bar (iOS Books style)

    /// Bottom of the screen has two layers:
    ///   1. A tall gradient fade (~140pt) from clear → page background, so any
    ///      text underneath the controls stays legible without a hard divider.
    ///   2. A minimal control row: time/page indicator | Read·Listen segment |
    ///      brightness | Aa | AI, capped by a centred chevron-down to collapse.
    @ViewBuilder
    private func bottomBar(viewModel: ReaderViewModel) -> some View {
        let isDark = settings.theme == .dark || settings.theme == .black
        let bg = backgroundColor

        VStack(spacing: 0) {
            LinearGradient(
                colors: [bg.opacity(0), bg.opacity(0.55), bg.opacity(0.92), bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
            .allowsHitTesting(false)

            VStack(spacing: 10) {
                // Three-tab mode pill — always visible. Each tab switches the
                // reader into Read / Speed / Listen and triggers the right
                // side-effect (start/stop TTS, open speed reader, etc.).
                ModeTabPill(mode: $mode, isDark: isDark)
                    .padding(.horizontal, 18)
                    .onChange(of: mode) { _, newMode in
                        applyModeChange(to: newMode, viewModel: viewModel)
                    }

                // Contextual controls underneath the pill.
                modeControls(viewModel: viewModel, isDark: isDark)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)

                // Mode-independent secondary row: Aa, AI, collapse-chrome.
                HStack(spacing: 22) {
                    Spacer()
                    IconBarButton(systemImage: "textformat.size", isDark: isDark) {
                        viewModel.sheet = .readerSettings
                    }
                    IconBarButton(systemImage: "wand.and.stars", isDark: isDark) {
                        viewModel.sheet = .transformations
                    }
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { showsChrome = false }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(textColor.opacity(0.5))
                            .frame(width: 38, height: 38)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.bottom, 2)
            }
            .padding(.bottom, 4)
            .background(bg)
        }
    }

    @ViewBuilder
    private func modeControls(viewModel: ReaderViewModel, isDark: Bool) -> some View {
        switch mode {
        case .read:
            progressRegion(isPlaying: false)
        case .speed:
            speedTabHint()
        case .listen:
            listenControls(viewModel: viewModel, isDark: isDark)
        }
    }

    @ViewBuilder
    private func speedTabHint() -> some View {
        // Speed reading takes over the screen via SpeedReaderView (sheet),
        // so the inline area shows the current state plus a re-open shortcut.
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("Speed reading…")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button {
                if let vm = viewModel { vm.sheet = .speedReader }
            } label: {
                Text("Resume")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().stroke(textColor.opacity(0.2), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(textColor.opacity(0.7))
    }

    @ViewBuilder
    private func listenControls(viewModel: ReaderViewModel, isDark: Bool) -> some View {
        VStack(spacing: 8) {
            if !ttsEngine.currentText.isEmpty {
                Text(ttsEngine.currentText.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(textColor.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 16) {
                Button {
                    viewModel.sheet = .ttsSettings
                } label: {
                    Image(systemName: "person.wave.2")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(textColor.opacity(0.78))
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Voice settings")

                Spacer()

                Button {
                    ttsEngine.skipBackward()
                } label: {
                    Image(systemName: "gobackward")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isDark ? Color.white : Color.black)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                Button {
                    ttsEngine.togglePlayback(paragraphs: viewModel.paragraphs)
                } label: {
                    Image(systemName: ttsEngine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(isDark ? Color.black : Color.white)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(isDark ? Color.white : Color.black))
                }
                .buttonStyle(.plain)

                Button {
                    ttsEngine.skipForward()
                } label: {
                    Image(systemName: "goforward")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isDark ? Color.white : Color.black)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    ttsEngine.cycleRate()
                } label: {
                    Text(rateLabel(for: ttsEngine.currentRate))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .frame(minWidth: 38, minHeight: 28)
                        .padding(.horizontal, 8)
                        .background(
                            Capsule().stroke(textColor.opacity(0.2), lineWidth: 0.5)
                        )
                        .foregroundStyle(textColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Side-effects of the user changing the active mode tab. Keeps the
    /// engine state and any sub-sheet in sync with the pill's selection.
    private func applyModeChange(to newMode: ReaderMode, viewModel: ReaderViewModel) {
        switch newMode {
        case .read:
            if ttsEngine.isPlaying { ttsEngine.pause() }
        case .listen:
            // Start narration if we aren't already playing.
            if !ttsEngine.isPlaying {
                toggleListen(viewModel: viewModel)
            }
        case .speed:
            // Pause TTS in case it was active, open the speed-read sheet.
            if ttsEngine.isPlaying { ttsEngine.pause() }
            viewModel.sheet = .speedReader
        }
    }

    @ViewBuilder
    private func progressRegion(isPlaying: Bool) -> some View {
        if isPlaying, !ttsEngine.currentText.isEmpty {
            // While narrating, replace the indicator with the snippet being
            // read. Skip controls live in the next row.
            Text(ttsEngine.currentText.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 13, weight: .regular, design: .serif))
                .foregroundStyle(textColor.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            switch settings.progressIndicator {
            case .timeLeft:
                Text(timeLeftText())
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(textColor.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .pageCount:
                Text(pageCountText())
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(textColor.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .progressBar:
                ScrubBar(
                    progress: scrollProgress,
                    tint: textColor.opacity(0.85),
                    track: textColor.opacity(0.12)
                ) { newProgress in
                    seek(to: newProgress)
                }
            }
        }
    }

    private func rateLabel(for rate: Double) -> String {
        // Map AVSpeech rate (0.0-1.0, default 0.5) to playback-speed style.
        switch Float(rate) {
        case ..<0.45: return "0.8×"
        case ..<0.55: return "1×"
        case ..<0.65: return "1.3×"
        default:      return "1.6×"
        }
    }

    /// Jump the reader's scroll position to the given 0-1 progress.
    private func seek(to progress: Double) {
        let clamped = max(0, min(1, progress))
        let total = max(1, contentHeight - viewportHeight)
        let targetY = clamped * Double(total)
        scrollPosition.scrollTo(y: targetY)
        scrollProgress = clamped
    }

    private func timeLeftText() -> String {
        let pct = scrollProgress.clamped()
        let totalWords = book.totalWordsEstimate
        if totalWords > 250 {
            let remaining = max(0, Double(totalWords) * (1.0 - pct))
            let mins = Int(remaining / 250)
            if mins == 0 { return "Almost done" }
            if mins < 60 { return "\(mins) min left" }
            let h = mins / 60
            let m = mins % 60
            return m == 0 ? "\(h) h left" : "\(h)h \(m)m left"
        }
        return pageCountText()
    }

    private func pageCountText() -> String {
        let pct = scrollProgress.clamped()
        let pages = max(1, book.totalPagesEstimate)
        let currentPage = max(1, Int(pct * Double(pages)).clampedToPages(pages))
        return "\(currentPage) / \(pages)"
    }


    // MARK: - Theming helpers

    private var backgroundColor: Color {
        switch settings.theme {
        case .light: return Color(hex: "FFFFFF")
        case .sepia: return Color(hex: "F4ECD8")
        case .dark:  return Color(hex: "111111")
        case .black: return .black
        }
    }

    private var textColor: Color {
        switch settings.theme {
        case .light: return Color(hex: "0A0A0A")
        case .sepia: return Color(hex: "433422")
        case .dark:  return Color(hex: "F0EBE3")
        case .black: return Color(hex: "EDEDED")
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

// MARK: - Mode pill

/// The three reading modes — the unified UI for "Read / Speed / Listen".
enum ReaderMode: String, CaseIterable, Hashable {
    case read, speed, listen

    var systemImage: String {
        switch self {
        case .read:   return "book"
        case .speed:  return "bolt.fill"
        case .listen: return "headphones"
        }
    }

    var label: String {
        switch self {
        case .read:   return "Read"
        case .speed:  return "Speed"
        case .listen: return "Listen"
        }
    }
}

/// Three-segment selectable pill — Apple Books-style "Read / Listen" extended
/// with a Speed segment in the middle. Selected segment fills with the inverse
/// of the page background; the others stay outlined.
private struct ModeTabPill: View {
    @Binding var mode: ReaderMode
    let isDark: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ReaderMode.allCases, id: \.self) { tab in
                Button {
                    mode = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.label)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(
                        mode == tab
                            ? (isDark ? Color.black : Color.white)
                            : (isDark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                    )
                    .background(
                        ZStack {
                            if mode == tab {
                                Capsule().fill(isDark ? Color.white : Color.black)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .stroke(isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.12), lineWidth: 0.5)
        )
    }
}

/// Plain round-icon control — used for Aa and AI in the secondary row.
private struct IconBarButton: View {
    let systemImage: String
    let isDark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isDark ? Color.white.opacity(0.85) : Color.black.opacity(0.78))
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scroll progress

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ProgressBar: View {
    let progress: Double
    let tint: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(tint.opacity(0.10))
                Rectangle()
                    .fill(tint)
                    .frame(width: geo.size.width * progress.clamped())
            }
        }
    }
}

private extension Double {
    func clamped() -> Double { Swift.max(0, Swift.min(1, self)) }
}

private extension Int {
    func clampedToPages(_ total: Int) -> Int { Swift.max(1, Swift.min(total, self)) }
}

/// Slim scrubbable progress bar. Pannable thumb, taps jump to position.
/// 4pt tall when idle, 6pt while dragging.
private struct ScrubBar: View {
    let progress: Double
    let tint: Color
    let track: Color
    let onChange: (Double) -> Void

    @State private var isDragging: Bool = false
    @State private var dragValue: Double = 0

    var body: some View {
        GeometryReader { geo in
            let displayed = isDragging ? dragValue : progress
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, geo.size.width * displayed))
                Circle()
                    .fill(tint)
                    .frame(width: isDragging ? 14 : 10, height: isDragging ? 14 : 10)
                    .offset(x: max(0, min(geo.size.width - 5, geo.size.width * displayed - 5)))
            }
            .frame(height: isDragging ? 6 : 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle().inset(by: -10))   // generous hit area
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        isDragging = true
                        let pct = max(0, min(1, v.location.x / geo.size.width))
                        dragValue = pct
                    }
                    .onEnded { _ in
                        onChange(dragValue)
                        isDragging = false
                    }
            )
            .animation(.easeOut(duration: 0.15), value: isDragging)
        }
        .frame(height: 16)        // total clickable height
    }
}

/// Conditional paging behaviour — applies `.scrollTargetBehavior(.paging)`
/// only when `enabled`. Default `.viewAligned` is implicit when off.
private struct PagingModifier: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.scrollTargetBehavior(.paging)
        } else {
            content
        }
    }
}

/// Tracks vertical scroll progress (0…1) plus the viewport height so the
/// reader can page-flip by one viewport on tap.
private extension View {
    func scrollPositionTracking(
        progress: Binding<Double>,
        container: Binding<CGFloat>
    ) -> some View {
        self.modifier(ScrollProgressModifier(progress: progress, container: container))
    }
}

private struct ScrollProgressModifier: ViewModifier {
    @Binding var progress: Double
    @Binding var container: CGFloat

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: ScrollGeo.self) { geo in
                ScrollGeo(
                    offset: geo.contentOffset.y,
                    contentSize: geo.contentSize.height,
                    containerSize: geo.containerSize.height
                )
            } action: { _, newValue in
                let total = max(1, newValue.contentSize - newValue.containerSize)
                progress  = Double(newValue.offset) / Double(total)
                container = newValue.containerSize
            }
    }

    private struct ScrollGeo: Equatable {
        var offset: CGFloat
        var contentSize: CGFloat
        var containerSize: CGFloat
    }
}
