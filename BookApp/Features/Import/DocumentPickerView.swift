import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

/// File picker that defaults to iCloud Drive, accepting epub, pdf, and mobi.
/// Wraps `UIDocumentPickerViewController` on iOS / iPadOS; uses
/// `fileImporter` on macOS where the SwiftUI native picker is fine.
struct DocumentPickerView: View {
    let onPicked: ([URL]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var presentMacPicker = false

    private static let acceptedTypes: [UTType] = {
        var types: [UTType] = [.pdf]
        if let epub = UTType(filenameExtension: "epub") { types.append(epub) }
        if let mobi = UTType(filenameExtension: "mobi") { types.append(mobi) }
        if let azw3 = UTType(filenameExtension: "azw3") { types.append(azw3) }
        return types
    }()

    var body: some View {
        #if os(macOS)
        Color.clear
            .fileImporter(
                isPresented: .constant(true),
                allowedContentTypes: Self.acceptedTypes,
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result { onPicked(urls) }
                dismiss()
            }
        #else
        DocumentPickerRepresentable(types: Self.acceptedTypes) { urls in
            onPicked(urls)
            dismiss()
        }
        .ignoresSafeArea()
        #endif
    }
}

#if canImport(UIKit)
private struct DocumentPickerRepresentable: UIViewControllerRepresentable {
    let types: [UTType]
    let onPicked: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: ([URL]) -> Void
        init(onPicked: @escaping ([URL]) -> Void) { self.onPicked = onPicked }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPicked(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPicked([])
        }
    }
}
#endif
