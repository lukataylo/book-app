import SwiftUI

/// Attribution + licenses. The app ships original summaries of real books and
/// three public-domain classics, plus open-source components — App Review
/// (Guideline 5.2) and the BSD licenses both expect these credited in-app.
struct AcknowledgementsView: View {
    var body: some View {
        Form {
            Section("Summary content") {
                Text("The \u{201C}Big Ideas in \u{2026}\u{201D} summaries are original works written for this app. They paraphrase the ideas of each book and are not affiliated with, authorized, or endorsed by the authors or publishers. If a summary resonates, please buy the full book — the author earned it.")
                    .font(.callout)
            }

            Section("Public-domain classics") {
                Text("The Republic (Plato), The Prince (Machiavelli), and Beyond Good and Evil (Nietzsche) are in the public domain, sourced from Project Gutenberg.")
                    .font(.callout)
            }

            Section("Open source") {
                license("Readium Swift Toolkit", "BSD-3-Clause")
                license("SwiftSoup", "MIT")
                license("CryptoSwift", "Attribution")
                license("ZIPFoundation", "MIT")
                license("GCDWebServer", "BSD-3-Clause")
                Text("Full license texts are available in each project's repository.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func license(_ name: String, _ license: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(license)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { AcknowledgementsView() }
}
