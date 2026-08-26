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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: return "Доход"
        case .expense: return "Расход"
        case .transfer: return "Перевод"
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
