import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppLockController.self) private var lockController
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @AppStorage(AppStorageKeys.defaultAccountID) private var defaultAccountID = ""
    @AppStorage(AppStorageKeys.appTheme) private var appThemeRaw = AppTheme.system.rawValue
    @AppStorage(AppStorageKeys.appAccentHex) private var appAccentHex = AppAccent.defaultHex
    @AppStorage(AppStorageKeys.faceIDEnabled) private var faceIDEnabled = false
    @State private var showBiometryUnavailable = false
    @State private var biometryAlertMessage = ""
    @State private var showChangePIN = false
    @State private var changePINPhase: ChangePINPhase = .verify
    @State private var changePINBuffer = ""
    @State private var changePINNew = ""
    @State private var changePINError: String?
    @State private var accounts: [Account] = []

    private enum ChangePINPhase {
        case verify
        case create
        case confirm
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
        Form {
            Section("Основные") {
                Picker("Валюта по умолчанию", selection: $defaultCurrency) {
                    ForEach(AppCurrency.allCases) { currency in
                        Text(currency.title).tag(currency.rawValue)
                    }
                }

                if !accounts.isEmpty {
                    Picker("Счёт по умолчанию", selection: $defaultAccountID) {
                        ForEach(accounts, id: \.id) { account in
                            Text(account.name).tag(account.id.uuidString)
                        }
                    }
                }
            }

            Section("Оформление") {
                Picker("Тема", selection: $appThemeRaw) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme.rawValue)
                    }
                }

                NavigationLink {
                    AccentPickerView()
                } label: {
                    HStack {
                        Text("Цвет акцента")
                        Spacer()
                        Circle()
                            .fill(Color(hex: appAccentHex))
                            .frame(width: 22, height: 22)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                            }
                        Text(AppAccent.preset(forHex: appAccentHex)?.name ?? "Свой")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                LabeledContent("PIN-код", value: lockController.hasPIN ? "Установлен" : "Не задан")
                Button("Сменить PIN") {
                    resetChangePIN()
                    showChangePIN = true
                }
                .disabled(!lockController.hasPIN)

                if lockController.isBiometryAvailable {
                    Toggle("Разблокировка через \(lockController.biometryTitle)", isOn: faceIDBinding)
                } else {
                    Text("Биометрия недоступна — используйте PIN.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Безопасность")
            } footer: {
                if lockController.isBiometryAvailable {
                    Text("PIN обязателен. \(lockController.biometryTitle) — быстрый вход поверх PIN.")
                }
            }

            Section {
                Text("monёy")
                    .foregroundStyle(.secondary)
            }
        }
        .appGroupedList()
        .navigationTitle("Настройки")
        .toolbarTitleDisplayMode(.large)
        .alert("Биометрия недоступна", isPresented: $showBiometryUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(biometryAlertMessage)
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
                    ModalCloseToolbarItem { showChangePIN = false }
                }
            }
            .presentationDetents([.large])
        }
        .onAppear {
            accounts = (try? container.accounts.fetchAll()) ?? []
            if defaultAccountID.isEmpty, let first = accounts.first {
                defaultAccountID = first.id.uuidString
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
            faceIDEnabled = false
        }
    }
}

struct AccentPickerView: View {
    @AppStorage(AppStorageKeys.appAccentHex) private var appAccentHex = AppAccent.defaultHex
    @State private var expandedGroup: AppAccentGroup?

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

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: appAccentHex))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppAccent.preset(forHex: appAccentHex)?.name ?? "Свой цвет")
                        Text(appAccentHex)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ColorPicker("Свой цвет", selection: customAccentBinding, supportsOpacity: false)
            }

            ForEach(AppAccentGroup.allCases) { group in
                DisclosureGroup(
                    isExpanded: expansionBinding(for: group)
                ) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6),
                        spacing: 10
                    ) {
                        ForEach(AppAccent.presets(in: group)) { preset in
                            accentSwatch(preset)
                        }
                    }
                    .padding(.vertical, 6)
                } label: {
                    Text(group.rawValue)
                }
            }
        }
        .appGroupedList()
        .navigationTitle("Цвет акцента")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if expandedGroup == nil {
                expandedGroup = AppAccent.preset(forHex: appAccentHex)?.group
            }
        }
    }

    private func expansionBinding(for group: AppAccentGroup) -> Binding<Bool> {
        Binding(
            get: { expandedGroup == group },
            set: { isExpanded in
                expandedGroup = isExpanded ? group : nil
            }
        )
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
}
