import SwiftUI

/// Action Button / deep-link flow: capture → batch confirm inside one fullScreenCover.
struct VoiceQuickAddFlowView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case capture
        case confirm(transcript: String, results: [VoiceParseResult])
    }

    @State private var step: Step = .capture
    @State private var errorMessage: String?

    var body: some View {
        Group {
            switch step {
            case .capture:
                VoiceCaptureView(
                    embeddedInFlow: true,
                    onCancel: { dismiss() },
                    onComplete: handleTranscript
                )
            case .confirm(let transcript, let results):
                VoiceBatchConfirmView(transcript: transcript, results: results)
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func handleTranscript(_ text: String) {
        do {
            let results = try container.parseVoiceTranscripts(text)
            step = .confirm(transcript: text, results: results)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
