import SwiftUI

/// Theme-adaptive colors for lock / PIN screens (follows app light/dark/system).
enum MoneyLockPalette {
    static let danger = MoneyPalette.expense

    static var background: Color { MoneyPalette.canvas }
    static var groupedBackground: Color { MoneyPalette.canvas }
    static var surface: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    static var keyFill: Color { Color(uiColor: .secondarySystemFill) }
    static var primaryText: Color { Color.primary }
    static var muted: Color { Color.secondary }
    static var faint: Color { Color.primary.opacity(0.12) }
    static var keyStroke: Color { Color.primary.opacity(0.06) }
    static var keyShadow: Color { Color.black.opacity(0.08) }
}

/// Shared PIN pad. Accent from app tint; chrome from color scheme.
struct AppPINPadView: View {
    enum Style {
        case premium
        case system
    }

    let title: String
    let subtitle: String
    var errorMessage: String? = nil
    let pin: String
    let maxLength: Int
    var style: Style = .premium
    let onDigit: (String) -> Void
    let onDelete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var shakeOffset: CGFloat = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    private var isPremium: Bool { style == .premium }
    private var accent: Color { Color.accentColor }

    var body: some View {
        VStack(spacing: 0) {
            if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: isPremium ? 22 : 26, weight: .bold, design: .rounded))
                        .foregroundStyle(MoneyLockPalette.primaryText)
                        .multilineTextAlignment(.center)

                    if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(MoneyLockPalette.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.bottom, 28)
            }

            pinDots
                .offset(x: shakeOffset)
                .padding(.bottom, 14)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Введено \(pin.count) из \(maxLength) цифр")

            Text(errorMessage ?? " ")
                .font(.footnote.weight(.medium))
                .foregroundStyle(MoneyLockPalette.danger)
                .multilineTextAlignment(.center)
                .frame(minHeight: 18)
                .opacity(errorMessage == nil || errorMessage?.isEmpty == true ? 0 : 1)
                .padding(.bottom, 18)
                .onChange(of: errorMessage) { _, newValue in
                    if let newValue, !newValue.isEmpty {
                        triggerShake()
                    }
                }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(1...9, id: \.self) { digit in
                    pinKey("\(digit)") { onDigit("\(digit)") }
                }
                Color.clear.frame(height: keySize)
                pinKey("0") { onDigit("0") }
                deleteKey
            }
            .padding(.horizontal, 4)
        }
    }

    private var pinDots: some View {
        HStack(spacing: 18) {
            ForEach(0..<maxLength, id: \.self) { index in
                let filled = index < pin.count
                ZStack {
                    Circle()
                        .strokeBorder(
                            filled ? accent.opacity(0.9) : MoneyLockPalette.faint,
                            lineWidth: filled ? 0 : 1.5
                        )
                        .frame(width: 16, height: 16)

                    Circle()
                        .fill(accent)
                        .frame(width: 16, height: 16)
                        .scaleEffect(filled ? 1 : 0.01)
                        .opacity(filled ? 1 : 0)
                        .shadow(
                            color: accent.opacity(filled ? (colorScheme == .dark ? 0.45 : 0.28) : 0),
                            radius: 8,
                            y: 0
                        )
                }
                .animation(
                    reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 0.62),
                    value: filled
                )
            }
        }
    }

    private var keySize: CGFloat { 72 }

    private func pinKey(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(MoneyLockPalette.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: keySize)
                .background(keyBackground)
        }
        .buttonStyle(MoneyPINKeyPressStyle())
    }

    private var deleteKey: some View {
        Button(action: onDelete) {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(MoneyLockPalette.muted)
                .frame(maxWidth: .infinity)
                .frame(height: keySize)
                .background(Color.clear)
        }
        .buttonStyle(MoneyPINKeyPressStyle())
        .disabled(pin.isEmpty)
        .opacity(pin.isEmpty ? 0.28 : 1)
    }

    @ViewBuilder
    private var keyBackground: some View {
        if isPremium {
            Circle()
                .fill(MoneyLockPalette.surface)
                .overlay {
                    Circle()
                        .strokeBorder(MoneyLockPalette.keyStroke, lineWidth: 1)
                }
                .shadow(
                    color: MoneyLockPalette.keyShadow,
                    radius: colorScheme == .dark ? 8 : 6,
                    y: 3
                )
        } else {
            RoundedRectangle(cornerRadius: MoneyLayout.controlRadius, style: .continuous)
                .fill(MoneyLockPalette.surface)
        }
    }

    private func triggerShake() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.05)) { shakeOffset = -10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.linear(duration: 0.05)) { shakeOffset = 10 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.linear(duration: 0.05)) { shakeOffset = -7 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.linear(duration: 0.05)) { shakeOffset = 0 }
        }
    }
}

private struct MoneyPINKeyPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
