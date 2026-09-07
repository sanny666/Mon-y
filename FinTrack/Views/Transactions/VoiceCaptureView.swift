import SwiftUI

struct VoiceCaptureView: View {
    @Environment(\.appAccentColor) private var accent
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(VoiceInputService.self) private var voiceInput

    var embeddedInFlow: Bool = false
    var onCancel: (() -> Void)? = nil
    let onComplete: (String) -> Void

    @State private var errorMessage: String?
    @State private var showSettingsAlert = false
    @State private var didComplete = false
    @State private var didStart = false
    @State private var hapticTick = 0
    @State private var successTick = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                timerLabel
                    .padding(.top, 8)

                waveformSection
                    .padding(.top, 28)
                    .padding(.horizontal, 20)

                transcriptBlock
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity, maxHeight: 120, alignment: .top)

                Spacer(minLength: 12)

                stopButton
                    .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MoneyPalette.canvas)
            .navigationTitle("Голосовой ввод")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ModalCloseToolbarItem {
                    voiceInput.cancel()
                    hapticTick += 1
                    cancel()
                }
            }
            .task {
                await startIfNeeded()
            }
            .onChange(of: voiceInput.isRecording) { wasRecording, isRecording in
                if wasRecording && !isRecording && !didComplete {
                    Task { await finishFromSilence() }
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: hapticTick)
            .sensoryFeedback(.success, trigger: successTick)
            .alert("Ошибка", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                if showSettingsAlert {
                    Button("Настройки") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Button("OK", role: .cancel) {
                    if !embeddedInFlow {
                        dismiss()
                    }
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .modifier(VoiceCaptureDetentsModifier(enabled: !embeddedInFlow))
    }

    private var waveformSection: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(accent.opacity(0.07 + Double(voiceInput.meterLevel) * 0.12))
                .frame(height: 72)
                .blur(radius: reduceMotion ? 0 : 12)
                .opacity(voiceInput.isRecording ? 1 : 0.35)
                .animation(
                    reduceMotion ? .easeOut(duration: 0.1) : .easeOut(duration: 0.12),
                    value: voiceInput.meterLevel
                )

            VoiceWaveformView(
                store: voiceInput.waveformStore,
                isRecording: voiceInput.isRecording,
                levelProvider: { voiceInput.currentMeterLevel() },
                accent: UIColor(accent)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }

    private var timerLabel: some View {
        TimelineView(.animation(minimumInterval: 0.03, paused: !voiceInput.isRecording)) { context in
            Text(Self.formatElapsed(startedAt: voiceInput.recordingStartedAt, now: context.date))
                .font(.title3.monospacedDigit().weight(.regular))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.03), value: context.date)
        }
        .accessibilityLabel("Длительность записи")
    }

    private var transcriptBlock: some View {
        Group {
            if voiceInput.partialText.isEmpty {
                Text(voiceInput.isRecording ? "Слушаю…" : "Подготовка…")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    Text(voiceInput.partialText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.opacity)
                }
                .scrollIndicators(.hidden)
                .animation(.easeInOut(duration: 0.2), value: voiceInput.partialText)
            }
        }
    }

    private var stopButton: some View {
        Button {
            Task { await stopAndFinish() }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(width: 84, height: 84)

                if voiceInput.isRecording {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(didComplete || (!voiceInput.isRecording && didStart))
        .opacity(didComplete ? 0.5 : 1)
        .accessibilityLabel(voiceInput.isRecording ? "Стоп" : "Микрофон")
    }

    private func startIfNeeded() async {
        guard !didStart else { return }
        didStart = true
        hapticTick += 1

        let authorized = await voiceInput.requestAuthorizationIfNeeded()
        guard authorized else {
            presentError(VoiceInputError.notAuthorized)
            return
        }

        do {
            try await voiceInput.startRecording()
        } catch {
            presentError(error)
        }
    }

    private func stopAndFinish() async {
        if voiceInput.isRecording {
            do {
                let text = try await voiceInput.stopRecording()
                successTick += 1
                complete(with: text)
            } catch {
                presentError(error)
            }
        } else {
            cancel()
        }
    }

    private func finishFromSilence() async {
        let text = voiceInput.partialText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            presentError(VoiceInputError.emptyTranscript)
            return
        }
        successTick += 1
        complete(with: text)
    }

    private func complete(with text: String) {
        guard !didComplete else { return }
        didComplete = true
        onComplete(text)
        if !embeddedInFlow {
            dismiss()
        }
    }

    private func cancel() {
        if let onCancel {
            onCancel()
        } else {
            dismiss()
        }
    }

    private func presentError(_ error: Error) {
        if let voiceError = error as? VoiceInputError {
            errorMessage = voiceError.errorDescription
            showSettingsAlert = voiceError == .notAuthorized || voiceError == .microphoneDenied
        } else {
            errorMessage = error.localizedDescription
            showSettingsAlert = false
        }
    }

    /// Matches Russian Voice Memos style: `00:02,77`.
    private static func formatElapsed(startedAt: Date?, now: Date) -> String {
        guard let startedAt else { return "00:00,00" }
        let totalCs = max(0, Int((now.timeIntervalSince(startedAt) * 100).rounded()))
        let minutes = totalCs / 6000
        let seconds = (totalCs % 6000) / 100
        let centiseconds = totalCs % 100
        return String(format: "%02d:%02d,%02d", minutes, seconds, centiseconds)
    }
}

private struct VoiceCaptureDetentsModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}
