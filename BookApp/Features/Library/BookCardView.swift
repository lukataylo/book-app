import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Single book on the shelf — cover image (or generated spine fallback),
/// title, author. Sized for the shelf carousel; the same view is reused on
/// the search results screen.
struct BookCardView: View {
    let book: Book
    var width: CGFloat = 120
    var showsTitle: Bool = true
    /// 0…1; renders a thin filled bar on the bottom edge of the cover when > 0.01.
    var progress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ZStack(alignment: .bottom) {
                cover
                    .frame(width: width, height: width * 1.5)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s, style: .continuous))
                if progress > 0.01 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track + soft shadow on the fill keep the bar
                            // visible over light covers too.
                            Capsule().fill(.black.opacity(0.25))
                            Capsule().fill(.white)
                                .frame(width: geo.size.width * min(1, max(0, progress)))
                                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 0)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
            .frame(width: width, height: width * 1.5)
            .shadow(color: Theme.Palette.bookShadow, radius: 8, x: 0, y: 4)
            if showsTitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(Typography.cardTitle)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(2)
                    Text(book.author)
                        .font(Typography.secondary)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                    // Length tiers, quietly: every catalog title ships a
                    // 3-min quick take and the full summary.
                    if book.isSummaryEdition, book.readMinutesEstimate > 0 {
                        Text("3–\(book.readMinutesEstimate) min")
                            .font(Typography.micro)
                            .foregroundStyle(Theme.Palette.textSecondary.opacity(0.8))
                    }
                }
                .frame(width: width, alignment: .leading)
            }
        }
        // One spoken element per card — the cover art is decorative
        // (hidden in BookCoverView), so VoiceOver reads a single clean label
        // instead of the title twice plus an asset filename.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [book.title]
        if !book.author.isEmpty { parts.append("by \(book.author)") }
        if book.isSummaryEdition, book.readMinutesEstimate > 0 {
            parts.append("3 to \(book.readMinutesEstimate) minute read")
        }
        if progress > 0.01 { parts.append("\(Int((progress * 100).rounded())) percent read") }
        return parts.joined(separator: ", ")
    }

    private var cover: some View { BookCoverView(book: book) }

    /// Platform-aware image decoder used by both compact and grid layouts.
    /// Static so we don't capture `self` in the call site.
    static func platformImage(from data: Data) -> Image? {
        #if canImport(UIKit)
        return UIImage(data: data).map { Image(uiImage: $0) }
        #elseif canImport(AppKit)
        return NSImage(data: data).map { Image(nsImage: $0) }
        #else
        return nil
        #endif
    }
}
