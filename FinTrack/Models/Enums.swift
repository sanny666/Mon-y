import Foundation

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case cash
    case card
    case deposit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: return "Наличные"
        case .card: return "Карта"
        case .deposit: return "Депозит"
        }
    }

    var systemImage: String {
        switch self {
        case .cash: return "banknote"
        case .card: return "creditcard"
        case .deposit: return "building.columns"
        }
    }
}

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income
    case expense
    case transfer
    case debtBorrow
    case debtLend
    case debtRepay
    case debtReceive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: return "Доход"
        case .expense: return "Расход"
        case .transfer: return "Перевод"
        case .debtBorrow: return "Взял в долг"
        case .debtLend: return "Дал в долг"
        case .debtRepay: return "Отдал долг"
        case .debtReceive: return "Получил долг"
        }
    }

    var isDebt: Bool {
        switch self {
        case .debtBorrow, .debtLend, .debtRepay, .debtReceive: return true
        case .income, .expense, .transfer: return false
        }
    }

    /// Positive effect on the linked account balance.
    var increasesAccountBalance: Bool {
        switch self {
        case .income, .debtBorrow, .debtReceive: return true
        case .expense, .transfer, .debtLend, .debtRepay: return false
        }
    }
}

enum DebtDirection: String, Codable, CaseIterable, Identifiable {
    case iOwe
    case theyOwe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iOwe: return "Я должен"
        case .theyOwe: return "Мне должны"
        }
    }

    var openActionTitle: String {
        switch self {
        case .iOwe: return "Взял в долг"
        case .theyOwe: return "Дал в долг"
        }
    }

    var settleActionTitle: String {
        switch self {
        case .iOwe: return "Отдать"
        case .theyOwe: return "Получить"
        }
    }

    var openTransactionType: TransactionType {
        switch self {
        case .iOwe: return .debtBorrow
        case .theyOwe: return .debtLend
        }
    }

    var settleTransactionType: TransactionType {
        switch self {
        case .iOwe: return .debtRepay
        case .theyOwe: return .debtReceive
        }
    }
}

enum CategoryType: String, Codable, CaseIterable, Identifiable {
    case income
    case expense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: return "Доход"
        case .expense: return "Расход"
        }
    }
}

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable {
    case monthly

    var id: String { rawValue }

    var title: String { "Месяц" }
}

enum RecurringFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: return "Еженедельно"
        case .monthly: return "Ежемесячно"
        case .yearly: return "Ежегодно"
        }
    }
}

enum AppCurrency: String, Codable, CaseIterable, Identifiable {
    case kzt = "KZT"
    case rub = "RUB"
    case usd = "USD"
    case eur = "EUR"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .kzt: return "₸"
        case .rub: return "₽"
        case .usd: return "$"
        case .eur: return "€"
        }
    }

    var title: String {
        switch self {
        case .kzt: return "Тенге (₸)"
        case .rub: return "Рубль (₽)"
        case .usd: return "Доллар ($)"
        case .eur: return "Евро (€)"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Системная"
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        }
    }
}
