import SwiftUI

struct AppLockView: View {
    let lockController: AppLockController
    var faceIDEnabled: Bool
    var onBiometricUnlock: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppStorageKeys.appAccentHex) private var appAccentHex = AppAccent.defaultHex
    @State private var pin = ""
    @State private var appeared = false
    @State private var didAutoPrompt = false

    private var accent: Color { Color(hex: appAccentHex) }

    var body: some View {
        ZStack {
            MoneyLockPalette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("monёy")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(MoneyLockPalette.primaryText)
                    .tracking(-0.4)
                    .padding(.top, 28)

                Spacer(minLength: 24)

                AppPINPadView(
                    title: "",
                    subtitle: "",
                    errorMessage: lockController.lastErrorMessage,
                    pin: pin,
                    maxLength: AppLockController.requiredPINLength,
                    style: .premium,
                    onDigit: appendDigit,
                    onDelete: {
                        if !pin.isEmpty { pin.removeLast() }
                    }
                )
                .padding(.horizontal, 28)

                if faceIDEnabled, lockController.isBiometryAvailable {
                    Button {
                        onBiometricUnlock()
                    } label: {
                        Image(systemName: lockController.biometrySymbolName)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(accent)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .strokeBorder(accent.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .accessibilityLabel(lockController.biometryTitle)
                }

                Spacer(minLength: 28)
            }
            .opacity(appeared ? 1 : 0)
        }
        .tint(accent)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.2)) { appeared = true }
            }
            guard !didAutoPrompt else { return }
            didAutoPrompt = true
            if faceIDEnabled, lockController.isBiometryAvailable {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onBiometricUnlock()
                }
            }
        }
    }

    private func appendDigit(_ digit: String) {
        guard pin.count < AppLockController.requiredPINLength else { return }
        pin.append(digit)
        if pin.count == AppLockController.requiredPINLength {
            let ok = lockController.verifyPIN(pin)
            if !ok { pin = "" }
        }
    }
}

struct AppPrivacyCover: View {
    var body: some View {
        ZStack {
            MoneyLockPalette.background
            Text("monёy")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(MoneyLockPalette.primaryText)
                .tracking(-0.4)
        }
        .ignoresSafeArea()
    }
}
