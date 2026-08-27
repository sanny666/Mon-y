import SwiftUI
import WidgetKit

@main
struct FinTrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        FinTrackWidget()
        if #available(iOS 18.0, *) {
            AddTransactionControl()
        }
    }
}
