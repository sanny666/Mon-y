import QuartzCore
import UIKit

/// Lock-backed sample buffer that is NOT @Observable — CADisplayLink reads it directly.
final class VoiceWaveformStore: @unchecked Sendable {
    static let historyLimit = 360
    static let sampleInterval: CFTimeInterval = 1.0 / 48.0

    struct Sample {
        var level: Float
        var time: CFTimeInterval
    }

    struct Snapshot {
        var samples: [Sample]
        var isActive: Bool
    }

    private let lock = NSLock()
    private var samples: [Sample] = []
    private(set) var isActive = false

    func resetAndStart() {
        lock.lock()
        samples = []
        isActive = true
        // Seed a short baseline so the ribbon is visible before the first meter tick.
        let now = CACurrentMediaTime()
        for i in 0..<24 {
            samples.append(Sample(level: 0.03, time: now - CFTimeInterval(24 - i) * Self.sampleInterval))
        }
        lock.unlock()
    }

    func stop() {
        lock.lock()
        isActive = false
        lock.unlock()
    }

    func clear() {
        lock.lock()
        samples = []
        isActive = false
        lock.unlock()
    }

    func append(level: Float) {
        lock.lock()
        samples.append(Sample(level: max(0.02, min(1, level)), time: CACurrentMediaTime()))
        if samples.count > Self.historyLimit {
            samples.removeFirst(samples.count - Self.historyLimit)
        }
        lock.unlock()
    }

    /// Linear interpolation between stored samples at `targetTime`.
    func level(at targetTime: CFTimeInterval) -> Float {
        lock.lock()
        defer { lock.unlock() }

        guard !samples.isEmpty else { return 0.02 }

        if targetTime <= samples[0].time {
            return samples[0].level
        }

        let last = samples[samples.count - 1]
        if targetTime >= last.time {
            return last.level
        }

        for index in 1..<samples.count {
            let previous = samples[index - 1]
            let next = samples[index]
            if targetTime <= next.time {
                let delta = next.time - previous.time
                if delta <= 0 { return next.level }
                let fraction = Float((targetTime - previous.time) / delta)
                return previous.level + (next.level - previous.level) * fraction
            }
        }

        return last.level
    }

    func snapshot() -> Snapshot {
        lock.lock()
        let snap = Snapshot(samples: samples, isActive: isActive)
        lock.unlock()
        return snap
    }
}
