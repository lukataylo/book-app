import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Generated cover system — "Idea Glyphs" (approach B from
/// `research/cover-art/`): warm paper ground, ink typography, one
/// stroke-built geometric glyph per category, category-color foot bar.
/// Deterministic per title via a stable hash; flat fills and strokes only
/// (no gradients); renders crisply at shelf and detail scale.
enum CoverArt {
    /// Warm paper — covers are artwork, so the ground does not flip with
    /// the system color scheme (exactly like real jackets in iOS Books).
    static let paper = Color(hex: "F7F3EB")
    static let ink   = Color(hex: "2B2620")

    /// Refined "print ink" tones shared with the mockups.
    static let palette: [String: Color] = [
        "Self-improvement": Color(hex: "C92A21"),
        "Psychology":       Color(hex: "2447C2"),
        "Business":         Color(hex: "0E7C96"),
        "Science":          Color(hex: "0B7F58"),
        "History":          Color(hex: "8F4A12"),
        "Philosophy":       Color(hex: "6B3FC9"),
        "Politics":         Color(hex: "4B5563"),
        "Memoir":           Color(hex: "A16207"),
        "Essays":           Color(hex: "374151")
    ]

    static func tint(for tags: [String]) -> Color {
        for tag in tags {
            if let c = palette[tag] { return c }
        }
        return Color(hex: "475569")
    }

    /// Asset name of this book's designed vector cover (`Covers.xcassets`),
    /// or `nil` when none ships — callers then fall back to the generated
    /// Idea-Glyph cover. The SVGs are authored at a true 2:3 ratio, so they
    /// fill the 2:3 card frame exactly and never crop.
    static func designedAssetName(for book: Book) -> String? {
        guard !book.artSlug.isEmpty else { return nil }
        let name = "cover-\(book.artSlug)"
        #if canImport(UIKit)
        return UIImage(named: name) != nil ? name : nil
        #else
        return nil
        #endif
    }

    /// Stable seed for per-title variation. `hashValue` is randomized per
    /// launch, so covers would shuffle on every run — djb2 instead.
    static func seed(_ s: String) -> UInt64 {
        var h: UInt64 = 5381
        for b in s.utf8 { h = (h &* 33) &+ UInt64(b) }
        return h
    }
}

/// The full generated cover: eyebrow + title + glyph + author + foot bar.
/// Sized by its container; all metrics are proportional to the cover
/// width, like type on a printed jacket (the scalable title/author live
/// in the card's caption below, so Dynamic Type is served there).
struct GeneratedCoverView: View {
    let title: String
    let author: String
    let categories: [String]

    init(book: Book) {
        self.title = book.title
        self.author = book.author
        self.categories = book.categoryTags
    }

    init(title: String, author: String, categories: [String]) {
        self.title = title
        self.author = author
        self.categories = categories
    }

    private static let eyebrowPrefix = "The Big Ideas in "

    private var eyebrow: String? {
        title.hasPrefix(Self.eyebrowPrefix) ? "THE BIG IDEAS IN" : nil
    }

    private var displayTitle: String {
        title.hasPrefix(Self.eyebrowPrefix)
            ? String(title.dropFirst(Self.eyebrowPrefix.count))
            : title
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let margin = w * 0.09
            let tint = CoverArt.tint(for: categories)
            let seed = CoverArt.seed(title)

            ZStack(alignment: .topLeading) {
                CoverArt.paper

                // Glyph sits in the lower-middle band, gently tilted by
                // the title seed so shelves feel hand-set, not stamped.
                IdeaGlyph(
                    category: categories.first ?? "",
                    tint: tint,
                    seed: seed
                )
                .frame(width: w * 0.52, height: w * 0.52)
                .rotationEffect(.degrees(Double(seed % 13) - 6))
                .position(x: w * 0.5, y: h * 0.56)

                VStack(alignment: .leading, spacing: h * 0.012) {
                    if let eyebrow {
                        Text(eyebrow)
                            .font(.system(size: w * 0.052, weight: .semibold))
                            .tracking(w * 0.012)
                            .foregroundStyle(CoverArt.ink.opacity(0.55))
                    }
                    Text(displayTitle)
                        .font(.system(size: w * 0.105, weight: .semibold, design: .serif))
                        .foregroundStyle(CoverArt.ink)
                        .lineLimit(4)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, margin)
                .padding(.top, margin)

                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    if !author.isEmpty {
                        Text(author)
                            .font(.system(size: w * 0.052, weight: .medium))
                            .foregroundStyle(CoverArt.ink.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, margin)
                            .padding(.bottom, h * 0.028)
                    }
                    Rectangle()
                        .fill(tint)
                        .frame(height: h * 0.045)
                }
            }
        }
        .clipped()
    }
}

/// One stroke-built glyph per category, with element count and accents
/// seeded by the title so siblings within a category stay distinct.
private struct IdeaGlyph: View {
    let category: String
    let tint: Color
    let seed: UInt64

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let line = max(s * 0.045, 1)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            var strokes = Path()
            var fills = Path()

            switch category {
            case "Psychology":
                // Concentric rings — the mind's layers.
                let rings = 3 + Int(seed % 3)
                for i in 0..<rings {
                    let r = s * 0.5 * CGFloat(i + 1) / CGFloat(rings)
                    strokes.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                }
                fills.addEllipse(in: CGRect(x: c.x - line, y: c.y - line, width: line * 2, height: line * 2))

            case "Self-improvement":
                // Repeating circles marching right — the habit loop, again.
                let n = 3 + Int(seed % 3)
                let r = s * 0.22
                let step = (s - r * 2) / CGFloat(max(n - 1, 1))
                for i in 0..<n {
                    let x = r + step * CGFloat(i)
                    strokes.addEllipse(in: CGRect(x: x - r, y: c.y - r, width: r * 2, height: r * 2))
                }
                let dotR = line * 1.2
                fills.addEllipse(in: CGRect(x: s - r - dotR, y: c.y - dotR, width: dotR * 2, height: dotR * 2))

            case "Business":
                // Ascending bars.
                let n = 4 + Int(seed % 3)
                let gap = s * 0.06
                let barW = (s - gap * CGFloat(n - 1)) / CGFloat(n)
                for i in 0..<n {
                    let height = s * (0.3 + 0.7 * CGFloat(i + 1) / CGFloat(n))
                    let x = (barW + gap) * CGFloat(i)
                    strokes.addRect(CGRect(x: x, y: s - height, width: barW, height: height))
                }

            case "Science":
                // Orbitals around a nucleus.
                let orbits = 2 + Int(seed % 2)
                for i in 0..<orbits {
                    let angle = Angle.degrees(Double(i) * 180.0 / Double(orbits) + Double(seed % 30))
                    let ellipse = Path(ellipseIn: CGRect(x: c.x - s * 0.5, y: c.y - s * 0.2, width: s, height: s * 0.4))
                    strokes.addPath(ellipse.applying(
                        CGAffineTransform(translationX: -c.x, y: -c.y)
                            .concatenating(CGAffineTransform(rotationAngle: angle.radians))
                            .concatenating(CGAffineTransform(translationX: c.x, y: c.y))
                    ))
                }
                let r = line * 1.6
                fills.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))

            case "History":
                // A timeline with ticks; one seeded moment marked.
                strokes.move(to: CGPoint(x: 0, y: c.y))
                strokes.addLine(to: CGPoint(x: s, y: c.y))
                let ticks = 5 + Int(seed % 3)
                for i in 0..<ticks {
                    let x = s * CGFloat(i) / CGFloat(ticks - 1)
                    strokes.move(to: CGPoint(x: x, y: c.y - s * 0.09))
                    strokes.addLine(to: CGPoint(x: x, y: c.y + s * 0.09))
                }
                let markIndex = Int(seed % UInt64(ticks))
                let mx = s * CGFloat(markIndex) / CGFloat(ticks - 1)
                let r = line * 1.4
                fills.addEllipse(in: CGRect(x: mx - r, y: c.y - s * 0.22 - r, width: r * 2, height: r * 2))

            case "Philosophy":
                // Two columns under an arch.
                let colW = s * 0.14
                let colH = s * 0.45
                let baseY = s * 0.9
                let leftX = s * 0.18
                let rightX = s * 0.82 - colW
                strokes.addRect(CGRect(x: leftX, y: baseY - colH, width: colW, height: colH))
                strokes.addRect(CGRect(x: rightX, y: baseY - colH, width: colW, height: colH))
                strokes.addArc(
                    center: CGPoint(x: s * 0.5, y: baseY - colH),
                    radius: (rightX + colW - leftX) / 2,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
                )
                strokes.move(to: CGPoint(x: s * 0.08, y: baseY))
                strokes.addLine(to: CGPoint(x: s * 0.92, y: baseY))

            case "Politics":
                // Pediment over columns — the institution.
                let baseY = s * 0.88
                strokes.move(to: CGPoint(x: s * 0.1, y: s * 0.32))
                strokes.addLine(to: CGPoint(x: s * 0.5, y: s * 0.08))
                strokes.addLine(to: CGPoint(x: s * 0.9, y: s * 0.32))
                strokes.closeSubpath()
                let cols = 3
                for i in 0..<cols {
                    let x = s * (0.22 + 0.28 * CGFloat(i))
                    strokes.move(to: CGPoint(x: x, y: s * 0.4))
                    strokes.addLine(to: CGPoint(x: x, y: baseY))
                }
                strokes.move(to: CGPoint(x: s * 0.1, y: baseY))
                strokes.addLine(to: CGPoint(x: s * 0.9, y: baseY))

            case "Memoir":
                // A life inside its frame: open circle, off-center self.
                let r = s * 0.42
                strokes.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                let dr = line * 1.6
                let angle = Double(seed % 360) * .pi / 180
                let dx = c.x + cos(angle) * r * 0.45
                let dy = c.y + sin(angle) * r * 0.45
                fills.addEllipse(in: CGRect(x: dx - dr, y: dy - dr, width: dr * 2, height: dr * 2))

            case "Essays":
                // Staggered text lines.
                let rows = 4 + Int(seed % 2)
                for i in 0..<rows {
                    let y = s * (0.2 + 0.6 * CGFloat(i) / CGFloat(rows - 1))
                    let inset = (i == rows - 1) ? s * 0.35 : s * CGFloat((seed >> UInt64(i)) % 4) * 0.04
                    strokes.move(to: CGPoint(x: 0, y: y))
                    strokes.addLine(to: CGPoint(x: s - inset, y: y))
                }

            default:
                // Quiet diamond for anything uncategorized.
                strokes.move(to: CGPoint(x: c.x, y: c.y - s * 0.4))
                strokes.addLine(to: CGPoint(x: c.x + s * 0.4, y: c.y))
                strokes.addLine(to: CGPoint(x: c.x, y: c.y + s * 0.4))
                strokes.addLine(to: CGPoint(x: c.x - s * 0.4, y: c.y))
                strokes.closeSubpath()
            }

            ctx.stroke(strokes, with: .color(tint), style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
            ctx.fill(fills, with: .color(tint))
        }
        .accessibilityHidden(true)
    }
}

#Preview("Idea Glyph covers") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
            ForEach([
                ("The Big Ideas in Atomic Habits", "James Clear", ["Self-improvement"]),
                ("The Big Ideas in Thinking, Fast and Slow", "Daniel Kahneman", ["Psychology"]),
                ("The Big Ideas in Zero to One", "Peter Thiel", ["Business"]),
                ("The Big Ideas in Why We Sleep", "Matthew Walker", ["Science"]),
                ("The Big Ideas in Sapiens", "Yuval Noah Harari", ["History"]),
                ("The Big Ideas in Meditations", "Marcus Aurelius", ["Philosophy"])
            ], id: \.0) { item in
                GeneratedCoverView(title: item.0, author: item.1, categories: item.2)
                    .frame(width: 120, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding()
    }
}
