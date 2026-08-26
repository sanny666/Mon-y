import SwiftUI

struct SettingsView: View {
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @AppStorage(AppStorageKeys.appTheme) private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage(AppStorageKeys.faceIDEnabled) private var faceIDEnabled = false
    @State private var showExportStub = false

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
                Text("FinTrack MVP")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Настройки")
        .alert("Скоро", isPresented: $showExportStub) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Экспорт CSV появится в следующем обновлении.")
        }
    }
}
