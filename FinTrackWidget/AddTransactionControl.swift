import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct AddTransactionControl: ControlWidget {
    static let kind = "com.sany.fintrack.control.addTransaction"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: AddTransactionIntent()) {
                Label("Транзакция", systemImage: "plus")
            }
        }
        .displayName("Добавить транзакцию")
        .description("Новая транзакция в monёy")
    }
}
