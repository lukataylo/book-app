import SwiftUI

struct ReaderSettingsSheet: View {
    /// `@Bindable` is the right wrapper for `@Observable` (`@Model`) classes
    /// — `$settings.theme` produces a `Binding<ReaderTheme>` that SwiftUI
    /// correctly observes for re-render. `@Binding` would compare class
    /// identity, miss property changes, and leave the UI stale.
    @Bindable var settings: ReaderSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Background", selection: $settings.theme) {
                        ForEach(ReaderTheme.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.theme) { _, _ in persist() }
                }
                Section("Font") {
                    Picker("Family", selection: $settings.font) {
                        ForEach(ReaderFont.allCases, id: \.self) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    .onChange(of: settings.font) { _, _ in persist() }

                    Stepper(
                        "Size: \(Int(settings.fontSize)) pt",
                        value: $settings.fontSize,
                        in: 12...28,
                        step: 1,
                        onEditingChanged: { _ in persist() }
                    )
                }
                Section("Layout") {
                    Picker("Margin", selection: $settings.margin) {
                        ForEach(ReaderMargin.allCases, id: \.self) { m in
                            Text(m.rawValue.capitalized).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.margin) { _, _ in persist() }

                    HStack {
                        Text("Line spacing")
                        Slider(value: $settings.lineSpacing, in: 1.0...2.0, step: 0.1, onEditingChanged: { _ in persist() })
                        Text(String(format: "%.1f", settings.lineSpacing))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Paragraph gap")
                        Slider(value: $settings.paragraphSpacing, in: 4...32, step: 2, onEditingChanged: { _ in persist() })
                        Text("\(Int(settings.paragraphSpacing))")
                            .monospacedDigit()
                    }

                    Toggle("Hyphenation", isOn: $settings.hyphenation)
                        .onChange(of: settings.hyphenation) { _, _ in persist() }

                    Toggle("Drop caps at chapter starts", isOn: $settings.dropCaps)
                        .onChange(of: settings.dropCaps) { _, _ in persist() }
                }
                Section("Reading style") {
                    Picker("Style", selection: Binding(
                        get: { settings.paginatedScroll ? "page" : "scroll" },
                        set: { settings.paginatedScroll = $0 == "page"; persist() }
                    )) {
                        Text("Continuous scroll").tag("scroll")
                        Text("Page-by-page").tag("page")
                    }
                    .pickerStyle(.segmented)
                    Text(settings.paginatedScroll
                         ? "Each scroll snaps to the next viewport — like turning a page."
                         : "Read at your own pace; the position bar tracks your place in the book.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Bottom indicator") {
                    Picker("Show", selection: $settings.progressIndicator) {
                        ForEach(ProgressIndicatorStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.progressIndicator) { _, _ in persist() }
                    Text(progressHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Reader settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func persist() {
        try? modelContext.save()
    }

    private var progressHelpText: String {
        switch settings.progressIndicator {
        case .timeLeft:    return "How many minutes are left at 250 words / minute."
        case .pageCount:   return "Current page out of the book's estimated total."
        case .progressBar: return "A draggable bar — slide to scrub through the book."
        }
    }
}
