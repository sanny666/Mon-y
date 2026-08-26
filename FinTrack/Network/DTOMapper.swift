import Foundation
import SwiftData

enum DTOMapper {
    // MARK: Account

    static func dto(from account: Account) -> AccountDTO {
        AccountDTO(
            id: account.id,
            name: account.name,
            type: account.typeRaw,
            currency: account.currency,
            initialBalance: account.initialBalance,
            icon: account.icon,
            colorHex: account.colorHex,
            createdAt: account.createdAt,
            updatedAt: account.updatedAt,
            isDeleted: account.isDeleted
        )
    }

    static func apply(_ dto: AccountDTO, to account: Account) {
        account.name = dto.name
        account.typeRaw = dto.type
        account.currency = dto.currency
        account.initialBalance = dto.initialBalance
        account.icon = dto.icon
        account.colorHex = dto.colorHex
        account.createdAt = dto.createdAt
        account.updatedAt = dto.updatedAt
        account.isDeleted = dto.isDeleted
        account.isSynced = true
    }

    // MARK: Category

    static func dto(from category: Category) -> CategoryDTO {
        CategoryDTO(
            id: category.id,
            name: category.name,
            icon: category.icon,
            colorHex: category.colorHex,
            type: category.typeRaw,
            parentId: category.parent?.id,
            updatedAt: category.updatedAt,
            isDeleted: category.isDeleted
        )
    }

    static func apply(_ dto: CategoryDTO, to category: Category, parent: Category?) {
        category.name = dto.name
        category.icon = dto.icon
        category.colorHex = dto.colorHex
        category.typeRaw = dto.type
        category.parent = parent
        category.updatedAt = dto.updatedAt
        category.isDeleted = dto.isDeleted
        category.isSynced = true
    }

    // MARK: Transaction

    static func dto(from tx: Transaction) -> TransactionDTO {
        let url = tx.attachmentURL.flatMap { raw -> String? in
            guard let u = URL(string: raw), !u.isFileURL else { return nil }
            return raw
        }
        return TransactionDTO(
            id: tx.id,
            amount: tx.amount,
            type: tx.typeRaw,
            date: tx.date,
            note: tx.note,
            tags: tx.tags,
            attachmentURL: url,
            accountId: tx.account?.id,
            toAccountId: tx.toAccount?.id,
            categoryId: tx.category?.id,
            updatedAt: tx.updatedAt,
            isDeleted: tx.isDeleted
        )
    }

    static func apply(
        _ dto: TransactionDTO,
        to tx: Transaction,
        account: Account?,
        toAccount: Account?,
        category: Category?
    ) {
        tx.amount = dto.amount
        tx.typeRaw = dto.type
        tx.date = dto.date
        tx.note = dto.note
        tx.tags = dto.tags
        if let remote = dto.attachmentURL {
            tx.attachmentURL = remote
        }
        tx.account = account
        tx.toAccount = toAccount
        tx.category = category
        tx.updatedAt = dto.updatedAt
        tx.isDeleted = dto.isDeleted
        tx.isSynced = true
    }

    // MARK: Budget

    static func dto(from budget: Budget) -> BudgetDTO {
        BudgetDTO(
            id: budget.id,
            limitAmount: budget.limitAmount,
            period: budget.periodRaw,
            currentSpent: budget.currentSpent,
            categoryId: budget.category?.id,
            notifiedAt80: budget.notifiedAt80,
            notifiedAt100: budget.notifiedAt100,
            updatedAt: budget.updatedAt,
            isDeleted: budget.isDeleted
        )
    }

    static func apply(_ dto: BudgetDTO, to budget: Budget, category: Category?) {
        budget.limitAmount = dto.limitAmount
        budget.periodRaw = dto.period
        budget.currentSpent = dto.currentSpent
        budget.category = category
        budget.notifiedAt80 = dto.notifiedAt80
        budget.notifiedAt100 = dto.notifiedAt100
        budget.updatedAt = dto.updatedAt
        budget.isDeleted = dto.isDeleted
        budget.isSynced = true
    }

    // MARK: Goal

    static func dto(from goal: Goal) -> GoalDTO {
        GoalDTO(
            id: goal.id,
            name: goal.name,
            targetAmount: goal.targetAmount,
            currentAmount: goal.currentAmount,
            deadline: goal.deadline,
            icon: goal.icon,
            colorHex: goal.colorHex,
            updatedAt: goal.updatedAt,
            isDeleted: goal.isDeleted
        )
    }

    static func apply(_ dto: GoalDTO, to goal: Goal) {
        goal.name = dto.name
        goal.targetAmount = dto.targetAmount
        goal.currentAmount = dto.currentAmount
        goal.deadline = dto.deadline
        goal.icon = dto.icon
        goal.colorHex = dto.colorHex
        goal.updatedAt = dto.updatedAt
        goal.isDeleted = dto.isDeleted
        goal.isSynced = true
    }

    // MARK: Recurring

    static func dto(from item: RecurringTransaction) -> RecurringTransactionDTO {
        RecurringTransactionDTO(
            id: item.id,
            amount: item.amount,
            type: item.typeRaw,
            note: item.note,
            frequency: item.frequencyRaw,
            nextDate: item.nextDate,
            accountId: item.account?.id,
            categoryId: item.category?.id,
            updatedAt: item.updatedAt,
            isDeleted: item.isDeleted
        )
    }

    static func apply(_ dto: RecurringTransactionDTO, to item: RecurringTransaction, account: Account?, category: Category?) {
        item.amount = dto.amount
        item.typeRaw = dto.type
        item.note = dto.note
        item.frequencyRaw = dto.frequency
        item.nextDate = dto.nextDate
        item.account = account
        item.category = category
        item.updatedAt = dto.updatedAt
        item.isDeleted = dto.isDeleted
        item.isSynced = true
    }
}
