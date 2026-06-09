import SwiftUI
import SwiftData

/// Full-screen transformation studio. Pushed from BookDetailView.
///
/// The user composes a transformation by enabling any combination of:
///   • **Length** — compress to N pages or expand to N pages
///   • **Style**  — rewrite in another author's voice
///   • **Themes** — drop content matching specific themes
///
/// All three are independently toggle-able and run together in a single
/// pipeline (the engine already supports combined directives in
/// `PromptTemplates.transformChunk`).
struct TransformationStudioView: View {
    let book: Book
    let sourceVariant: BookVariant

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Length
    @State private var changeLength: Bool = true
    @State private var targetPages: Double = 20

    // Style
    @State private var changeStyle: Bool = false
    @State private var styleReference: String = ""

    // Themes
    @State private var omitThemes: Bool = false
    @State private var omittedThemes: [String] = []
    @State private var customThemeDraft: String = ""
    @FocusState private var customThemeFieldFocused: Bool

    // Model + run
    @State private var modelOverride: LLMModel?
    @State private var estimate: CostEstimate?
    @State private var progress: TransformationProgress?
    @State private var isRunning: Bool = false
    @State private var errorText: String?
    // Cached chunk count + input tokens — computed once on appear off the
    // main thread so a 280K-char source doesn't block the sheet animation
    // and every typed character of styleReference doesn't re-chunk.
    @State private var cachedInputTokens: Int = 0
    @State private var cachedChunkCount: Int = 0
    @State private var sourceLoading: Bool = true
    /// Filled in on appear from `LocalProvider().isAvailable()`. When true,
    /// "Auto" defaults to Apple FM and the studio shows "Free · on-device".
    @State private var localAvailable: Bool = false
    /// Holds the active run task so Cancel can stop a long on-device run.
    @State private var runTask: Task<Void, Never>?

    @FocusState private var styleFieldFocused: Bool

    private let engine = TransformationEngine()
    private let suggestedAuthors = [
        "Malcolm Gladwell", "Joan Didion", "Hemingway",
        "Susan Sontag", "James Baldwin", "Annie Dillard",
        "Edward Tufte", "Yuval Harari", "Ursula K. Le Guin"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                hero
                lengthSection
                styleSection
                themesSection
                modelSection
                if sourceLoading {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Calculating cost…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .padding(.vertical, 4)
                } else if let estimate {
                    estimateCard(estimate)
                }
                if let progress {
                    progressCard(progress)
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.m)
            .padding(.bottom, 120)   // leaves room for the floating CTA
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.Palette.appBackground.ignoresSafeArea())
        .navigationTitle("Transform")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            runCTA
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.s)
                // Frosted toolbar — content scrolls under glass, the
                // native iOS bar treatment.
                .background(.ultraThinMaterial)
        }
        .alert("Couldn't transform", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
        .task {
            // Detect Apple Intelligence availability before chunking so the
            // chunk size matches the model the engine will pick.
            let provider = LocalProvider()
            let available = await provider.isAvailable()
            await MainActor.run {
                self.localAvailable = available
                self.engine.localAvailableHint = available
            }
            await loadSourceTokens()
        }
        // styleReference and omittedThemes don't affect tokens or pricing —
        // they only flow into the prompt body. We skip recomputing the
        // estimate when those change so typing doesn't thrash any state.
        .onChange(of: changeLength)   { _, _ in recomputeEstimate() }
        .onChange(of: targetPages)    { _, _ in recomputeEstimate() }
        .onChange(of: changeStyle)    { _, _ in recomputeEstimate() }
        .onChange(of: omitThemes)     { _, _ in recomputeEstimate() }
        .onChange(of: modelOverride)  { _, _ in recomputeEstimate() }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(2)
            Text("\(book.totalPagesEstimate) pages · ~\(formatTokens(estimateInputTokens())) tokens")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    // MARK: - Length

    private var lengthSection: some View {
        SectionCard(
            title: "Length",
            subtitle: changeLength ? lengthSummary() : "Keep the original length",
            isOn: $changeLength
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(Int(targetPages)) pages")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Spacer()
                    Text(directionLabel())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Slider(value: $targetPages,
                       in: 10...max(20, Double(book.totalPagesEstimate) * 4),
                       step: 5)
                Text("Original is ~\(book.totalPagesEstimate) pages.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }

    private func lengthSummary() -> String {
        let dir = directionLabel().lowercased()
        return "\(dir) to \(Int(targetPages)) pages"
    }

    private func directionLabel() -> String {
        if Int(targetPages) < book.totalPagesEstimate { return "Compress" }
        if Int(targetPages) > book.totalPagesEstimate { return "Expand" }
        return "Same length"
    }

    // MARK: - Style

    private var styleSection: some View {
        SectionCard(
            title: "Style",
            subtitle: changeStyle && !styleReference.isEmpty
                ? "Sound like \(styleReference)"
                : "Keep the author's voice",
            isOn: $changeStyle
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("e.g. Malcolm Gladwell", text: $styleReference)
                    .focused($styleFieldFocused)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Theme.Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.Palette.divider, lineWidth: 0.5)
                    )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestedAuthors, id: \.self) { name in
                            Button {
                                styleReference = name
                            } label: {
                                Text(name)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(styleReference == name
                                                  ? Theme.Palette.textPrimary.opacity(0.08)
                                                  : .clear)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Theme.Palette.divider, lineWidth: 0.5)
                                    )
                                    .foregroundStyle(Theme.Palette.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 1)
                }

                Text("The rewrite preserves every key idea while matching the chosen voice.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
    }

    // MARK: - Themes

    @ViewBuilder
    private var themesSection: some View {
        // Themes the user typed in themselves — they live only in
        // `omittedThemes` until added to the book. We surface them as
        // chips alongside auto-detected themes so the UX is consistent.
        let detected = book.detectedThemes
        let custom = omittedThemes.filter { !detected.contains($0) }

        SectionCard(
            title: "Omit themes",
            subtitle: omitThemes && !omittedThemes.isEmpty
                ? omittedThemes.joined(separator: ", ")
                : (detected.isEmpty && custom.isEmpty
                   ? "Type any theme you want skipped"
                   : "Keep all themes"),
            isOn: $omitThemes
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if !detected.isEmpty || !custom.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(detected, id: \.self) { theme in
                            themeChip(theme, isCustom: false)
                        }
                        ForEach(custom, id: \.self) { theme in
                            themeChip(theme, isCustom: true)
                        }
                    }
                }
                customThemeField
            }
        }
    }

    @ViewBuilder
    private func themeChip(_ theme: String, isCustom: Bool) -> some View {
        let on = omittedThemes.contains(theme)
        Button {
            if on { omittedThemes.removeAll { $0 == theme } }
            else  { omittedThemes.append(theme) }
        } label: {
            HStack(spacing: 4) {
                if on { Image(systemName: "xmark").font(.system(size: 10, weight: .bold)) }
                Text(theme).font(.system(size: 12, weight: .medium))
                if isCustom {
                    // Pencil hint distinguishes user-typed chips from
                    // auto-detected ones — clarifies that deleting one
                    // from `omittedThemes` makes it disappear entirely.
                    Image(systemName: "pencil")
                        .font(.system(size: 9, weight: .semibold))
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(on ? .white : Theme.Palette.textPrimary)
            .background(
                Capsule().fill(on ? Color.black : Color.clear)
            )
            .overlay(
                Capsule().stroke(
                    on ? Color.black : Theme.Palette.divider,
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var customThemeField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.textSecondary)
            TextField("Add a theme", text: $customThemeDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($customThemeFieldFocused)
                .submitLabel(.done)
                .onSubmit(addCustomTheme)
                .font(.system(size: 13))
            if !customThemeDraft.isEmpty {
                Button("Add", action: addCustomTheme)
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay(
            Capsule().stroke(Theme.Palette.divider, lineWidth: 0.5)
        )
    }

    private func addCustomTheme() {
        let trimmed = customThemeDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Dedupe case-insensitively against both detected + already-added.
        let alreadyKnown = (book.detectedThemes + omittedThemes)
            .contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        if !alreadyKnown {
            omittedThemes.append(trimmed)
        } else if !omittedThemes.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            // Already detected but user re-typed — flip it on.
            if let match = book.detectedThemes.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                omittedThemes.append(match)
            }
        }
        customThemeDraft = ""
        customThemeFieldFocused = true
    }

    // MARK: - Model

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
            HStack {
                Text("Use")
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                Picker("", selection: $modelOverride) {
                    Text("Auto").tag(Optional<LLMModel>.none)
                    Text("Sonnet 4.6").tag(Optional(LLMModel.claudeSonnet4_6))
                    Text("Opus 4.7").tag(Optional(LLMModel.claudeOpus4_7))
                    Text("Haiku 4.5").tag(Optional(LLMModel.claudeHaiku4_5))
                    Text("On-device").tag(Optional(LLMModel.appleFoundation))
                }
                .pickerStyle(.menu)
                .tint(Theme.Palette.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Estimate / progress

    private func estimateCard(_ e: CostEstimate) -> some View {
        let isLocal = e.model.providerID == .foundationModels || e.model.providerID == .mlx
        let estimatedSecs = isLocal ? Double(e.chunkCount) * 8.0 : Double(e.chunkCount) * 1.5
        return VStack(alignment: .leading, spacing: 8) {
            Text("Estimate")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
            VStack(spacing: 0) {
                row("Chunks", "\(e.chunkCount)")
                Divider().background(Theme.Palette.divider)
                row("Input tokens", formatTokens(e.inputTokens))
                Divider().background(Theme.Palette.divider)
                row("Output tokens (est.)", formatTokens(e.estOutputTokens))
                Divider().background(Theme.Palette.divider)
                row("Model", e.model.displayName)
                Divider().background(Theme.Palette.divider)
                row("Time (est.)", formatDuration(estimatedSecs))
                Divider().background(Theme.Palette.divider)
                if isLocal {
                    row("Cost", "Free · on-device", emphasize: true)
                } else {
                    row("Cost (est.)", String(format: "$%.3f", e.usd), emphasize: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Theme.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 60 { return "\(max(1, Int(seconds))) sec" }
        let mins = Int(seconds / 60)
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60
        let m = mins % 60
        return m == 0 ? "\(h) h" : "\(h)h \(m)m"
    }

    private func progressCard(_ p: TransformationProgress) -> some View {
        let modelIsLocal = (estimate?.model.providerID ?? .anthropic) != .anthropic
        return VStack(alignment: .leading, spacing: 10) {
            Text("Running…")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.Palette.textPrimary)
            ProgressView(value: Double(p.chunkIndex), total: Double(max(1, p.chunkCount)))
                .tint(.black)
            HStack {
                Text("chunk \(p.chunkIndex)/\(p.chunkCount)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer()
                if p.estimatedSecondsRemaining > 0 {
                    Text("~\(formatDuration(p.estimatedSecondsRemaining)) left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            HStack {
                if modelIsLocal {
                    Text("Free · on-device")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                } else {
                    Text(String(format: "$%.3f spent", p.costUSD))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                Spacer()
                Button(role: .destructive) {
                    cancelRun()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ label: String, _ value: String, emphasize: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .fontWeight(emphasize ? .semibold : .regular)
                .foregroundStyle(Theme.Palette.textPrimary)
        }
        .font(.system(size: 14))
        .padding(.vertical, 11)
    }

    // MARK: - Run CTA

    private var runCTA: some View {
        Button {
            startRun()
        } label: {
            HStack {
                if isRunning {
                    ProgressView().tint(.white)
                } else {
                    Text(canRun ? generateLabel() : "Enable at least one option")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canRun ? Color.black : Color.black.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canRun || isRunning)
    }

    private func generateLabel() -> String {
        var parts: [String] = []
        if changeLength { parts.append(directionLabel().lowercased()) }
        if changeStyle, !styleReference.isEmpty { parts.append("restyle") }
        if omitThemes, !omittedThemes.isEmpty { parts.append("omit themes") }
        if parts.isEmpty { return "Generate variant" }
        return "Generate · \(parts.joined(separator: " + "))"
    }

    private var canRun: Bool {
        if isRunning { return false }
        let lengthChange = changeLength && Int(targetPages) != book.totalPagesEstimate
        let styleChange  = changeStyle && !styleReference.trimmingCharacters(in: .whitespaces).isEmpty
        let themeChange  = omitThemes && !omittedThemes.isEmpty
        return lengthChange || styleChange || themeChange
    }

    // MARK: - Pipeline glue

    private var ratio: Double {
        guard book.totalPagesEstimate > 0 else { return 1 }
        if !changeLength { return 1 }
        return targetPages / Double(book.totalPagesEstimate)
    }

    private var resolvedKind: VariantKind {
        if changeStyle, !styleReference.isEmpty { return .styled }
        if omitThemes,  !omittedThemes.isEmpty  { return .themeOmitted }
        if changeLength {
            return Int(targetPages) < book.totalPagesEstimate ? .compressed : .expanded
        }
        return .original
    }

    private var transformRequest: TransformationRequest {
        TransformationRequest(
            kind: resolvedKind,
            targetRatio: ratio,
            styleReference: changeStyle ? styleReference : "",
            omittedThemes: omitThemes ? omittedThemes : [],
            modelOverride: modelOverride
        )
    }

    /// One-time chunking pass on the source text. Runs off the main thread
    /// so a long book (~280K tokens for The Republic) doesn't stall the
    /// sheet's appearance animation.
    private func loadSourceTokens() async {
        let source = sourceVariant.contentText
        let result: (tokens: Int, count: Int) = await Task.detached(priority: .userInitiated) {
            let chunks = Chunker.chunk(source)
            let tokens = chunks.reduce(0) { $0 + $1.approxTokens }
            return (tokens, chunks.count)
        }.value
        await MainActor.run {
            self.cachedInputTokens = result.tokens
            self.cachedChunkCount = result.count
            self.sourceLoading = false
            self.recomputeEstimate()
        }
    }

    /// Cheap recompute — uses the cached chunk count + token total, just
    /// updates the price math when length / kind / model selection changes.
    private func recomputeEstimate() {
        guard cachedInputTokens > 0 else { return }
        let req = transformRequest
        let outputTokens = max(1, Int(Double(cachedInputTokens) * req.targetRatio))
        let model = req.modelOverride ?? defaultModelLocal(for: req)
        // Chunk count varies by model context window. Recompute from the
        // cached input-token total rather than re-chunking the source.
        let (maxTok, _) = TransformationEngine.chunkSize(for: model)
        let chunks = max(1, Int((Double(cachedInputTokens) / Double(maxTok)).rounded(.up)))
        let price = model.price
        let usd = (Double(cachedInputTokens) * price.inputPerM
                   + Double(outputTokens) * price.outputPerM) / 1_000_000
        estimate = CostEstimate(
            inputTokens: cachedInputTokens,
            estOutputTokens: outputTokens,
            model: model,
            usd: usd,
            chunkCount: chunks
        )
    }

    /// Apple-Intelligence-aware default. When the device has on-device
    /// inference, all transformations route through it for free. Otherwise
    /// falls back to the cost-aware Claude routing.
    private func defaultModelLocal(for request: TransformationRequest) -> LLMModel {
        if localAvailable { return .appleFoundation }
        switch request.kind {
        case .styled:        return .claudeOpus4_7
        case .expanded where request.targetRatio >= 3: return .claudeOpus4_7
        case .compressed where request.targetRatio >= 0.30: return .appleFoundation
        default:             return .claudeSonnet4_6
        }
    }

    private func estimateInputTokens() -> Int {
        cachedInputTokens > 0 ? cachedInputTokens : Chunker.tokenEstimate(sourceVariant.contentText)
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return "\(n / 1_000)k" }
        return "\(n)"
    }

    private func startRun() {
        runTask?.cancel()
        runTask = Task { @MainActor in
            await run()
        }
    }

    private func cancelRun() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
        progress = nil
    }

    private func run() async {
        isRunning = true
        defer {
            isRunning = false
            runTask = nil
        }
        do {
            _ = try await engine.run(
                on: book,
                sourceText: sourceVariant.contentText,
                sourceVariant: sourceVariant,
                request: transformRequest,
                context: modelContext,
                progress: { p in self.progress = p }
            )
            dismiss()
        } catch is CancellationError {
            errorText = nil
            progress = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - SectionCard

private struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var disabled: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.black)
                    .disabled(disabled)
            }
            if isOn && !disabled {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(Theme.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(disabled ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.18), value: isOn)
    }
}

// MARK: - FlowLayout (chip wrap)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
