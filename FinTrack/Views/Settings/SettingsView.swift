import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppLockController.self) private var lockController
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @AppStorage(AppStorageKeys.appTheme) private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage(AppStorageKeys.appAccentHex) private var appAccentHex = AppAccent.defaultHex
    @AppStorage(AppStorageKeys.faceIDEnabled) private var faceIDEnabled = false
    @State private var showBiometryUnavailable = false
    @State private var biometryAlertMessage = ""
    @State private var showExportEmpty = false
    @State private var exportErrorMessage: String?
    @State private var shareURL: URL?
    @State private var showChangePIN = false
    @State private var changePINPhase: ChangePINPhase = .verify
    @State private var changePINBuffer = ""
    @State private var changePINNew = ""
    @State private var changePINError: String?

    private enum ChangePINPhase {
        case verify
        case create
        case confirm
    }

    private var customAccentBinding: Binding<Color> {
        Binding(
            get: { Color(hex: appAccentHex) },
            set: { newColor in
                if let hex = newColor.toHexRGB() {
                    appAccentHex = hex
                }
            }
        )
    }

    private var faceIDBinding: Binding<Bool> {
        Binding(
            get: { faceIDEnabled },
            set: { newValue in
                Task { await setFaceIDEnabled(newValue) }
            }
        )
    }

    var body: some View {
        settingsForm
        .navigationTitle("Настройки")
        .alert("Биометрия недоступна", isPresented: $showBiometryUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(biometryAlertMessage)
        }
        .alert("Нет данных", isPresented: $showExportEmpty) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Нет транзакций для экспорта.")
        }
        .alert(
            "Ошибка экспорта",
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let shareURL {
                ActivityShareSheet(items: [shareURL]) {
                    self.shareURL = nil
                }
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showChangePIN) {
            NavigationStack {
                AppPINPadView(
                    title: changePINTitle,
                    subtitle: changePINSubtitle,
                    errorMessage: changePINError,
                    pin: changePINBuffer,
                    maxLength: AppLockController.requiredPINLength,
                    style: .system,
                    onDigit: handleChangePINDigit,
                    onDelete: {
                        if !changePINBuffer.isEmpty { changePINBuffer.removeLast() }
                    }
                )
                .padding()
                .navigationTitle("Смена PIN")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { showChangePIN = false }
                    }
                }
            }
            .presentationDetents([.large])
        }
    }

    private var settingsForm: some View {
        Form {
            Section("Основные") {
                Picker("Валюта по умолчанию", selection: $defaultCurrency) {
                    ForEach(AppCurrency.allCases) { currency in
                        Text(currency.title).tag(currency.rawValue)
                    }
                }
            }

            Section("Оформление") {
                Picker("Тема", selection: $appThemeRaw) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme.rawValue)
                    }
                }

                ForEach(AppAccentGroup.allCases) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.rawValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6),
                            spacing: 10
                        ) {
                            ForEach(AppAccent.presets(in: group)) { preset in
                                accentSwatch(preset)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                ColorPicker("Свой цвет", selection: customAccentBinding, supportsOpacity: false)

                if let selected = AppAccent.preset(forHex: appAccentHex) {
                    LabeledContent("Выбрано", value: selected.name)
                } else {
                    LabeledContent("Выбрано", value: appAccentHex)
                }
            }

            Section("Аккаунт") {
                if let banner = container.authBannerMessage {
                    Text(banner)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                LabeledContent("Email", value: container.authManager.userEmail ?? "—")
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
                Button("Выйти", role: .destructive) {
                    Task { await container.logout() }
                }
            }

            Section("Безопасность") {
                LabeledContent("PIN-код", value: lockController.hasPIN ? "Установлен" : "Не задан")
                Button("Сменить PIN") {
                    resetChangePIN()
                    showChangePIN = true
                }
                .disabled(!lockController.hasPIN)

                if lockController.isBiometryAvailable {
                    Toggle("Разблокировка через \(lockController.biometryTitle)", isOn: faceIDBinding)
                    Text("PIN обязателен. \(lockController.biometryTitle) — быстрый вход поверх PIN.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Биометрия недоступна — используйте PIN.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Данные") {
                Button("Экспорт CSV") {
                    exportCSV()
                }
            }

            Section {
                Text("monёy MVP")
                    .foregroundStyle(.secondary)
                Text(AppConfig.baseURL.absoluteString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var changePINTitle: String {
        switch changePINPhase {
        case .verify: return "Текущий PIN"
        case .create: return "Новый PIN"
        case .confirm: return "Повторите новый PIN"
        }
    }

    private var changePINSubtitle: String {
        switch changePINPhase {
        case .verify: return "Подтвердите текущий код"
        case .create: return "Придумайте новый код из \(AppLockController.requiredPINLength) цифр"
        case .confirm: return "Введите новый код ещё раз"
        }
    }

    private func resetChangePIN() {
        changePINPhase = .verify
        changePINBuffer = ""
        changePINNew = ""
        changePINError = nil
    }

    private func handleChangePINDigit(_ digit: String) {
        changePINError = nil
        guard changePINBuffer.count < AppLockController.requiredPINLength else { return }
        changePINBuffer.append(digit)
        guard changePINBuffer.count == AppLockController.requiredPINLength else { return }

        switch changePINPhase {
        case .verify:
            if lockController.matchesPIN(changePINBuffer) {
                changePINPhase = .create
                changePINBuffer = ""
            } else {
                changePINError = "Неверный PIN"
                changePINBuffer = ""
            }
        case .create:
            changePINNew = changePINBuffer
            changePINBuffer = ""
            changePINPhase = .confirm
        case .confirm:
            guard changePINBuffer == changePINNew else {
                changePINError = "PIN не совпадает"
                changePINBuffer = ""
                return
            }
            do {
                try lockController.setPIN(changePINBuffer)
                showChangePIN = false
            } catch {
                changePINError = error.localizedDescription
                changePINBuffer = ""
            }
        }
    }

    private func setFaceIDEnabled(_ enabled: Bool) async {
        guard lockController.hasPIN else {
            biometryAlertMessage = "Сначала задайте PIN в онбординге."
            showBiometryUnavailable = true
            return
        }
        if enabled {
            guard lockController.isBiometryAvailable else {
                biometryAlertMessage = "Биометрия недоступна на этом устройстве."
                showBiometryUnavailable = true
                return
            }
            let ok = await lockController.authenticateWithBiometrics(
                reason: "Включить \(lockController.biometryTitle) для monёy"
            )
            guard ok else { return }
            faceIDEnabled = true
        } else {
            // Confirm with PIN via temporary pad would be heavier; biometrics or just allow off.
            faceIDEnabled = false
        }
    }

    private func exportCSV() {
        do {
            let transactions = try container.transactions.fetchAll()
            let result = try CSVExportService.export(transactions: transactions)
            shareURL = result.fileURL
        } catch CSVExportService.ExportError.noTransactions {
            showExportEmpty = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func accentSwatch(_ preset: AppAccentPreset) -> some View {
        let isSelected = appAccentHex.uppercased() == preset.hex
        return Button {
            appAccentHex = preset.hex
        } label: {
            Circle()
                .fill(Color(hex: preset.hex))
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(AppAccent.checkmarkColor(forHex: preset.hex))
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(isSelected ? 0.35 : 0.08), lineWidth: isSelected ? 2 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
