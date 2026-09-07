import SwiftUI

struct OnboardingSetupView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.appAccentColor) private var accentColor
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue

    let onComplete: () -> Void

    @State private var selectedCurrency = AppCurrency.kzt
    @State private var accountName = "Основной счёт"
    @State private var accountType: AccountType = .card
    @State private var initialBalance = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var canContinue: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        OnboardingScaffold(
            step: 2,
            title: "Настройка",
            subtitle: "Выберите валюту и создайте первый счёт. С него начнётся учёт."
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Валюта")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(AppCurrency.allCases) { currency in
                            OnboardingSelectRow(
                                title: currency.title,
                                subtitle: currency.rawValue,
                                isSelected: selectedCurrency == currency
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedCurrency = currency
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Первый счёт")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        OnboardingField(title: "Название", text: $accountName)

                        ForEach(AccountType.allCases) { type in
                            OnboardingSelectRow(
                                title: type.title,
                                systemImage: type.systemImage,
                                isSelected: accountType == type
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    accountType = type
                                }
                            }
                        }

                        OnboardingField(
                            title: "Начальный баланс",
                            text: $initialBalance,
                            keyboard: .decimalPad
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        } footer: {
            OnboardingPrimaryButton(
                title: "Продолжить",
                isLoading: isSaving,
                isEnabled: canContinue
            ) {
                finish()
            }
        }
    }

    private func finish() {
        isSaving = true
        defer { isSaving = false }

        defaultCurrency = selectedCurrency.rawValue
        let balance = Double(initialBalance.replacingOccurrences(of: ",", with: ".")) ?? 0
        let account = Account(
            name: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            type: accountType,
            currency: selectedCurrency.rawValue,
            initialBalance: balance,
            icon: accountType.systemImage + ".fill",
            colorHex: accentColor.toHexRGB() ?? AppAccent.defaultHex
        )
        do {
            try container.accounts.save(account)
            container.seedDefaultCategoriesIfNeeded()
            container.notifyChange()
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
