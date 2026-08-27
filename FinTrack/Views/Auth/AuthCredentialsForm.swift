import SwiftUI

struct AuthCredentialsForm: View {
    enum Mode {
        case login
        case register
    }

    @Binding var mode: Mode
    @Binding var email: String
    @Binding var password: String
    @Binding var name: String
    var isLoading: Bool
    var errorMessage: String?
    var onSubmit: () -> Void
    var footer: String? = nil

    private var canSubmit: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && password.count >= 8
    }

    var body: some View {
        Form {
            Section {
                Picker("Режим", selection: $mode) {
                    Text("Регистрация").tag(Mode.register)
                    Text("Вход").tag(Mode.login)
                }
                .pickerStyle(.segmented)
            }

            Section {
                if mode == .register {
                    TextField("Имя (необязательно)", text: $name)
                        .textContentType(.name)
                }
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Пароль (мин. 8 символов)", text: $password)
                    .textContentType(mode == .register ? .newPassword : .password)
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
                    onSubmit()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(mode == .register ? "Зарегистрироваться" : "Войти")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSubmit || isLoading)
            } footer: {
                if let footer {
                    Text(footer)
                }
            }
        }
    }
}
