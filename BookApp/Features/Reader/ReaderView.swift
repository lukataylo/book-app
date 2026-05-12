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
    @State private var toastTask: Task<Void, Never>?
    @State private var persistTask: Task<Void, Never>?
    @State private var mode: ReaderMode = .read
    // Speed-mode inline state
    @State private var speedWordIndex: Int = 0
    @State private var speedParagraphIndex: Int = 0
    @State private var speedIsRunning: Bool = false
    @State private var speedTickerTask: Task<Void, Never>?
    @State private var speedSettings = SpeedReaderSettings()
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
                    viewModel?.sheet = .search
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(textColor.opacity(0.85))
                }
                .accessibilityLabel("Search in book")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel?.sheet = .markings
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(textColor.opacity(0.85))
                }
                .accessibilityLabel("Highlights and bookmarks")
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
        .onDisappear {
            stats.stop()
            // Speed mode is a foreground-only ticker (it scrolls the
            // reader). Without this, popping the reader leaves the task
            // running against orphaned `@State` storage and the next
            // open of a book gets a stuttering scroll from the ghost
            // ticker mutating viewModel.currentParagraph.
            stopSpeedTicker()
            // Cancel debounced background tasks that captured this
            // reader's session — leaving them running risks writing the
            // previous book's progress over the next reader's state, or
            // racing against a fresh `currentParagraph` value the user
            // hasn't actually scrolled to.
            persistTask?.cancel()
            persistTask = nil
            toastTask?.cancel()
            toastTask = nil
        }
    }

    @ViewBuilder
    private func content(viewModel: ReaderViewModel) -> some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: settings.paragraphSpacing) {
                        ForEach(viewModel.blocks.indices, id: \.self) { idx in
                            blockView(
                                viewModel.blocks[idx].block,
                                isFirstAfterHeading: viewModel.blocks[idx].firstAfterHeading,
                                paragraphIndex: idx
                            )
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
                }
                .modifier(PagingModifier(enabled: settings.paginatedScroll))
                // Single source of truth for content/viewport sizes —
                // `onScrollGeometryChange` already fires whenever the
                // layout settles, so the previous `ContentHeightKey` +
                // GeometryReader pipeline was redundant work and produced
                // "Bound preference … updated multiple times per frame"
                // log spam.
                .scrollPositionTracking(
                    progress: $scrollProgress,
                    container: $viewportHeight,
                    contentHeight: $contentHeight
                )
                .scrollPosition($scrollPosition)
                .onChange(of: viewModel.currentParagraph) { _, newValue in
                    // Animated scroll for user-driven jumps (chapter list,
                    // search result tap, bookmark navigation). NOT used by
                    // speed mode — that has its own un-animated scroll
                    // hook on `speedParagraphIndex` because animating 5-20
                    // scrolls per second monopolises the gesture system
                    // and locks the tab pill against taps.
                    guard mode != .speed else { return }
                    withAnimation { proxy.scrollTo(newValue, anchor: .top) }
                }
                .onChange(of: speedParagraphIndex) { _, newValue in
                    // Direct scroll, no animation — keeps the gesture
                    // recogniser responsive while the ticker fires.
                    guard mode == .speed else { return }
                    proxy.scrollTo(newValue, anchor: .top)
                }
                .onChange(of: ttsEngine.currentSourceParagraph) { _, newValue in
                    // Follow narration: when the engine moves to the next
                    // paragraph, animate-scroll the body so the highlighted
                    // paragraph stays roughly under the user's eye.
                    guard mode == .listen, let newValue else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .onAppear {
                    // Restore the last-read paragraph. Resume targets set
                    // by ReaderViewModel.init are silent — `.onChange`
                    // doesn't fire for the initial value, so we drive the
                    // scroll explicitly. Without animation the user lands
                    // there immediately rather than watching a 200-paragraph
                    // scroll roll past.
                    let target = viewModel.currentParagraph
                    if target > 0 {
                        DispatchQueue.main.async {
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
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
            case .search:
                SearchInBookSheet(paragraphs: viewModel.paragraphs) { idx in
                    viewModel.currentParagraph = idx
                }
                .presentationDetents([.medium, .large])
            case .markings:
                MarkingsSheet(book: book) { idx in
                    viewModel.currentParagraph = idx
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Block model
    //
    // The block list (paragraph / heading / image classification + the
    // first-after-heading flag) lives on `ReaderViewModel` so it isn't
    // recomputed on every body re-render. The reader's body re-runs on
    // every settings tick (font size, line spacing, theme…), and rebuilding
    // the block list each time was the dominant cost when adjusting type
    // with a long book loaded.

    @ViewBuilder
    private func blockView(_ block: ReaderBlock, isFirstAfterHeading: Bool, paragraphIndex: Int?) -> some View {
        switch block {
        case .heading(let text):
            Text(text)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(textColor)
                .padding(.top, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xs)
        case .image(let filename):
            inlineImage(filename: filename)
        case .paragraph(let text):
            paragraphView(text: text,
                          isFirstAfterHeading: isFirstAfterHeading,
                          paragraphIndex: paragraphIndex)
        }
    }

    /// Two rendering paths so the common case stays fast:
    ///
    /// - **Plain.** Most paragraphs, most of the time. We hand SwiftUI a
    ///   `Text(text)` with `.font` and `.foregroundStyle` modifiers; no
    ///   `AttributedString` allocation, no per-character iteration.
    /// - **Attributed.** Used only when the paragraph needs the drop cap
    ///   or is the active speed-reader paragraph (which paints a
    ///   per-word highlight). Both of those genuinely need
    ///   `AttributedString`, so we eat the cost — but only there.
    @ViewBuilder
    private func paragraphView(text: String,
                               isFirstAfterHeading: Bool,
                               paragraphIndex: Int?) -> some View {
        let needsDropCap = isFirstAfterHeading && settings.dropCaps
        let isActiveSpeedPara = mode == .speed && paragraphIndex == speedParagraphIndex
        let isActiveListenPara = mode == .listen
            && paragraphIndex != nil
            && paragraphIndex == ttsEngine.currentSourceParagraph
        let needsAttributed = needsDropCap || isActiveSpeedPara || isActiveListenPara

        Group {
            if needsAttributed {
                Text(paragraphAttributed(
                    text,
                    dropCap: needsDropCap,
                    paragraphIndex: paragraphIndex,
                    isActiveListenPara: isActiveListenPara
                ))
            } else {
                Text(text)
                    .font(Typography.reader(settings.font, size: settings.fontSize))
                    .foregroundStyle(paragraphForeground)
            }
        }
        .lineSpacing((settings.lineSpacing - 1) * settings.fontSize)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .contextMenu {
            Button {
                saveAnnotation(text: text)
            } label: {
                Label("Highlight", systemImage: "highlighter")
            }
            Button {
                if let idx = paragraphIndex {
                    saveBookmark(text: text, paragraphIndex: idx)
                }
            } label: {
                Label("Bookmark", systemImage: "bookmark")
            }
            Button {
                UIPasteboard.general.string = text
            } label: {
                Label("Copy paragraph", systemImage: "doc.on.doc")
            }
        }
    }

    /// Foreground for a non-active paragraph in the current mode. Speed
    /// mode dims everything that isn't the cursor's paragraph; everything
    /// else gets full text colour.
    private var paragraphForeground: Color {
        mode == .speed ? textColor.opacity(0.40) : textColor
    }

    /// Render an inline EPUB image extracted on import. Goes through
    /// `InlineFigureImage`, which decodes the JPEG on a background task
    /// (preparingForDisplay can hang the main thread for 50–200 ms on
    /// older devices). Layout reserves space the moment the figure block
    /// is reached so the surrounding paragraphs don't jump when the
    /// bitmap arrives.
    @ViewBuilder
    private func inlineImage(filename: String) -> some View {
        let url = BookStore.shared.imagesFolder(for: book.id, create: false)
            .appendingPathComponent(filename)
        InlineFigureImage(url: url)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.vertical, Theme.Spacing.s)
            .accessibilityLabel("Figure")
    }

    /// Build the paragraph as an `AttributedString` so the body font, drop
    /// cap, and the speed-mode word/paragraph highlight share one `Text`.
    private func paragraphAttributed(_ text: String,
                                     dropCap: Bool,
                                     paragraphIndex: Int?,
                                     isActiveListenPara: Bool) -> AttributedString {
        var attr = AttributedString(text)
        attr.font = Typography.reader(settings.font, size: settings.fontSize)

        // Speed-mode dimming: paragraphs that aren't currently active fade
        // back so the eye lands on the cursor's paragraph.
        let inSpeed = mode == .speed
        let isActiveSpeedPara = inSpeed && paragraphIndex == speedParagraphIndex
        attr.foregroundColor = inSpeed
            ? (isActiveSpeedPara ? textColor : textColor.opacity(0.40))
            : textColor

        if dropCap, !text.isEmpty {
            let firstStart = attr.startIndex
            let firstEnd   = attr.index(firstStart, offsetByCharacters: 1)
            attr[firstStart..<firstEnd].font = .system(
                size: settings.fontSize * 2.4,
                weight: .semibold,
                design: .serif
            )
        }

        // Highlight the active word within the active paragraph.
        if isActiveSpeedPara {
            applySpeedWordHighlight(to: &attr, in: text)
        }
        if isActiveListenPara {
            applyListenWordHighlight(to: &attr, in: text)
        }

        return attr
    }

    /// Highlight the substring AVSpeechSynthesizer is currently speaking
    /// (reported via `currentRange`, in UTF-16 units relative to the
    /// engine's `currentText`). The reader's body text is identical to the
    /// engine's spoken text for this paragraph because both come from the
    /// same source string with `# ` headings stripped.
    private func applyListenWordHighlight(to attr: inout AttributedString, in source: String) {
        let range = ttsEngine.currentRange
        guard range.length > 0 else { return }
        // Engine reports the range against `currentText`; only highlight
        // when the body paragraph matches what's actually being spoken.
        // (Avoids painting a stale highlight on the previous paragraph
        // during the brief moment between paragraphs.)
        guard ttsEngine.currentText == source,
              let stringRange = Range(range, in: source),
              let attrStart = AttributedString.Index(stringRange.lowerBound, within: attr),
              let attrEnd = AttributedString.Index(stringRange.upperBound, within: attr)
        else { return }
        let attrRange = attrStart..<attrEnd
        // User-configured highlight (default: warm yellow). Force a near-
        // black foreground so the spoken word stays readable on the
        // tinted background regardless of the page theme.
        attr[attrRange].backgroundColor = Color(hex: ttsEngine.highlightColorHex)
        attr[attrRange].foregroundColor = Color(hex: "111111")
    }

    /// Walk the source string by whitespace boundaries and tag the word at
    /// `speedWordIndex` with a tinted background so the reader's eye
    /// follows along.
    private func applySpeedWordHighlight(to attr: inout AttributedString, in source: String) {
        var seen = 0
        var cursor = source.startIndex
        while cursor < source.endIndex {
            while cursor < source.endIndex, source[cursor].isWhitespace {
                cursor = source.index(after: cursor)
            }
            guard cursor < source.endIndex else { break }
            let wordStart = cursor
            while cursor < source.endIndex, !source[cursor].isWhitespace {
                cursor = source.index(after: cursor)
            }
            if seen == speedWordIndex {
                if let attrStart = AttributedString.Index(wordStart, within: attr),
                   let attrEnd   = AttributedString.Index(cursor,    within: attr) {
                    let range = attrStart..<attrEnd
                    attr[range].backgroundColor = textColor.opacity(0.18)
                    attr[range].foregroundColor = textColor
                }
                return
            }
            seen += 1
        }
    }

    // MARK: - Save actions

    /// Defer a SwiftData save to the next runloop tick so the in-flight
    /// gesture (highlight / bookmark / annotation) sees the toast and the
    /// context-menu dismiss animation *before* CloudKit's sync flush blocks
    /// the main actor for 50–300ms. The SwiftData model context is itself
    /// MainActor-bound so we can't move it off the main thread; what we
    /// can do is yield once so SwiftUI gets a chance to commit the frame
    /// first.
    private func deferredSave() {
        Task { @MainActor in
            await Task.yield()
            try? modelContext.save()
        }
    }

    private func saveLearning(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let learning = KeyLearning(
            book: book,
            text: String(trimmed.prefix(500)),
            chapterRef: currentChapterTitle(),
            userEdited: true
        )
        modelContext.insert(learning)
        deferredSave()
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
        deferredSave()
        showToast("Highlight saved")
    }

    private func saveBookmark(text: String, paragraphIndex: Int) {
        let snippet = String(text.prefix(140))
        let bm = Bookmark(
            book: book,
            variantID: viewModel?.currentVariant.id,
            paragraphIndex: paragraphIndex,
            label: "",
            snippet: snippet
        )
        modelContext.insert(bm)
        deferredSave()
        showToast("Bookmarked")
    }

    private func currentChapterTitle() -> String {
        guard let vm = viewModel else { return "" }
        let chapters = vm.chapters
        guard !chapters.isEmpty else { return "" }
        let current = max(0, vm.currentParagraph)
        return chapters.last(where: { $0.paragraphIndex <= current })?.title ?? ""
    }

    /// Debounced reading-progress persist. Cancels any in-flight write and
    /// queues a fresh one 600ms in the future. The locator is a paragraph
    /// index (`para:<n>`) rather than a scroll percent so a future open
    /// of this book lands on the exact paragraph the user was reading,
    /// even when the variant has been re-rendered at a different font
    /// size or margin.
    private func schedulePersistProgress(percent: Double) {
        guard let vm = viewModel else { return }
        persistTask?.cancel()
        let pct = max(0, min(1, percent))
        // Best-estimate paragraph from the visible scroll position. The
        // first paragraph at or above the viewport's top is a reasonable
        // resume target; this matches what the on-change scroll already
        // anchors to.
        let paragraph = max(0, currentVisibleParagraphIndex(viewModel: vm))
        persistTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            vm.updateProgress(
                percent: pct,
                locator: "para:\(paragraph)",
                in: modelContext
            )
        }
    }

    private func showToast(_ message: String) {
        // Cancel any in-flight dismiss task — rapid highlights would
        // otherwise pile up overlapping 1.5s sleepers, each of which still
        // ends up calling `savedToast = nil` and clobbering newer toasts.
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) { savedToast = message }
        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { savedToast = nil }
        }
    }

    // MARK: - TTS controls

    /// Tap on Listen — reuse the user's saved voice + rate + pitch + sleep
    /// timer rather than starting from blank defaults each time.
    private func toggleListen(viewModel: ReaderViewModel) {
        let saved = SettingsStore.shared.tts(in: modelContext)
        ttsEngine.configure(settings: saved)
        ttsEngine.configureNowPlaying(
            title: book.title,
            author: book.author,
            coverData: book.coverData
        )
        let bookID = book.id
        let variantID = viewModel.currentVariant.id
        ttsEngine.onParagraphChange = { [ttsEngine] _ in
            ttsEngine.persistResumePoint(bookID: bookID, variantID: variantID)
        }
        ttsEngine.togglePlayback(
            bookID: bookID,
            variantID: variantID,
            paragraphs: viewModel.paragraphs
        )
        // Capture the resume point once now too — the listener only fires on
        // paragraph *changes*, not on the initial start.
        ttsEngine.persistResumePoint(bookID: bookID, variantID: variantID)
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

            VStack(spacing: 8) {
                // Three-tab mode pill — always visible. Each tab switches the
                // reader into Read / Speed / Listen and triggers the right
                // side-effect (start/stop TTS, start the speed ticker, etc.).
                ModeTabPill(mode: $mode, isDark: isDark)
                    .padding(.horizontal, 18)
                    .onChange(of: mode) { _, newMode in
                        applyModeChange(to: newMode, viewModel: viewModel)
                    }

                // Speed and Listen modes need their own full-width row of
                // controls. Read mode doesn't — its progress indicator gets
                // tucked inline with the secondary row below to save height.
                if mode != .read {
                    modeControls(viewModel: viewModel, isDark: isDark)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                }

                // Compact secondary row. In Read mode the leading slot is the
                // progress indicator; in Speed / Listen it's a Spacer.
                HStack(spacing: 14) {
                    if mode == .read {
                        progressRegion(isPlaying: false)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer(minLength: 0)
                    }
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
                }
                .padding(.horizontal, 18)
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
            speedControls(viewModel: viewModel, isDark: isDark)
        case .listen:
            listenControls(viewModel: viewModel, isDark: isDark)
        }
    }

    /// Inline speed-reading controls — the reader page above keeps showing
    /// the text with the active paragraph + word highlighted, auto-scrolling
    /// at the chosen WPM. No full-screen sheet takeover.
    @ViewBuilder
    private func speedControls(viewModel: ReaderViewModel, isDark: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text("\(speedSettings.wpm)")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(textColor)
                    .monospacedDigit()
                Text("words / min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(textColor.opacity(0.55))

                Spacer(minLength: 6)

                // Quick presets — tap-and-go.
                ForEach([300, 500, 800], id: \.self) { wpm in
                    Button {
                        speedSettings.wpm = wpm
                        persistSpeedSettings()
                    } label: {
                        Text("\(wpm)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(
                                    speedSettings.wpm == wpm
                                        ? textColor.opacity(0.10)
                                        : .clear
                                )
                            )
                            .overlay(
                                Capsule().stroke(textColor.opacity(0.18), lineWidth: 0.5)
                            )
                            .foregroundStyle(textColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 16) {
                // Live WPM slider — snaps to 25.
                Slider(
                    value: Binding(
                        get: { Double(speedSettings.wpm) },
                        set: {
                            speedSettings.wpm = Int(($0 / 25).rounded()) * 25
                            persistSpeedSettings()
                        }
                    ),
                    in: 150...1200,
                    step: 25
                )
                .tint(textColor)

                Spacer(minLength: 2)

                Button {
                    rewindSpeedSentence()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isDark ? Color.white : Color.black)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button {
                    if speedIsRunning { stopSpeedTicker() }
                    else { startSpeedTicker(viewModel: viewModel) }
                } label: {
                    Image(systemName: speedIsRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isDark ? Color.black : Color.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(isDark ? Color.white : Color.black))
                }
                .buttonStyle(.plain)

                Button {
                    skipSpeedForward(viewModel: viewModel)
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isDark ? Color.white : Color.black)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func listenControls(viewModel: ReaderViewModel, isDark: Bool) -> some View {
        VStack(spacing: 8) {
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
                    ttsEngine.togglePlayback(
                        bookID: book.id,
                        variantID: viewModel.currentVariant.id,
                        paragraphs: viewModel.paragraphs
                    )
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
            stopSpeedTicker()
        case .listen:
            stopSpeedTicker()
            // Start narration when nothing is playing, or when the engine
            // is mid-narration for a *different* book — without the second
            // check, popping back to the library and opening another book
            // would leave the Listen tab pointing at the previous book.
            let bookID = book.id
            let variantID = viewModel.currentVariant.id
            if !ttsEngine.isPlaying || !ttsEngine.isLoadedFor(bookID: bookID, variantID: variantID) {
                toggleListen(viewModel: viewModel)
            }
        case .speed:
            if ttsEngine.isPlaying { ttsEngine.pause() }
            ensureSpeedSettings()
            // Anchor the speed cursor to the paragraph the user is roughly
            // looking at right now so they don't get yanked back to the top.
            speedParagraphIndex = currentVisibleParagraphIndex(viewModel: viewModel)
            speedWordIndex = 0
            startSpeedTicker(viewModel: viewModel)
        }
    }

    // MARK: - Speed mode

    private func ensureSpeedSettings() {
        speedSettings = SettingsStore.shared.speed(in: modelContext)
    }

    private func persistSpeedSettings() {
        // Slider changes fire many times per drag — debounce-ish: just queue
        // the save off the immediate render path.
        Task { @MainActor in
            try? modelContext.save()
        }
    }

    private func currentVisibleParagraphIndex(viewModel: ReaderViewModel) -> Int {
        let count = viewModel.paragraphs.count
        guard count > 0 else { return 0 }
        let pct = scrollProgress.clamped()
        return min(count - 1, max(0, Int(pct * Double(count))))
    }

    private func startSpeedTicker(viewModel: ReaderViewModel) {
        speedTickerTask?.cancel()
        speedIsRunning = true
        // Capture the paragraph list locally so the closure isn't reaching
        // back into the view's identity on every tick.
        let paragraphs = viewModel.paragraphs
        guard !paragraphs.isEmpty else {
            speedIsRunning = false
            return
        }
        speedTickerTask = Task { @MainActor in
            while speedIsRunning && !Task.isCancelled {
                let baseIntervalMs = 60_000 / max(60, speedSettings.wpm)
                var dwellMs = baseIntervalMs
                let word = currentSpeedWord(in: paragraphs)
                if speedSettings.pauseAtPunctuation {
                    if word.hasSuffix(",") || word.hasSuffix(";") { dwellMs += speedSettings.commaPauseMS }
                    if word.hasSuffix(".") || word.hasSuffix("?") || word.hasSuffix("!") { dwellMs += speedSettings.periodPauseMS }
                }
                // Clamp before the UInt64 conversion: a negative dwell
                // (corrupted SwiftData / user-set zero pause values plus
                // a weird wpm) would trap on UInt64(negative).
                let safeDwellMs = max(16, dwellMs)
                try? await Task.sleep(nanoseconds: UInt64(safeDwellMs) * 1_000_000)
                guard !Task.isCancelled else { break }
                advanceSpeedWord(in: paragraphs)
            }
        }
    }

    private func stopSpeedTicker() {
        speedTickerTask?.cancel()
        speedTickerTask = nil
        speedIsRunning = false
    }

    private func currentSpeedWord(in paragraphs: [String]) -> String {
        guard let paragraph = paragraphs[safe: speedParagraphIndex] else { return "" }
        let words = paragraph.split(whereSeparator: { $0.isWhitespace })
        return words[safe: speedWordIndex].map(String.init) ?? ""
    }

    private func advanceSpeedWord(in paragraphs: [String]) {
        guard let paragraph = paragraphs[safe: speedParagraphIndex] else {
            speedIsRunning = false
            return
        }
        let words = paragraph.split(whereSeparator: { $0.isWhitespace })
        if speedWordIndex + 1 < words.count {
            speedWordIndex += 1
            return
        }
        // End of paragraph — advance to the next non-empty one. Skip
        // headings and inline-image marker paragraphs, neither of which
        // are read aloud or word-stepped.
        var nextIdx = speedParagraphIndex + 1
        while nextIdx < paragraphs.count {
            let candidate = paragraphs[nextIdx]
            let isImage = candidate.hasPrefix("[img:") && candidate.hasSuffix("]")
            if candidate.split(whereSeparator: { $0.isWhitespace }).isEmpty == false
                && !candidate.hasPrefix("# ")
                && !isImage {
                break
            }
            nextIdx += 1
        }
        if nextIdx < paragraphs.count {
            speedParagraphIndex = nextIdx
            speedWordIndex = 0
            // The dedicated `.onChange(of: speedParagraphIndex)` handler
            // in `content(viewModel:)` un-animatedly scrolls the new
            // paragraph into view. We deliberately do NOT also write to
            // `viewModel.currentParagraph` here — doing that fired the
            // animated scroll handler 5-20 times per second, which
            // hijacked SwiftUI's gesture system and made the mode-tab
            // pill unresponsive once Speed was running.
        } else {
            speedIsRunning = false
        }
    }

    private func skipSpeedForward(viewModel: ReaderViewModel) {
        let paragraphs = viewModel.paragraphs
        guard !paragraphs.isEmpty else { return }
        var nextIdx = speedParagraphIndex + 1
        while nextIdx < paragraphs.count {
            let p = paragraphs[nextIdx]
            let isImage = p.hasPrefix("[img:") && p.hasSuffix("]")
            if p.hasPrefix("# ") || isImage {
                nextIdx += 1
            } else {
                break
            }
        }
        guard nextIdx < paragraphs.count else { return }
        speedParagraphIndex = nextIdx
        speedWordIndex = 0
        // Scroll happens via the dedicated speedParagraphIndex onChange.
    }

    private func rewindSpeedSentence() {
        guard let vm = viewModel else { return }
        let words = vm.paragraphs[safe: speedParagraphIndex]?
            .split(whereSeparator: { $0.isWhitespace }) ?? []
        var i = min(speedWordIndex - 1, words.count - 1)
        while i > 0, let w = words[safe: i].map(String.init) {
            if w.hasSuffix(".") || w.hasSuffix("?") || w.hasSuffix("!") { break }
            i -= 1
        }
        if i <= 0, speedParagraphIndex > 0 {
            speedParagraphIndex -= 1
            speedWordIndex = 0
            // Scroll happens via the dedicated speedParagraphIndex onChange.
        } else {
            speedWordIndex = max(0, i)
        }
        _ = vm  // viewModel is still required to compute `paragraphs` above
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
        // Settings are app-wide singletons; SettingsStore caches the
        // resolved instance so repeated reader opens don't pay the
        // FetchDescriptor cost.
        settings = SettingsStore.shared.reader(in: modelContext)
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
        container: Binding<CGFloat>,
        contentHeight: Binding<CGFloat>
    ) -> some View {
        self.modifier(ScrollProgressModifier(
            progress: progress,
            container: container,
            contentHeight: contentHeight
        ))
    }
}

private struct ScrollProgressModifier: ViewModifier {
    @Binding var progress: Double
    @Binding var container: CGFloat
    @Binding var contentHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: ScrollGeo.self) { geo in
                ScrollGeo(
                    offset: geo.contentOffset.y,
                    contentSize: geo.contentSize.height,
                    containerSize: geo.containerSize.height
                )
            } action: { _, newValue in
                // Equality guard the bindings — SwiftUI fires
                // onScrollGeometryChange whenever any of the three values
                // change, but we only need to push back what's actually
                // different. Without this guard, paging through a long
                // book triggered redundant state-write storms that
                // surfaced as "multiple times per frame" warnings.
                let total = max(1, newValue.contentSize - newValue.containerSize)
                let nextProgress = Double(newValue.offset) / Double(total)
                if abs(progress - nextProgress) > 0.0005 {
                    progress = nextProgress
                }
                if container != newValue.containerSize {
                    container = newValue.containerSize
                }
                if contentHeight != newValue.contentSize {
                    contentHeight = newValue.contentSize
                }
            }
    }

    private struct ScrollGeo: Equatable {
        var offset: CGFloat
        var contentSize: CGFloat
        var containerSize: CGFloat
    }
}
