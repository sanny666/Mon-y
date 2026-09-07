import SwiftUI

enum OnboardingLayout {
    static let totalSteps = 4
    static let horizontalPadding: CGFloat = MoneyLayout.pageInset
    static let corner: CGFloat = MoneyLayout.cardRadius
}

struct OnboardingScaffold<Content: View, Footer: View>: View {
    let step: Int
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    Text("monёy")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    OnboardingStepDots(current: step, total: OnboardingLayout.totalSteps)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 20)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            footer
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(.bar)
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(MoneyPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct OnboardingStepDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appAccentColor) private var accent
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? accent : Color.secondary.opacity(0.25))
                    .frame(width: index == current ? 18 : 8, height: 8)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: current)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Шаг \(current) из \(total)")
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().tint(.primary) }
            }
        }
        .buttonStyle(MoneyPrimaryButtonStyle())
        .disabled(!isEnabled || isLoading)
    }
}

struct OnboardingCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        MoneyCard { content }
    }
}

struct OnboardingSelectRow: View {
    @Environment(\.appAccentColor) private var accent
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isSelected ? accent : .secondary)
                        .frame(width: 28)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? accent : Color.secondary.opacity(0.35))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: MoneyLayout.controlRadius, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: MoneyLayout.controlRadius, style: .continuous)
                    .strokeBorder(isSelected ? accent.opacity(0.45) : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var isSecure: Bool = false
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled(keyboard == .emailAddress)
                }
            }
            .textContentType(contentType)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: MoneyLayout.controlRadius, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }
}
