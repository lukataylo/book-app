import WidgetKit
import SwiftUI

@main
struct BookAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        ContinueReadingWidget()
        TodaysMemoryWidget()
    }
}
