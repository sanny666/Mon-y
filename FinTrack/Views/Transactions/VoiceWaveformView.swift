import SwiftUI
import UIKit

/// CADisplayLink waveform — samples at display rate, interpolated slots, gradient bars.
struct VoiceWaveformView: UIViewRepresentable {
    let store: VoiceWaveformStore
    /// Passed so SwiftUI calls `updateUIView` when recording starts/stops.
    var isRecording: Bool
    var levelProvider: () -> Float
    var accent: UIColor = .systemOrange

    func makeUIView(context: Context) -> VoiceWaveformCanvasView {
        let view = VoiceWaveformCanvasView()
        view.store = store
        view.levelProvider = levelProvider
        view.accentColor = accent
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Уровень голоса"
        view.startDisplayLinkIfNeeded()
        return view
    }

    func updateUIView(_ uiView: VoiceWaveformCanvasView, context: Context) {
        uiView.store = store
        uiView.levelProvider = levelProvider
        uiView.accentColor = accent
        if isRecording || store.snapshot().isActive {
            uiView.startDisplayLinkIfNeeded()
        } else {
            uiView.stopDisplayLink()
        }
        uiView.setNeedsDisplay()
    }

    static func dismantleUIView(_ uiView: VoiceWaveformCanvasView, coordinator: ()) {
        uiView.stopDisplayLink()
    }
}

final class VoiceWaveformCanvasView: UIView {
    var store: VoiceWaveformStore?
    var levelProvider: (() -> Float)?
    var accentColor: UIColor = .systemOrange

    private var displayLink: CADisplayLink?

    private let barWidth: CGFloat = 2.5
    private let spacing: CGFloat = 2
    private let minHeight: CGFloat = 3
    private let maxHeight: CGFloat = 56

    private var barStride: CGFloat { barWidth + spacing }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .redraw
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.contentsScale = window?.screen.scale ?? UIScreen.main.scale
        if bounds.width > 1 {
            startDisplayLinkIfNeeded()
            setNeedsDisplay()
        }
    }

    func startDisplayLinkIfNeeded() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(onDisplayTick))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func onDisplayTick() {
        if let store, store.snapshot().isActive, let levelProvider {
            store.append(level: levelProvider())
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard bounds.width > 1, bounds.height > 1 else { return }
        guard let store else { return }

        let snap = store.snapshot()
        guard snap.isActive || !snap.samples.isEmpty else { return }

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setAllowsAntialiasing(true)
        context.interpolationQuality = .high

        let now = CACurrentMediaTime()
        let midY = bounds.midY
        let trailingX = bounds.width - barWidth
        let interval = max(VoiceWaveformStore.sampleInterval, 0.001)
        let slotCount = Int(bounds.width / barStride) + 2
        let maxAge = CGFloat(max(1, slotCount - 1))

        for slotIndex in 0..<slotCount {
            let targetTime = now - CFTimeInterval(slotIndex) * interval
            let level = store.level(at: targetTime)
            let x = trailingX - CGFloat(slotIndex) * barStride
            guard x + barWidth > -barStride, x < bounds.width + barStride else { continue }

            let clamped = CGFloat(min(1, max(0, level)))
            let height = minHeight + (maxHeight - minHeight) * clamped
            let barRect = CGRect(
                x: x,
                y: midY - height / 2,
                width: barWidth,
                height: height
            )
            let path = UIBezierPath(roundedRect: barRect, cornerRadius: barWidth / 2)

            let ageFade = 1.0 - (CGFloat(slotIndex) / maxAge) * 0.75
            let levelAlpha = 0.35 + clamped * 0.65
            let alpha = snap.isActive ? ageFade * levelAlpha : ageFade * 0.35

            context.saveGState()
            path.addClip()

            let topColor = accentColor.withAlphaComponent(alpha * 0.35).cgColor
            let midColor = accentColor.withAlphaComponent(alpha).cgColor
            let bottomColor = accentColor.withAlphaComponent(alpha * 0.35).cgColor
            let colors = [topColor, midColor, bottomColor] as CFArray
            let locations: [CGFloat] = [0, 0.5, 1]
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: barRect.midX, y: barRect.minY),
                    end: CGPoint(x: barRect.midX, y: barRect.maxY),
                    options: []
                )
            }
            context.restoreGState()
        }
    }
}
