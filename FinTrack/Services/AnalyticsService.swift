import Foundation

enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "Неделя"
        case .month: return "Месяц"
        case .quarter: return "Квартал"
        case .year: return "Год"
        }
    }

    func dateInterval(around date: Date = .now, calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)
                ?? DateInterval(start: date, end: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date)
                ?? DateInterval(start: date, end: date)
        case .quarter:
            return calendar.dateInterval(of: .quarter, for: date)
                ?? DateInterval(start: date, end: date)
        case .year:
            return calendar.dateInterval(of: .year, for: date)
                ?? DateInterval(start: date, end: date)
        }
    }
}

struct DailyAmountPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let amount: Double
}

struct CategoryExpenseSlice: Identifiable {
    var id: String { categoryKey }
    let categoryKey: String
    let name: String
    let colorHex: String
    let amount: Double
}

struct MonthIncomeExpense: Identifiable {
    var id: Date { monthStart }
    let monthStart: Date
    let income: Double
    let expense: Double
}

struct BalancePoint: Identifiable {
    var id: Date { date }
    let date: Date
    let balance: Double
}

struct AnalyticsService {
    private let calendar = Calendar.current

    func dailyExpenses(transactions: [Transaction], days: Int = 30, around date: Date = .now) -> [DailyAmountPoint] {
        guard days > 0 else { return [] }
        let endDay = calendar.startOfDay(for: date)
        guard let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) else { return [] }

        var totals: [Date: Double] = [:]
        for offset in 0..<days {
            if let day = calendar.date(byAdding: .day, value: offset, to: startDay) {
                totals[day] = 0
            }
        }

        var hasData = false
        for tx in transactions where tx.type == .expense {
            let day = calendar.startOfDay(for: tx.date)
            guard day >= startDay, day <= endDay else { continue }
            totals[day, default: 0] += tx.amount
            hasData = true
        }

        guard hasData else { return [] }
        return totals.keys.sorted().map { DailyAmountPoint(date: $0, amount: totals[$0] ?? 0) }
    }

    func expensesByCategory(
        transactions: [Transaction],
        period: AnalyticsPeriod,
        around date: Date = .now
    ) -> [CategoryExpenseSlice] {
        let range = period.dateInterval(around: date, calendar: calendar)
        var buckets: [String: (name: String, colorHex: String, amount: Double)] = [:]

        for tx in transactions where tx.type == .expense && range.contains(tx.date) {
            let key = tx.category?.id.uuidString ?? "none"
            let name = tx.category?.name ?? "Без категории"
            let color = tx.category?.colorHex ?? "#8E8E93"
            var bucket = buckets[key] ?? (name: name, colorHex: color, amount: 0)
            bucket.amount += tx.amount
            buckets[key] = bucket
        }

        return buckets
            .map { CategoryExpenseSlice(categoryKey: $0.key, name: $0.value.name, colorHex: $0.value.colorHex, amount: $0.value.amount) }
            .sorted { $0.amount > $1.amount }
    }

    func incomeExpenseByMonth(transactions: [Transaction], months: Int = 12, around date: Date = .now) -> [MonthIncomeExpense] {
        guard months > 0 else { return [] }
        guard let currentMonth = calendar.dateInterval(of: .month, for: date)?.start else { return [] }
        guard let firstMonth = calendar.date(byAdding: .month, value: -(months - 1), to: currentMonth) else { return [] }

        var result: [MonthIncomeExpense] = []
        var hasData = false

        for offset in 0..<months {
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: firstMonth),
                  let interval = calendar.dateInterval(of: .month, for: monthStart) else { continue }

            var income = 0.0
            var expense = 0.0
            for tx in transactions where interval.contains(tx.date) {
                switch tx.type {
                case .income:
                    income += tx.amount
                    hasData = true
                case .expense:
                    expense += tx.amount
                    hasData = true
                case .transfer, .debtBorrow, .debtLend, .debtRepay, .debtReceive:
                    break
                }
            }
            result.append(MonthIncomeExpense(monthStart: monthStart, income: income, expense: expense))
        }

        return hasData ? result : []
    }

    func balanceSeries(
        accounts: [Account],
        transactions: [Transaction],
        days: Int = 90,
        around date: Date = .now
    ) -> [BalancePoint] {
        guard days > 0, !accounts.isEmpty else { return [] }
        let endDay = calendar.startOfDay(for: date)
        guard let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) else { return [] }

        let startingBalance = accounts.reduce(0.0) { $0 + $1.initialBalance }
        let chronological = transactions.sorted { $0.date < $1.date }

        var running = startingBalance
        var eventsBeforeStart: [(Date, Double)] = []
        var eventsInRange: [(Date, Double)] = []

        for tx in chronological {
            let delta = balanceDelta(for: tx)
            guard delta != 0 else { continue }
            let day = calendar.startOfDay(for: tx.date)
            if day < startDay {
                eventsBeforeStart.append((day, delta))
            } else if day <= endDay {
                eventsInRange.append((day, delta))
            }
        }

        for event in eventsBeforeStart {
            running += event.1
        }

        var byDay: [Date: Double] = [:]
        for event in eventsInRange {
            byDay[event.0, default: 0] += event.1
        }

        var points: [BalancePoint] = []
        var current = running
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            current += byDay[day] ?? 0
            points.append(BalancePoint(date: day, balance: current))
        }

        let hasMovement = !eventsBeforeStart.isEmpty || !eventsInRange.isEmpty
            || accounts.contains { $0.initialBalance != 0 }
        return hasMovement ? points : []
    }

    private func balanceDelta(for tx: Transaction) -> Double {
        switch tx.type {
        case .income, .debtBorrow, .debtReceive:
            return tx.amount
        case .expense, .debtLend, .debtRepay:
            return -tx.amount
        case .transfer:
            // Net across all accounts is zero; omit from total-balance series.
            return 0
        }
    }
}
