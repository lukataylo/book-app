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
                if book.isSummaryEdition {
                    summaryBadge
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                if progress > 0.01 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.18))
                            Capsule().fill(Color.white)
                                .frame(width: geo.size.width * min(1, max(0, progress)))
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
                }
                .frame(width: width, alignment: .leading)
            }
        }
    }

    /// "15 MIN" pill marking catalog summary editions on the shelf.
    private var summaryBadge: some View {
        Text(book.readMinutesEstimate > 0 ? "\(book.readMinutesEstimate) MIN" : "KEY IDEAS")
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .padding(6)
    }

    @ViewBuilder
    private var cover: some View {
        #if canImport(UIKit)
        if let data = book.coverData {
            CachedCoverImage(bookID: book.id, data: data) {
                generatedCover
            }
        } else {
            generatedCover
        }
        #else
        if let image = book.coverData.flatMap(Self.platformImage(from:)) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            generatedCover
        }
        #endif
    }

    private var generatedCover: some View {
        let color = Theme.BookSpine.color(for: book.categoryTags)
        return ZStack(alignment: .bottomLeading) {
            // Flat spine color — the catalog's no-gradient design language.
            color
                .overlay(
                    Rectangle()
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(book.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Text(book.author)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(Theme.Spacing.s)
        }
    }

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
