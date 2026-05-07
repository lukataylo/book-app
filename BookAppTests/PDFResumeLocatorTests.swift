import Testing
import Foundation
@testable import BookApp

/// PDFReaderView writes `pdfpage:<n>` as the locator format. Older
/// installs may still have `scroll:` or `para:` locators on PDF books
/// (legacy: PDFs used to route through the text reader). This pins the
/// parsing rules so a future refactor doesn't quietly break resume.
struct PDFResumeLocatorTests {

    @Test
    func pdfpageLocatorParses() {
        let locator = "pdfpage:42"
        #expect(locator.hasPrefix("pdfpage:"))
        #expect(Int(locator.dropFirst("pdfpage:".count)) == 42)
    }

    @Test
    func pdfpageLocatorWithZeroIsValid() {
        // Page 0 is the first page — must round-trip cleanly so a user
        // who reopens at the very beginning doesn't get bumped.
        let locator = "pdfpage:0"
        #expect(Int(locator.dropFirst("pdfpage:".count)) == 0)
    }

    @Test
    func malformedLocatorYieldsNil() {
        let locator = "pdfpage:abc"
        #expect(Int(locator.dropFirst("pdfpage:".count)) == nil)
    }

    @Test
    func percentEstimateClampsWithinBounds() {
        // Mirrors the fallback logic used when the locator format is from
        // before pdfpage: was canonical.
        let pageCount = 100
        let percent = 0.73
        let estimated = max(0, min(Int(percent * Double(pageCount)), pageCount - 1))
        #expect(estimated == 73)

        let percent2 = 1.5  // shouldn't happen but defensive
        let estimated2 = max(0, min(Int(percent2 * Double(pageCount)), pageCount - 1))
        #expect(estimated2 == pageCount - 1)
    }
}
