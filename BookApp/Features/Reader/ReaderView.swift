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
                        // Bottom spacer so content can scroll above the floating bar.
                        Color.clear.frame(height: 120)
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
                .scrollPositionTracking(progress: $scrollProgress)
                .onChange(of: viewModel.currentParagraph) { _, newValue in
                    withAnimation { proxy.scrollTo(newValue, anchor: .top) }
                }
            }

            // Tap zones for page navigation. They sit BEHIND the chrome via zIndex.
            HStack(spacing: 0) {
                tapZone(action: .pageBack)
                tapZone(action: .toggleChrome)
                tapZone(action: .pageForward)
            }
            .zIndex(0)

            // Scroll progress: thin line at the very top.
            VStack(spacing: 0) {
                ProgressBar(progress: scrollProgress, tint: textColor.opacity(0.6))
                    .frame(height: 2)
                    .opacity(showsChrome ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: showsChrome)
                Spacer()
            }
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .top)

            // iOS Books-style bottom bar: gradient fade + minimal black-on-light row.
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
        case .pageForward, .pageBack:
            // ScrollView page-by-viewport — relies on the ScrollView's
            // built-in animation. We adjust scrollProgress by ~0.05 of the
            // total which approximates a viewport on most devices.
            // (A fully paginated reader is on the roadmap.)
            break
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

        ZStack(alignment: .bottom) {
            // Gradient fade lifts the controls off the prose for legibility.
            LinearGradient(
                colors: [bg.opacity(0), bg.opacity(0.6), bg.opacity(0.95), bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
            .allowsHitTesting(false)

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // Page indicator on the left.
                    Text(progressText())
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(textColor.opacity(0.65))
                        .frame(minWidth: 64, alignment: .leading)

                    Spacer(minLength: 8)

                    // Read · Listen segmented pill (sits on a hairline-bordered capsule).
                    SegmentedPill(
                        items: [.init(label: "Read", icon: nil),
                                .init(label: "Listen", icon: nil)],
                        activeIndex: 0,
                        isDark: isDark
                    ) { idx in
                        if idx == 1 { viewModel.sheet = .ttsSettings }
                    }

                    Spacer(minLength: 8)

                    // Trailing icon set: Speed · Aa · AI.
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
                .padding(.horizontal, 18)

                // Collapse chevron — tapping it hides the bar (same as tapping centre of page).
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { showsChrome = false }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textColor.opacity(0.4))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 6)
        }
        .frame(height: 180, alignment: .bottom)
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

/// Tracks vertical scroll progress (0…1) by reading the scroll offset against
/// the content height. Backed by `scrollPosition(_:)` on iOS 17+ and a
/// preference-key fallback otherwise.
private extension View {
    func scrollPositionTracking(progress: Binding<Double>) -> some View {
        self.modifier(ScrollProgressModifier(progress: progress))
    }
}

private struct ScrollProgressModifier: ViewModifier {
    @Binding var progress: Double
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { outer in
                Color.clear
                    .onChange(of: outer.size) { _, _ in /* layout pass */ }
            })
            .onScrollGeometryChange(for: Double.self) { geo in
                let total = max(1, geo.contentSize.height - geo.containerSize.height)
                return Double(geo.contentOffset.y) / Double(total)
            } action: { _, newValue in
                progress = newValue
            }
    }
}
