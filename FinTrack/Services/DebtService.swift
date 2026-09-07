import Foundation

enum DebtServiceError: LocalizedError {
    case invalidAmount
    case amountExceedsRemaining
    case debtClosed

    var errorDescription: String? {
        switch self {
        case .invalidAmount: return "Введите сумму больше нуля"
        case .amountExceedsRemaining: return "Сумма больше остатка долга"
        case .debtClosed: return "Долг уже закрыт"
        }
    }
}

enum DebtService {
    static func open(
        direction: DebtDirection,
        personName: String,
        amount: Double,
        account: Account,
        date: Date = .now,
        note: String = "",
        dueDate: Date? = nil,
        icon: String = "person.fill",
        colorHex: String = "#C45C26",
        debts: DebtRepository,
        transactions: TransactionRepository
    ) throws -> Debt {
        guard amount.isFinite, amount > 0 else { throw DebtServiceError.invalidAmount }
        let trimmed = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        let debt = Debt(
            personName: trimmed,
            direction: direction,
            originalAmount: amount,
            remainingAmount: amount,
            dueDate: dueDate,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            colorHex: colorHex
        )
        try debts.save(debt)
        let tx = Transaction(
            amount: amount,
            type: direction.openTransactionType,
            date: date,
            note: note.isEmpty ? "\(direction.openActionTitle) · \(trimmed)" : note,
            account: account,
            debt: debt
        )
        try transactions.save(tx)
        return debt
    }

    static func settle(
        debt: Debt,
        amount: Double,
        account: Account,
        date: Date = .now,
        note: String = "",
        debts: DebtRepository,
        transactions: TransactionRepository
    ) throws {
        guard !debt.isClosed else { throw DebtServiceError.debtClosed }
        guard amount.isFinite, amount > 0 else { throw DebtServiceError.invalidAmount }
        guard amount <= debt.remainingAmount + 0.000_001 else { throw DebtServiceError.amountExceedsRemaining }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let tx = Transaction(
            amount: amount,
            type: debt.direction.settleTransactionType,
            date: date,
            note: trimmedNote.isEmpty
                ? "\(debt.direction.settleActionTitle) · \(debt.personName)"
                : trimmedNote,
            account: account,
            debt: debt
        )
        try transactions.save(tx)

        debt.remainingAmount = max(debt.remainingAmount - amount, 0)
        if debt.remainingAmount < 0.000_001 {
            debt.remainingAmount = 0
        }
        try debts.save(debt)
    }
}
