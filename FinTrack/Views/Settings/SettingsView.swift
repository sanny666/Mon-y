import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @AppStorage(AppStorageKeys.appTheme) private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage(AppStorageKeys.faceIDEnabled) private var faceIDEnabled = false
    @State private var showExportStub = false
    @State private var showLogin = false

    var body: some View {
        Form {
            Section("Основные") {
                Picker("Валюта по умолчанию", selection: $defaultCurrency) {
                    ForEach(AppCurrency.allCases) { currency in
                        Text(currency.title).tag(currency.rawValue)
                    }
                }
                Picker("Тема", selection: $appThemeRaw) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme.rawValue)
                    }
                }
            }

            Section("Синхронизация") {
                if let banner = container.authBannerMessage {
                    Text(banner)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                if container.dataMode == .synced {
                    LabeledContent("Аккаунт", value: container.authManager.userEmail ?? "—")
                    syncStatusRow
                    Button {
                        Task { await container.performSync() }
                    } label: {
                        Label("Синхронизировать", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled({
                        if case .syncing = container.syncStatus { return true }
                        return false
                    }())
                    Button("Выйти", role: .destructive) {
                        Task { await container.logout() }
                    }
                } else {
                    Text("Локальный режим — данные только на этом устройстве.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(container.needsReauthentication ? "Войти снова" : "Войти для синхронизации") {
                        showLogin = true
                    }
                }
            }

            Section("Безопасность") {
                Toggle("Face ID блокировка", isOn: $faceIDEnabled)
                    .disabled(true)
                Text("Скоро")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Данные") {
                Button("Экспорт CSV") {
                    showExportStub = true
                }
            }

            Section {
                Text("Monëy MVP")
                    .foregroundStyle(.secondary)
                Text(AppConfig.baseURL.absoluteString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("Настройки")
        .sheet(isPresented: $showLogin) {
            LoginView()
                .environment(container)
        }
        .alert("Скоро", isPresented: $showExportStub) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Экспорт CSV появится в следующем обновлении.")
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
}
