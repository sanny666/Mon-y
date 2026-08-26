import SwiftUI

struct LoginView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var isRegister = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Режим", selection: $isRegister) {
                        Text("Вход").tag(false)
                        Text("Регистрация").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if isRegister {
                        TextField("Имя (необязательно)", text: $name)
                            .textContentType(.name)
                    }
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Пароль (мин. 8)", text: $password)
                        .textContentType(isRegister ? .newPassword : .password)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isRegister ? "Создать аккаунт" : "Войти")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canSubmit || isLoading)
                } footer: {
                    Text("После входа данные синхронизируются с сервером (\(AppConfig.baseURL.host ?? "server")). Локальный режим без аккаунта по-прежнему доступен.")
                }
            }
            .navigationTitle("Синхронизация")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }

    private var canSubmit: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && password.count >= 8
    }

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            if isRegister {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                try await container.register(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    name: trimmedName.isEmpty ? nil : trimmedName
                )
            } else {
                try await container.login(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
