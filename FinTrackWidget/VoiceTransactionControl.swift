import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct VoiceTransactionControl: ControlWidget {
    static let kind = "com.sany.fintrack.control.voiceTransaction"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: VoiceTransactionIntent()) {
                Label("Голос", systemImage: "mic.fill")
            }
        }
        .displayName("Голосовая транзакция")
        .description("Голосовой ввод транзакции в monёy")
    }
}
