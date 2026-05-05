import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Cross-platform share sheet shim. Routes to `UIActivityViewController` on
/// iOS / iPadOS and to `NSSharingServicePicker` on macOS.
@MainActor
final class ShareCoordinator {
    static let shared = ShareCoordinator()

    func share(item: Any) {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes
        let scene = scenes.first as? UIWindowScene
        let window = scene?.keyWindow
        guard let root = window?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        var presenter = root
        while let next = presenter.presentedViewController { presenter = next }
        if let pop = vc.popoverPresentationController {
            pop.sourceView = presenter.view
            pop.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        presenter.present(vc, animated: true)
        #elseif canImport(AppKit)
        guard let url = item as? URL else { return }
        let picker = NSSharingServicePicker(items: [url])
        if let window = NSApplication.shared.keyWindow,
           let view = window.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
        #endif
    }
}
