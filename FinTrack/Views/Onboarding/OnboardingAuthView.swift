import SwiftUI

struct OnboardingAuthView: View {
    @Environment(AppContainer.self) private var container
    let onSuccess: () -> Void

    @State private var mode: AuthCredentialsForm.Mode = .register
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && password.count >= 8
    }

    var body: some View {
        OnboardingScaffold(
            step: 1,
            title: mode == .register ? "Регистрация" : "Вход",
            subtitle: mode == .register
                ? "Создайте аккаунт, чтобы синхронизировать данные между устройствами."
                : "Войдите в существующий аккаунт monёy."
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Режим", selection: $mode) {
                        Text("Регистрация").tag(AuthCredentialsForm.Mode.register)
                        Text("Вход").tag(AuthCredentialsForm.Mode.login)
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 14) {
                        if mode == .register {
                            OnboardingField(
                                title: "Имя",
                                text: $name,
                                contentType: .name
                            )
                        }
                        OnboardingField(
                            title: "Email",
                            text: $email,
                            keyboard: .emailAddress,
                            contentType: .username,
                            autocapitalization: .never
                        )
                        OnboardingField(
                            title: "Пароль",
                            text: $password,
                            contentType: mode == .register ? .newPassword : .password,
                            isSecure: true
                        )
                    }

                    Text("Пароль не короче 8 символов.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        } footer: {
            OnboardingPrimaryButton(
                title: mode == .register ? "Зарегистрироваться" : "Войти",
                isLoading: isLoading,
                isEnabled: canSubmit
            ) {
                Task { await submit() }
            }
        }
    }

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if mode == .register {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                try await container.register(
                    email: trimmedEmail,
                    password: password,
                    name: trimmedName.isEmpty ? nil : trimmedName
                )
            } else {
                try await container.login(email: trimmedEmail, password: password)
            }
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
