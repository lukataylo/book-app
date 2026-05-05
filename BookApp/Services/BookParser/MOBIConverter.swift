import Foundation

/// MOBI → EPUB converter.
///
/// On Apple platforms there is no maintained Swift parser for MOBI/AZW3.
/// The plan is to vendor `libmobi` as a C SwiftPM target and bridge it here:
///
///   1. Open the MOBI file with `mobi_init` / `mobi_load_file`
///   2. Walk the records to extract HTML, images, and metadata
///   3. Repackage as EPUB 3 (mimetype, OPF, navigation document, content docs)
///   4. Return the EPUB URL — the rest of the pipeline is format-agnostic
///
/// The bridge is intentionally not in the initial scaffold because adding a
/// C target requires CMake-style headers that need editing in Xcode after
/// `xcodegen generate`. Until that's wired the converter surfaces a helpful
/// error so users know to convert their MOBI files in advance (e.g. with
/// Calibre or kindleunpack).
struct MOBIConverter {

    /// Convert a MOBI file at `mobiURL` to an EPUB stored next to it.
    /// Returns the EPUB URL on success.
    func convert(_ mobiURL: URL) async throws -> URL {
        // Step 1: detect KFX/AZW8 — those need different handling.
        if let header = try? FileHandle(forReadingFrom: mobiURL).read(upToCount: 64),
           let s = String(data: header, encoding: .ascii),
           s.contains("CONT") || s.contains("KFX") {
            throw ParserError.mobiConversionFailed("KFX / AZW8 books are not supported. Convert with Calibre and re-import.")
        }
        // Step 2: with libmobi linked we'd run conversion here.
        // Until the C target is wired into the project, fail gracefully.
        throw ParserError.mobiConversionFailed("MOBI conversion isn't wired up yet — convert to EPUB with Calibre and re-import.")
    }
}
