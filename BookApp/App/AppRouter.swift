import SwiftUI

/// App-wide navigation router. Lets external entry points (the Today's Memory
/// widget, notifications) select a tab. Injected into the environment by
/// `BookAppApp` and bound by `RootTabView`.
@Observable
final class AppRouter {
    var selectedTab: RootTabView.Tab = .library

    /// Route an incoming deep link (e.g. `bookapp://memories`) to a tab.
    /// Unknown hosts are ignored so a bad URL never throws the user somewhere
    /// surprising.
    func handle(url: URL) {
        switch url.host {
        case "memories": selectedTab = .memories
        case "learn":    selectedTab = .learn
        case "library":  selectedTab = .library
        default:         break
        }
    }
}
