import SwiftUI

struct ProfileView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSavingName = false
    @State private var isSavingPassword = false
    @State private var nameMessage: String?
    @State private var nameError: String?
    @State private var passwordMessage: String?
    @State private var passwordError: String?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var storedName: String {
        container.authManager.userName ?? ""
    }

    private var canSaveName: Bool {
        trimmedName != storedName && !isSavingName
    }

    private var canSavePassword: Bool {
        currentPassword.count >= 8
            && newPassword.count >= 8
            && newPassword == confirmPassword
            && newPassword != currentPassword
            && !isSavingPassword
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    ProfileAvatar(initials: container.authManager.initials, size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(container.authManager.displayName)
                            .font(.headline)
                        Text(container.authManager.userEmail ?? "—")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }

            Section("Имя") {
                TextField("Как к вам обращаться", text: $name)
                    .textContentType(.name)
                    .submitLabel(.done)
                Button {
                    Task { await saveName() }
                } label: {
                    if isSavingName {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Сохранить имя")
                    }
                }
                .disabled(!canSaveName)
                if let nameMessage {
                    Text(nameMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let nameError {
                    Text(nameError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                SecureField("Текущий пароль", text: $currentPassword)
                    .textContentType(.password)
                SecureField("Новый пароль", text: $newPassword)
                    .textContentType(.newPassword)
                SecureField("Повторите новый пароль", text: $confirmPassword)
                    .textContentType(.newPassword)
                Button {
                    Task { await savePassword() }
                } label: {
                    if isSavingPassword {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Сменить пароль")
                    }
                }
                .disabled(!canSavePassword)
                if !confirmPassword.isEmpty, newPassword != confirmPassword {
                    Text("Пароли не совпадают")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if let passwordMessage {
                    Text(passwordMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let passwordError {
                    Text(passwordError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Пароль")
            } footer: {
                Text("Новый пароль не короче 8 символов.")
            }

            Section("Синхронизация") {
                if let banner = container.authBannerMessage {
                    Text(banner)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                syncStatusRow
                Button {
                    Task { await container.performSync() }
                } label: {
                    Label("Синхронизировать", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled({
                    if case .syncing = container.syncStatus { return true }
                    return !container.isLoggedIn
                }())
            }

            Section {
                Button("Выйти", role: .destructive) {
                    Task {
                        await container.logout()
                        dismiss()
                    }
                }
            }
        }
        .appGroupedList()
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if name.isEmpty {
                name = storedName
            }
        }
        .onChange(of: container.refreshToken) { _, _ in
            if !canSaveName {
                name = storedName
            }
        }
    }

    @ViewBuilder
    private var syncStatusRow: some View {
        HStack {
            Text("Статус")
            Spacer()
            switch container.syncStatus {
            case .idle:
                Text("Ожидание").foregroundStyle(.secondary)
            case .syncing:
                Label("Синхронизация…", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
            case .success(let date):
                Label("OK · \(date.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            case .error(let message):
                Label(message, systemImage: message == "Нет сети" || message.contains("Таймаут")
                      ? "wifi.slash"
                      : "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }
    }

    private func saveName() async {
        nameError = nil
        nameMessage = nil
        isSavingName = true
        defer { isSavingName = false }
        do {
            try await container.updateProfileName(trimmedName)
            nameMessage = "Имя обновлено"
        } catch {
            nameError = error.localizedDescription
        }
    }

    private func savePassword() async {
        passwordError = nil
        passwordMessage = nil
        guard newPassword == confirmPassword else {
            passwordError = "Пароли не совпадают"
            return
        }
        isSavingPassword = true
        defer { isSavingPassword = false }
        do {
            try await container.changePassword(current: currentPassword, new: newPassword)
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            passwordMessage = "Пароль обновлён"
        } catch {
            passwordError = error.localizedDescription
        }
    }
}

struct ProfileAvatar: View {
    let initials: String
    var size: CGFloat = 32

    var body: some View {
        Text(initials)
            .font(size >= 44 ? .title3.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: size, height: size)
            .background(Color.accentColor.opacity(0.16), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

struct ProfileButton: View {
    var diameter: CGFloat = 22

    @Environment(AppContainer.self) private var container
    @State private var showProfile = false

    var body: some View {
        let _ = container.refreshToken
        Button {
            showProfile = true
        } label: {
            Text(container.authManager.initials)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: diameter, minHeight: diameter)
        }
        .accessibilityLabel("Профиль, \(container.authManager.displayName)")
        .modifier(ProfileButtonStyle())
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .toolbar {
                        ModalCloseToolbarItem { showProfile = false }
                    }
            }
            .presentationDetents([.large])
        }
    }
}

private struct ProfileButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            content.buttonStyle(.plain)
        }
    }
}

struct ProfileToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProfileButton()
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProfileButton()
                    }
                }
            }
    }
}

extension View {
    func profileToolbar() -> some View {
        modifier(ProfileToolbarModifier())
    }
}
