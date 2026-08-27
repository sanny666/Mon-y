import SwiftUI

struct LoginView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var mode: AuthCredentialsForm.Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            AuthCredentialsForm(
                mode: $mode,
                email: $email,
                password: $password,
                name: $name,
                isLoading: isLoading,
                errorMessage: errorMessage,
                onSubmit: { Task { await submit() } },
                footer: "После входа данные синхронизируются с сервером (\(AppConfig.baseURL.host ?? "server"))."
            )
            .navigationTitle(mode == .register ? "Регистрация" : "Вход")
            .toolbar {
                ModalCloseToolbarItem { dismiss() }
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
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
