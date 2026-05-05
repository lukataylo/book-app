import SwiftUI
import SwiftData

/// "AI" entry point from the reader's bottom bar. Drives the full
/// transformation flow: pick mode → set parameters → confirm cost → run with
/// per-chunk progress → open the new variant.
struct TransformationStudioView: View {
    let book: Book
    let sourceVariant: BookVariant

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var kind: VariantKind = .compressed
    @State private var targetPages: Double = 20
    @State private var styleReference: String = ""
    @State private var omittedThemes: [String] = []
    @State private var modelOverride: LLMModel?
    @State private var estimate: CostEstimate?
    @State private var progress: TransformationProgress?
    @State private var isRunning: Bool = false
    @State private var errorText: String?

    private let engine = TransformationEngine()

    var body: some View {
        NavigationStack {
            Form {
                kindSection
                if kind == .compressed || kind == .expanded {
                    lengthSection
                }
                if kind == .styled {
                    styleSection
                }
                themesSection
                modelSection
                if let estimate {
                    estimateSection(estimate)
                }
                if let progress {
                    progressSection(progress)
                }
                runSection
            }
            .navigationTitle("Transform")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Couldn't transform", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
            .onAppear { recomputeEstimate() }
            .onChange(of: kind)             { _, _ in recomputeEstimate() }
            .onChange(of: targetPages)      { _, _ in recomputeEstimate() }
            .onChange(of: styleReference)   { _, _ in recomputeEstimate() }
            .onChange(of: omittedThemes)    { _, _ in recomputeEstimate() }
            .onChange(of: modelOverride)    { _, _ in recomputeEstimate() }
        }
    }

    private var kindSection: some View {
        Section("Mode") {
            Picker("Kind", selection: $kind) {
                Text("Compress").tag(VariantKind.compressed)
                Text("Expand").tag(VariantKind.expanded)
                Text("Re-style").tag(VariantKind.styled)
                Text("Omit themes").tag(VariantKind.themeOmitted)
            }
            .pickerStyle(.segmented)
        }
    }

    private var lengthSection: some View {
        Section("Target length") {
            HStack {
                Text("\(Int(targetPages)) pages")
                Slider(value: $targetPages, in: 10...max(20, Double(book.totalPagesEstimate) * 4), step: 5)
            }
            Text("Original is ~\(book.totalPagesEstimate) pages.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var styleSection: some View {
        Section("Style reference") {
            TextField("Author or book to mimic (e.g. Malcolm Gladwell)", text: $styleReference)
            Text("The model will rewrite every passage in this voice while keeping every key idea.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var themesSection: some View {
        if !book.detectedThemes.isEmpty {
            Section("Omit themes") {
                ForEach(book.detectedThemes, id: \.self) { theme in
                    Toggle(theme, isOn: Binding(
                        get: { omittedThemes.contains(theme) },
                        set: { newValue in
                            if newValue { omittedThemes.append(theme) }
                            else { omittedThemes.removeAll { $0 == theme } }
                        }
                    ))
                }
            }
        }
    }

    private var modelSection: some View {
        Section("Model") {
            Picker("Use", selection: $modelOverride) {
                Text("Auto").tag(Optional<LLMModel>.none)
                Text("Sonnet 4.6").tag(Optional(LLMModel.claudeSonnet4_6))
                Text("Opus 4.7").tag(Optional(LLMModel.claudeOpus4_7))
                Text("Haiku 4.5").tag(Optional(LLMModel.claudeHaiku4_5))
                Text("On-device").tag(Optional(LLMModel.appleFoundation))
            }
        }
    }

    private func estimateSection(_ e: CostEstimate) -> some View {
        Section("Estimate") {
            row("Chunks", "\(e.chunkCount)")
            row("Input tokens", "\(e.inputTokens)")
            row("Output tokens (est)", "\(e.estOutputTokens)")
            row("Model", e.model.displayName)
            row("Cost (est)", String(format: "$%.3f", e.usd))
        }
    }

    private func progressSection(_ p: TransformationProgress) -> some View {
        Section("Progress") {
            row("Phase", "\(p.phase)")
            row("Chunk", "\(p.chunkIndex)/\(p.chunkCount)")
            row("Cost so far", String(format: "$%.3f", p.costUSD))
            ProgressView(value: Double(p.chunkIndex), total: Double(max(1, p.chunkCount)))
        }
    }

    private var runSection: some View {
        Section {
            Button {
                Task { await run() }
            } label: {
                HStack {
                    Spacer()
                    if isRunning {
                        ProgressView()
                    } else {
                        Text("Generate variant")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .disabled(isRunning)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    private var ratio: Double {
        guard book.totalPagesEstimate > 0 else { return 1 }
        return targetPages / Double(book.totalPagesEstimate)
    }

    private var request: TransformationRequest {
        TransformationRequest(
            kind: kind,
            targetRatio: ratio,
            styleReference: styleReference,
            omittedThemes: omittedThemes,
            modelOverride: modelOverride
        )
    }

    private func recomputeEstimate() {
        estimate = engine.estimate(source: sourceVariant.contentText, request: request)
    }

    private func run() async {
        isRunning = true
        defer { isRunning = false }
        do {
            _ = try await engine.run(
                on: book,
                sourceText: sourceVariant.contentText,
                sourceVariant: sourceVariant,
                request: request,
                context: modelContext,
                progress: { p in self.progress = p }
            )
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
