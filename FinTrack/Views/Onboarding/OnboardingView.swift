import SwiftUI

struct OnboardingView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue

    @State private var step = 0
    @State private var selectedCurrency = AppCurrency.kzt
    @State private var accountName = "Основной счёт"
    @State private var accountType: AccountType = .card
    @State private var initialBalance = ""
    @State private var errorMessage: String?

    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ProgressView(value: Double(step + 1), total: 2)
                    .tint(.accentColor)

                if step == 0 {
                    currencyStep
                } else {
                    accountStep
                }

                Spacer()

                Button(step == 0 ? "Далее" : "Начать") {
                    if step == 0 {
                        defaultCurrency = selectedCurrency.rawValue
                        step = 1
                    } else {
                        finish()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(step == 1 && accountName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(24)
            .navigationTitle("Monëy")
            .alert("Ошибка", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var currencyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Выберите валюту по умолчанию")
                .font(.title2.bold())
            Text("Её можно изменить позже в настройках.")
                .foregroundStyle(.secondary)

            Picker("Валюта", selection: $selectedCurrency) {
                ForEach(AppCurrency.allCases) { currency in
                    Text(currency.title).tag(currency)
                }
            }
            .pickerStyle(.inline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accountStep: some View {
        Form {
            Section("Первый счёт") {
                TextField("Название", text: $accountName)
                Picker("Тип", selection: $accountType) {
                    ForEach(AccountType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                TextField("Начальный баланс", text: $initialBalance)
                    .keyboardType(.decimalPad)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func finish() {
        let balance = Double(initialBalance.replacingOccurrences(of: ",", with: ".")) ?? 0
        let account = Account(
            name: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            type: accountType,
            currency: selectedCurrency.rawValue,
            initialBalance: balance,
            icon: accountType.systemImage + ".fill",
            colorHex: "#268F6B"
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
