import SwiftUI
import SwiftData

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
        }
        .statusBarHidden(!showsChrome)
        .preferredColorScheme(settings.theme == .dark || settings.theme == .black ? .dark : .light)
    }

    @ViewBuilder
    private func content(viewModel: ReaderViewModel) -> some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: settings.paragraphSpacing) {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { idx, block in
                            blockView(block)
                                .id(idx)
                        }
                        // Bottom spacer so content can scroll above the bar.
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, settings.margin.horizontalPadding)
                    .padding(.top, Theme.Spacing.l)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ContentHeightKey.self, value: geo.size.height)
                        }
                    )
                }
                .onPreferenceChange(ContentHeightKey.self) { contentHeight = max(1, $0) }
                .scrollPositionTracking(progress: $scrollProgress, container: $viewportHeight)
                .scrollPosition($scrollPosition)
                .onChange(of: viewModel.currentParagraph) { _, newValue in
                    withAnimation { proxy.scrollTo(newValue, anchor: .top) }
                }
            }

            // Tap zones — left pages back one viewport, right pages forward,
            // centre toggles chrome.
            HStack(spacing: 0) {
                tapZone(action: .pageBack)
                tapZone(action: .toggleChrome)
                tapZone(action: .pageForward)
            }
            .zIndex(0)

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
            case .learnings:
                BookLearningsView(book: book)
            }
        }
    }

    // MARK: - Block model

    private enum Block: Hashable {
        case heading(String)
        case paragraph(String)
    }

    private var blocks: [Block] {
        guard let viewModel else { return [] }
        return viewModel.paragraphs.map { p in
            if p.hasPrefix("# ") {
                return .heading(String(p.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            }
            return .paragraph(p)
        }
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading(let text):
            Text(text)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(textColor)
                .padding(.top, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xs)
        case .paragraph(let text):
            Text(text)
                .font(Typography.reader(settings.font, size: settings.fontSize))
                .foregroundStyle(textColor)
                .lineSpacing((settings.lineSpacing - 1) * settings.fontSize)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Tap navigation

    private enum TapAction { case pageBack, toggleChrome, pageForward }

    private func tapZone(action: TapAction) -> some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                handle(action)
            }
    }

    private func handle(_ action: TapAction) {
        switch action {
        case .toggleChrome:
            withAnimation(.easeOut(duration: 0.18)) { showsChrome.toggle() }
        case .pageForward:
            advanceByViewport(forward: true)
        case .pageBack:
            advanceByViewport(forward: false)
        }
    }

    /// Move the scroll position by one viewport (~ a "page"), with animation.
    private func advanceByViewport(forward: Bool) {
        guard let vm = viewModel else { return }
        let total = max(1, contentHeight - viewportHeight)
        let currentY = scrollProgress * Double(total)
        let step = Double(viewportHeight) * 0.92      // ~one viewport, slight overlap
        let nextY = max(0, min(Double(total), currentY + (forward ? step : -step)))
        let nextProgress = nextY / Double(total)
        // Translate progress back to a paragraph index for ScrollViewReader to scroll to.
        let paragraphCount = max(1, vm.paragraphs.count)
        let targetIndex = max(0, min(paragraphCount - 1, Int(nextProgress * Double(paragraphCount))))
        withAnimation(.easeOut(duration: 0.22)) {
            scrollPosition.scrollTo(y: nextY)
            vm.currentParagraph = targetIndex
        }
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
            // Gradient fade lifts the controls off the prose so the bar's
            // contents stay legible regardless of underlying text.
            LinearGradient(
                colors: [bg.opacity(0), bg.opacity(0.55), bg.opacity(0.92), bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 84)
            .allowsHitTesting(false)

            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    // Page indicator on the left.
                    Text(progressText())
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(textColor.opacity(0.6))
                        .frame(minWidth: 56, alignment: .leading)

                    // Read · Listen segmented pill — given enough room that
                    // "Listen" never wraps.
                    SegmentedPill(
                        items: [.init(label: "Read", icon: nil),
                                .init(label: "Listen", icon: nil)],
                        activeIndex: 0,
                        isDark: isDark
                    ) { idx in
                        if idx == 1 { viewModel.sheet = .ttsSettings }
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 6)

                    IconBarButton(systemImage: "bolt.fill", isDark: isDark) {
                        viewModel.sheet = .speedReader
                    }
                    IconBarButton(systemImage: "textformat.size", isDark: isDark) {
                        viewModel.sheet = .readerSettings
                    }
                    IconBarButton(systemImage: "wand.and.stars", isDark: isDark) {
                        viewModel.sheet = .transformations
                    }
                }
                .padding(.horizontal, 14)

                // Tiny collapse chevron — small, unobtrusive.
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { showsChrome = false }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(textColor.opacity(0.4))
                        .frame(width: 36, height: 18)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)
            .background(bg)
        }
    }

    private func progressText() -> String {
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

// MARK: - Bar components

/// Two-state pill segmented control (Read · Listen).
private struct SegmentedPill: View {
    struct Item { let label: String; let icon: String? }
    let items: [Item]
    let activeIndex: Int
    let isDark: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                Button {
                    onSelect(idx)
                } label: {
                    Text(item.label)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .frame(minWidth: 70)
                        .foregroundStyle(
                            idx == activeIndex
                                ? (isDark ? Color.black : Color.white)
                                : (isDark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                        )
                        .background(
                            ZStack {
                                if idx == activeIndex {
                                    Capsule()
                                        .fill(isDark ? Color.white : Color.black)
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

/// Round-icon control with no chrome — used for brightness, Aa, AI.
private struct IconBarButton: View {
    let systemImage: String
    let isDark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isDark ? Color.white.opacity(0.85) : Color.black.opacity(0.75))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .stroke(isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.08), lineWidth: 0.5)
                )
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
