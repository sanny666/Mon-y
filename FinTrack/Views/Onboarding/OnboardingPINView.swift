import SwiftUI

struct OnboardingPINView: View {
    @Environment(AppLockController.self) private var lockController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appAccentColor) private var accent
    @AppStorage(AppStorageKeys.faceIDEnabled) private var faceIDEnabled = false

    let onComplete: () -> Void

    private enum Phase {
        case create
        case confirm
    }

    @State private var phase: Phase = .create
    @State private var firstPIN = ""
    @State private var confirmPIN = ""
    @State private var errorMessage: String?
    @State private var enableFaceID = true
    @State private var appeared = false

    private var currentPIN: String {
        phase == .create ? firstPIN : confirmPIN
    }

    var body: some View {
        ZStack {
            MoneyLockPalette.groupedBackground.ignoresSafeArea()

            RadialGradient(
                colors: [
                    accent.opacity(0.14),
                    accent.opacity(0.04),
                    .clear
                ],
                center: .top,
                startRadius: 10,
                endRadius: 380
            )
            .ignoresSafeArea()
            .offset(y: -40)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer(minLength: 12)

                AppPINPadView(
                    title: phase == .create ? "Придумайте PIN" : "Повторите PIN",
                    subtitle: phase == .create
                        ? "Четыре цифры. Только вы будете знать этот код."
                        : "Ещё раз — чтобы ничего не перепутать.",
                    errorMessage: errorMessage,
                    pin: currentPIN,
                    maxLength: AppLockController.requiredPINLength,
                    style: .premium,
                    onDigit: appendDigit,
                    onDelete: deleteDigit
                )
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)

                if phase == .confirm, lockController.isBiometryAvailable {
                    faceIDCard
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 20)
            }
        }
        .tint(accent)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                    appeared = true
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Text("monёy")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(MoneyLockPalette.primaryText)
                    .tracking(-0.3)

                Spacer()

                premiumStepDots
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Защита")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(MoneyLockPalette.primaryText)

                Text("PIN обязателен — без него приложение не откроется.")
                    .font(.subheadline)
                    .foregroundStyle(MoneyLockPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var premiumStepDots: some View {
        HStack(spacing: 6) {
            ForEach(1...OnboardingLayout.totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= 3 ? accent : MoneyLockPalette.faint)
                    .frame(width: index == 3 ? 20 : 7, height: 7)
            }
        }
        .accessibilityLabel("Шаг 3 из \(OnboardingLayout.totalSteps)")
    }

    private var faceIDCard: some View {
        Button {
            enableFaceID.toggle()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: lockController.biometrySymbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(lockController.biometryTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(MoneyLockPalette.primaryText)
                    Text("Быстрый вход. PIN останется запасным.")
                        .font(.caption)
                        .foregroundStyle(MoneyLockPalette.muted)
                }

                Spacer(minLength: 8)

                Image(systemName: enableFaceID ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(enableFaceID ? accent : MoneyLockPalette.faint)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MoneyLockPalette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                enableFaceID
                                    ? accent.opacity(0.45)
                                    : MoneyLockPalette.keyStroke,
                                lineWidth: 1
                            )
                    }
            )
        }
        .buttonStyle(.plain)
    }

    private func appendDigit(_ digit: String) {
        errorMessage = nil
        switch phase {
        case .create:
            guard firstPIN.count < AppLockController.requiredPINLength else { return }
            firstPIN.append(digit)
            if firstPIN.count == AppLockController.requiredPINLength {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        phase = .confirm
                    }
                }
            }
        case .confirm:
            guard confirmPIN.count < AppLockController.requiredPINLength else { return }
            confirmPIN.append(digit)
            if confirmPIN.count == AppLockController.requiredPINLength {
                finishIfReady()
            }
        }
    }

    private func deleteDigit() {
        errorMessage = nil
        switch phase {
        case .create:
            if !firstPIN.isEmpty { firstPIN.removeLast() }
        case .confirm:
            if confirmPIN.isEmpty {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    phase = .create
                    firstPIN = ""
                }
            } else {
                confirmPIN.removeLast()
            }
        }
    }

    private func finishIfReady() {
        guard firstPIN == confirmPIN else {
            errorMessage = "PIN не совпадает. Попробуйте ещё раз."
            confirmPIN = ""
            return
        }
        do {
            try lockController.setPIN(firstPIN)
            faceIDEnabled = enableFaceID && lockController.isBiometryAvailable
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            confirmPIN = ""
        }
    }
}
