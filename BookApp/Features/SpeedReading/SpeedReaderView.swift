import SwiftUI
import SwiftData

/// Speed reader with three modes — Paragraph + Word, Word Focus, RSVP.
/// Speed is set in WPM; pause-at-punctuation lengthens the dwell time on
/// commas, periods, and paragraph breaks.
struct SpeedReaderView: View {
    let paragraphs: [String]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SpeedReaderSettings()
    @State private var paragraphIndex: Int = 0
    @State private var wordIndex: Int = 0
    @State private var isRunning: Bool = false
    @State private var ticker: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.l) {
                modeContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                controls
            }
            .padding(Theme.Spacing.l)
            .navigationTitle("Speed reading")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { stop(); dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Mode", selection: Binding(
                            get: { settings.mode },
                            set: { settings.mode = $0; persist() }
                        )) {
                            ForEach(SpeedReaderMode.allCases, id: \.self) { m in
                                Text(m.displayName).tag(m)
                            }
                        }
                        Toggle("Pause at punctuation", isOn: Binding(
                            get: { settings.pauseAtPunctuation },
                            set: { settings.pauseAtPunctuation = $0; persist() }
                        ))
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .onAppear { load() }
            .onDisappear { stop() }
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch settings.mode {
        case .paragraphAndWord: paragraphAndWordView
        case .wordFocus:        wordFocusView
        case .rsvp:             rsvpView
        }
    }

    private var paragraphAndWordView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { idx, paragraph in
                        Text(highlightedAttributedString(for: paragraph, isCurrent: idx == paragraphIndex))
                            .font(.system(size: 18, design: .serif))
                            .id(idx)
                    }
                }
            }
            .onChange(of: paragraphIndex) { _, new in
                withAnimation { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private var wordFocusView: some View {
        VStack(spacing: Theme.Spacing.m) {
            Text(currentSentence)
                .font(.system(size: 24, design: .serif))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.l)
            Text(currentWord)
                .font(.system(size: 56, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.Palette.accent)
        }
    }

    private var rsvpView: some View {
        VStack(spacing: Theme.Spacing.l) {
            HStack(spacing: 4) {
                let word = currentWord
                let pivot = pivotIndex(for: word)
                let prefix = String(word.prefix(pivot))
                let pivotChar = String(word[word.index(word.startIndex, offsetBy: pivot)..<word.index(word.startIndex, offsetBy: min(pivot + 1, word.count))])
                let suffix = String(word.suffix(max(0, word.count - pivot - 1)))
                Text(prefix)
                    .font(.system(size: 64, weight: .bold, design: .serif))
                Text(pivotChar)
                    .font(.system(size: 64, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.Palette.accent)
                Text(suffix)
                    .font(.system(size: 64, weight: .bold, design: .serif))
            }
            Rectangle()
                .frame(width: 2, height: 80)
                .foregroundStyle(Theme.Palette.accent.opacity(0.4))
                .offset(y: -40)
        }
    }

    private var controls: some View {
        VStack(spacing: Theme.Spacing.l) {
            // WPM front and centre — big serif numeral, presets either side,
            // slider underneath for fine adjustment.
            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(settings.wpm)")
                        .font(.system(size: 56, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .monospacedDigit()
                    Text("words / min")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                // Preset chips for fast adjustment.
                HStack(spacing: 8) {
                    ForEach([200, 300, 500, 800, 1100], id: \.self) { wpm in
                        Button {
                            settings.wpm = wpm
                            persist()
                        } label: {
                            Text("\(wpm)")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(
                                        settings.wpm == wpm
                                            ? Theme.Palette.textPrimary.opacity(0.10)
                                            : Color.clear
                                    )
                                )
                                .overlay(
                                    Capsule().stroke(
                                        Theme.Palette.divider, lineWidth: 0.5
                                    )
                                )
                                .foregroundStyle(Theme.Palette.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Slider(
                    value: Binding(
                        get: { Double(settings.wpm) },
                        set: { settings.wpm = Int(($0 / 25).rounded()) * 25; persist() }
                    ),
                    in: 150...1200,
                    step: 25
                )
                .tint(Theme.Palette.textPrimary)
            }
            .padding(.horizontal, Theme.Spacing.s)

            // Playback row.
            HStack(spacing: 36) {
                Button { jumpBackOneSentence() } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Button { isRunning ? stop() : start() } label: {
                    Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 68))
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                Button { skipForward() } label: {
                    Image(systemName: "forward.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
        .padding(.bottom, Theme.Spacing.m)
    }

    // MARK: - Logic

    private var currentParagraphWords: [String] {
        guard paragraphIndex < paragraphs.count else { return [] }
        return paragraphs[paragraphIndex].split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    private var currentWord: String {
        let words = currentParagraphWords
        guard wordIndex < words.count else { return "" }
        return words[wordIndex]
    }

    private var currentSentence: String {
        let words = currentParagraphWords
        let start = max(0, wordIndex - 6)
        let end = min(words.count, wordIndex + 7)
        return words[start..<end].joined(separator: " ")
    }

    private func pivotIndex(for word: String) -> Int {
        // Spritz-like ORP: ~35% across the word, but weighted by length.
        guard !word.isEmpty else { return 0 }
        switch word.count {
        case 1: return 0
        case 2...5: return 1
        case 6...9: return 2
        case 10...13: return 3
        default: return 4
        }
    }

    private func highlightedAttributedString(for paragraph: String, isCurrent: Bool) -> AttributedString {
        var attributed = AttributedString(paragraph)
        attributed.foregroundColor = isCurrent ? .primary : .secondary.opacity(0.55)
        guard isCurrent else { return attributed }

        // Find the byte range of the wordIndex'th word in the paragraph by
        // scanning whitespace boundaries — `range(of:)` would jump to the
        // first occurrence and stick there when the same word repeats.
        var wordsSeen = 0
        var cursor = paragraph.startIndex
        while cursor < paragraph.endIndex {
            // Skip leading whitespace.
            while cursor < paragraph.endIndex, paragraph[cursor].isWhitespace {
                cursor = paragraph.index(after: cursor)
            }
            guard cursor < paragraph.endIndex else { break }
            let wordStart = cursor
            while cursor < paragraph.endIndex, !paragraph[cursor].isWhitespace {
                cursor = paragraph.index(after: cursor)
            }
            if wordsSeen == wordIndex {
                if let attrStart = AttributedString.Index(wordStart, within: attributed),
                   let attrEnd   = AttributedString.Index(cursor,    within: attributed) {
                    let range = attrStart..<attrEnd
                    attributed[range].backgroundColor = Color(hex: settings.highlightColorHex).opacity(0.5)
                    attributed[range].foregroundColor = .primary
                }
                break
            }
            wordsSeen += 1
        }
        return attributed
    }

    private func start() {
        isRunning = true
        ticker?.cancel()
        ticker = Task { await tick() }
    }

    private func stop() {
        isRunning = false
        ticker?.cancel()
        ticker = nil
    }

    @MainActor
    private func tick() async {
        while isRunning {
            let word = currentWord
            let baseIntervalMS = 60_000 / max(60, settings.wpm)
            var dwell = baseIntervalMS
            if settings.pauseAtPunctuation {
                if word.hasSuffix(",") || word.hasSuffix(";") { dwell += settings.commaPauseMS }
                if word.hasSuffix(".") || word.hasSuffix("?") || word.hasSuffix("!") { dwell += settings.periodPauseMS }
            }
            try? await Task.sleep(nanoseconds: UInt64(dwell) * 1_000_000)
            advance()
        }
    }

    private func advance() {
        let words = currentParagraphWords
        if wordIndex + 1 < words.count {
            wordIndex += 1
        } else if paragraphIndex + 1 < paragraphs.count {
            paragraphIndex += 1
            wordIndex = 0
            if settings.pauseAtPunctuation {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(settings.paragraphPauseMS) * 1_000_000)
                }
            }
        } else {
            stop()
        }
    }

    private func skipForward() {
        let words = currentParagraphWords
        wordIndex = min(words.count, wordIndex + 20)
        if wordIndex >= words.count, paragraphIndex + 1 < paragraphs.count {
            paragraphIndex += 1
            wordIndex = 0
        }
    }

    private func jumpBackOneSentence() {
        let words = currentParagraphWords
        var i = wordIndex - 1
        while i > 0 {
            let w = words[i]
            if w.hasSuffix(".") || w.hasSuffix("?") || w.hasSuffix("!") { break }
            i -= 1
        }
        wordIndex = max(0, i)
    }

    private func load() {
        let descriptor = FetchDescriptor<SpeedReaderSettings>()
        if let existing = try? modelContext.fetch(descriptor).first {
            settings = existing
        } else {
            modelContext.insert(settings)
            try? modelContext.save()
        }
    }

    private func persist() {
        try? modelContext.save()
    }
}
