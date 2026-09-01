import SwiftUI

/// Action Button / deep-link flow: capture → confirm inside one fullScreenCover.
struct VoiceQuickAddFlowView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case capture
        case confirm(transcript: String, parseResult: VoiceParseResult)
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
            case .confirm(let transcript, let parseResult):
                VoiceTransactionConfirmView(
                    transcript: transcript,
                    parseResult: parseResult
                )
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
            let result = try container.parseVoiceTranscript(text)
            step = .confirm(transcript: text, parseResult: result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
