import AVFoundation
import Foundation
import Observation
import Speech
import SwiftUI
import UIKit

enum VoiceInputError: LocalizedError, Equatable {
    case recognizerUnavailable
    case notAuthorized
    case microphoneDenied
    case alreadyRecording
    case notRecording
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Распознавание речи недоступно на этом устройстве."
        case .notAuthorized:
            return "Нет разрешения на распознавание речи. Разрешите в Настройках."
        case .microphoneDenied:
            return "Нет доступа к микрофону. Разрешите в Настройках."
        case .alreadyRecording:
            return "Запись уже начата."
        case .notRecording:
            return "Запись не активна."
        case .emptyTranscript:
            return "Не распознан текст. Попробуйте ещё раз."
        }
    }
}

@Observable
@MainActor
final class VoiceInputService {
  /// Glow refresh rate — waveform samples come from CADisplayLink, not this timer.
    static let meterPublishInterval: TimeInterval = 1.0 / 30.0

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceMonitorTask: Task<Void, Never>?
    private var meterPublishTask: Task<Void, Never>?
    private var lastPartialUpdate = Date.distantPast
    private let levelLock = NSLock()
    /// Written from the audio tap thread; read by the meter publisher.
    private nonisolated(unsafe) var liveLevel: Float = 0
    private nonisolated(unsafe) var smoothedLevel: Float = 0
    private nonisolated(unsafe) var peakTracker: Float = 0.12

    /// Non-observable waveform buffer — read by CADisplayLink, written by meter timer.
    let waveformStore = VoiceWaveformStore()

    private(set) var isRecording = false
    private(set) var partialText = ""
    private(set) var meterLevel: Float = 0
    private(set) var recordingStartedAt: Date?
    var errorMessage: String?

    private let silenceTimeout: TimeInterval = 1.8

    var recordingElapsed: TimeInterval {
        guard let recordingStartedAt else { return 0 }
        return Date().timeIntervalSince(recordingStartedAt)
    }

    /// Thread-safe read for CADisplayLink waveform sampling.
    func currentMeterLevel() -> Float {
        levelLock.lock()
        let level = liveLevel
        levelLock.unlock()
        return level
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            errorMessage = VoiceInputError.notAuthorized.errorDescription
            return false
        }

        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        guard micGranted else {
            errorMessage = VoiceInputError.microphoneDenied.errorDescription
            return false
        }

        return true
    }

    func startRecording() async throws {
        guard !isRecording else { throw VoiceInputError.alreadyRecording }
        guard let recognizer, recognizer.isAvailable else { throw VoiceInputError.recognizerUnavailable }

        guard await requestAuthorizationIfNeeded() else {
            throw VoiceInputError.notAuthorized
        }

        try prepareAudioSession()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        recognitionRequest = request
        partialText = ""
        errorMessage = nil
        lastPartialUpdate = .now
        levelLock.lock()
        liveLevel = 0
        smoothedLevel = 0
        peakTracker = 0.12
        levelLock.unlock()
        meterLevel = 0
        recordingStartedAt = .now
        waveformStore.resetAndStart()

        // Format must come from the hardware input after the session is active.
        // Using outputFormat before start often yields 0Hz / empty buffers → flat meter.
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            throw VoiceInputError.recognizerUnavailable
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)
            // Update level on the audio callback thread — don't hop to MainActor per buffer.
            self?.ingestMeterLevelFromAudioThread(Self.speechMeterLevel(from: buffer))
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.partialText = result.bestTranscription.formattedString
                    self.lastPartialUpdate = .now
                } else if let error {
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        isRecording = true
        startSilenceMonitor()
        startMeterPublisher()
    }

    func stopRecording() async throws -> String {
        guard isRecording else { throw VoiceInputError.notRecording }

        tearDownCapture()
        try? await Task.sleep(nanoseconds: 250_000_000)

        let text = partialText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw VoiceInputError.emptyTranscript }
        return text
    }

    func cancel() {
        silenceMonitorTask?.cancel()
        silenceMonitorTask = nil
        meterPublishTask?.cancel()
        meterPublishTask = nil
        tearDownCapture()
    }

    private func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startSilenceMonitor() {
        silenceMonitorTask?.cancel()
        silenceMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard let self, self.isRecording else { return }
                let idle = Date().timeIntervalSince(self.lastPartialUpdate)
                if idle >= self.silenceTimeout && !self.partialText.isEmpty {
                    self.tearDownCapture()
                    return
                }
            }
        }
    }

    private func tearDownCapture() {
        silenceMonitorTask?.cancel()
        silenceMonitorTask = nil
        meterPublishTask?.cancel()
        meterPublishTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        meterLevel = 0
        levelLock.lock()
        liveLevel = 0
        smoothedLevel = 0
        peakTracker = 0.12
        levelLock.unlock()
        recordingStartedAt = nil
        waveformStore.stop()

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Called from the audio render thread — keep it lock-only, no MainActor.
    nonisolated private func ingestMeterLevelFromAudioThread(_ raw: Float) {
        levelLock.lock()
        // Adaptive peak — quiet and loud speech both map into visible bar motion.
        peakTracker = max(raw * 0.95, peakTracker * 0.992)
        let normalized = min(1, raw / max(0.08, peakTracker))

        let attack: Float = 0.65
        let release: Float = 0.22
        if normalized > smoothedLevel {
            smoothedLevel += (normalized - smoothedLevel) * attack
        } else {
            smoothedLevel += (normalized - smoothedLevel) * release
        }
        liveLevel = smoothedLevel
        levelLock.unlock()
    }

    private func startMeterPublisher() {
        meterPublishTask?.cancel()
        meterPublishTask = Task { @MainActor [weak self] in
            let ns = UInt64(Self.meterPublishInterval * 1_000_000_000)
            while !Task.isCancelled {
                guard let self, self.isRecording else { return }
                self.levelLock.lock()
                let level = self.liveLevel
                self.levelLock.unlock()
                self.meterLevel = level
                try? await Task.sleep(nanoseconds: ns)
            }
        }
    }

    /// Peak-biased speech meter mapped into 0...1 for visible bar motion.
    nonisolated private static func speechMeterLevel(from buffer: AVAudioPCMBuffer) -> Float {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var peak: Float = 0
        var sumSquares: Float = 0

        if let channels = buffer.floatChannelData {
            let samples = UnsafeBufferPointer(start: channels[0], count: frameLength)
            for sample in samples {
                let absolute = abs(sample)
                if absolute > peak { peak = absolute }
                sumSquares += sample * sample
            }
        } else if let channels = buffer.int16ChannelData {
            let samples = UnsafeBufferPointer(start: channels[0], count: frameLength)
            for sample in samples {
                let normalized = Float(sample) / Float(Int16.max)
                let absolute = abs(normalized)
                if absolute > peak { peak = absolute }
                sumSquares += normalized * normalized
            }
        } else {
            return 0
        }

        let rms = sqrt(sumSquares / Float(frameLength))
        // Blend peak (responsive) with RMS (body). Mic speech is often quiet in linear PCM.
        let mixed = max(peak * 1.35, rms * 2.2)
        // Mild curve — adaptive peak normalization handles loud/quiet scaling.
        let curved = pow(min(1, mixed * 3.5), 0.6)
        return min(1, max(0, curved))
    }
}
