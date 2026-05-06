import Foundation

extension Collection {
    /// Bounds-checked subscript. Returns `nil` when the index is invalid
    /// instead of trapping. Use this in any path where the index comes
    /// from user state (currentParagraph, speedWordIndex, etc.) — those
    /// can drift out of sync with the underlying array after edits,
    /// chapter switches, or async work, and a single bad access is enough
    /// to crash the reader.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
