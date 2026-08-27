import Foundation

// MARK: - Auth

struct AuthTokensDTO: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let refreshExpiresIn: Int
    let user: AuthUserDTO
}

struct AuthUserDTO: Codable {
    let id: UUID
    let email: String
    let name: String?
}

struct LoginRequestDTO: Codable {
    let email: String
    let password: String
}

struct RegisterRequestDTO: Codable {
    let email: String
    let password: String
    let name: String?
}

struct RefreshRequestDTO: Codable {
    let refreshToken: String
}

struct LogoutRequestDTO: Codable {
    let refreshToken: String
}

struct UpdateProfileRequestDTO: Codable {
    let name: String?
}

struct ChangePasswordRequestDTO: Codable {
    let currentPassword: String
    let newPassword: String
}

struct APIErrorBody: Codable {
    let code: String?
    let message: String?
    let details: AnyCodableValue?
}

/// Loose JSON value for error details.
enum AnyCodableValue: Codable {
    case string(String)
    case object([String: AnyCodableValue])
    case array([AnyCodableValue])
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([String: AnyCodableValue].self) { self = .object(v); return }
        if let v = try? c.decode([AnyCodableValue].self) { self = .array(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

// MARK: - Entities

struct AccountDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var type: String
    var currency: String
    var initialBalance: Double
    var icon: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
}

struct CategoryDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var type: String
    var parentId: UUID?
    var updatedAt: Date
    var isDeleted: Bool
}

struct TransactionDTO: Codable, Identifiable {
    var id: UUID
    var amount: Double
    var type: String
    var date: Date
    var note: String
    var tags: [String]
    var attachmentURL: String?
    var accountId: UUID?
    var toAccountId: UUID?
    var categoryId: UUID?
    var updatedAt: Date
    var isDeleted: Bool
}

struct BudgetDTO: Codable, Identifiable {
    var id: UUID
    var limitAmount: Double
    var period: String
    var currentSpent: Double
    var categoryId: UUID?
    var notifiedAt80: Bool
    var notifiedAt100: Bool
    var updatedAt: Date
    var isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, limitAmount, period, currentSpent, categoryId
        case notifiedAt80, notifiedAt100, updatedAt, isDeleted
    }

    init(
        id: UUID,
        limitAmount: Double,
        period: String,
        currentSpent: Double,
        categoryId: UUID?,
        notifiedAt80: Bool,
        notifiedAt100: Bool,
        updatedAt: Date,
        isDeleted: Bool
    ) {
        self.id = id
        self.limitAmount = limitAmount
        self.period = period
        self.currentSpent = currentSpent
        self.categoryId = categoryId
        self.notifiedAt80 = notifiedAt80
        self.notifiedAt100 = notifiedAt100
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        limitAmount = try c.decode(Double.self, forKey: .limitAmount)
        period = try c.decode(String.self, forKey: .period)
        currentSpent = try c.decode(Double.self, forKey: .currentSpent)
        categoryId = try c.decodeIfPresent(UUID.self, forKey: .categoryId)
        notifiedAt80 = try c.decodeIfPresent(Bool.self, forKey: .notifiedAt80) ?? false
        notifiedAt100 = try c.decodeIfPresent(Bool.self, forKey: .notifiedAt100) ?? false
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        isDeleted = try c.decode(Bool.self, forKey: .isDeleted)
    }
}

struct GoalDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var deadline: Date?
    var icon: String
    var colorHex: String
    var updatedAt: Date
    var isDeleted: Bool
}

struct RecurringTransactionDTO: Codable, Identifiable {
    var id: UUID
    var amount: Double
    var type: String
    var note: String
    var frequency: String
    var nextDate: Date
    var accountId: UUID?
    var categoryId: UUID?
    var updatedAt: Date
    var isDeleted: Bool
}

struct ItemsResponse<T: Codable>: Codable {
    let items: [T]
}

struct AttachmentUploadResponse: Codable {
    let attachmentURL: String
    let updatedAt: Date
}

// MARK: - Sync

struct SyncEntityBatch<T: Codable>: Codable {
    var changes: [T]
}

struct SyncPullResponse: Codable {
    let serverTime: Date
    let accounts: SyncEntityBatch<AccountDTO>
    let categories: SyncEntityBatch<CategoryDTO>
    let transactions: SyncEntityBatch<TransactionDTO>
    let budgets: SyncEntityBatch<BudgetDTO>
    let goals: SyncEntityBatch<GoalDTO>
    let recurringTransactions: SyncEntityBatch<RecurringTransactionDTO>
}

struct SyncPushRequest: Codable {
    var accounts: SyncEntityBatch<AccountDTO>
    var categories: SyncEntityBatch<CategoryDTO>
    var transactions: SyncEntityBatch<TransactionDTO>
    var budgets: SyncEntityBatch<BudgetDTO>
    var goals: SyncEntityBatch<GoalDTO>
    var recurringTransactions: SyncEntityBatch<RecurringTransactionDTO>
}

struct SyncPushAccepted: Codable {
    let accounts: [UUID]
    let categories: [UUID]
    let transactions: [UUID]
    let budgets: [UUID]
    let goals: [UUID]
    let recurringTransactions: [UUID]
}

struct SyncConflictDTO {
    let entity: String
    let id: UUID
    let serverAccount: AccountDTO?
    let serverCategory: CategoryDTO?
    let serverTransaction: TransactionDTO?
    let serverBudget: BudgetDTO?
    let serverGoal: GoalDTO?
    let serverRecurring: RecurringTransactionDTO?

    private enum CodingKeys: String, CodingKey {
        case entity, id, server
    }

    static func decode(from decoder: Decoder) throws -> SyncConflictDTO {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let entity = try c.decode(String.self, forKey: .entity)
        let id = try c.decode(UUID.self, forKey: .id)
        switch entity {
        case "account":
            return SyncConflictDTO(
                entity: entity, id: id,
                serverAccount: try c.decode(AccountDTO.self, forKey: .server),
                serverCategory: nil, serverTransaction: nil, serverBudget: nil, serverGoal: nil, serverRecurring: nil
            )
        case "category":
            return SyncConflictDTO(
                entity: entity, id: id,
                serverAccount: nil,
                serverCategory: try c.decode(CategoryDTO.self, forKey: .server),
                serverTransaction: nil, serverBudget: nil, serverGoal: nil, serverRecurring: nil
            )
        case "transaction":
            return SyncConflictDTO(
                entity: entity, id: id,
                serverAccount: nil, serverCategory: nil,
                serverTransaction: try c.decode(TransactionDTO.self, forKey: .server),
                serverBudget: nil, serverGoal: nil, serverRecurring: nil
            )
        case "budget":
            return SyncConflictDTO(
                entity: entity, id: id,
                serverAccount: nil, serverCategory: nil, serverTransaction: nil,
                serverBudget: try c.decode(BudgetDTO.self, forKey: .server),
                serverGoal: nil, serverRecurring: nil
            )
        case "goal":
            return SyncConflictDTO(
                entity: entity, id: id,
                serverAccount: nil, serverCategory: nil, serverTransaction: nil, serverBudget: nil,
                serverGoal: try c.decode(GoalDTO.self, forKey: .server),
                serverRecurring: nil
            )
        case "recurringTransaction", "recurring-transaction", "recurring_transaction":
            return SyncConflictDTO(
                entity: entity, id: id,
                serverAccount: nil, serverCategory: nil, serverTransaction: nil, serverBudget: nil, serverGoal: nil,
                serverRecurring: try c.decode(RecurringTransactionDTO.self, forKey: .server)
            )
        default:
            return SyncConflictDTO(
                entity: entity, id: id,
                serverAccount: nil, serverCategory: nil, serverTransaction: nil,
                serverBudget: nil, serverGoal: nil, serverRecurring: nil
            )
        }
    }

    init(
        entity: String,
        id: UUID,
        serverAccount: AccountDTO?,
        serverCategory: CategoryDTO?,
        serverTransaction: TransactionDTO?,
        serverBudget: BudgetDTO?,
        serverGoal: GoalDTO?,
        serverRecurring: RecurringTransactionDTO?
    ) {
        self.entity = entity
        self.id = id
        self.serverAccount = serverAccount
        self.serverCategory = serverCategory
        self.serverTransaction = serverTransaction
        self.serverBudget = serverBudget
        self.serverGoal = serverGoal
        self.serverRecurring = serverRecurring
    }
}

struct SyncPushResponse: Decodable {
    let serverTime: Date
    let accepted: SyncPushAccepted
    let conflicts: [SyncConflictDTO]

    private enum CodingKeys: String, CodingKey {
        case serverTime, accepted, conflicts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serverTime = try c.decode(Date.self, forKey: .serverTime)
        accepted = try c.decode(SyncPushAccepted.self, forKey: .accepted)
        var conflictsContainer = try c.nestedUnkeyedContainer(forKey: .conflicts)
        var decoded: [SyncConflictDTO] = []
        while !conflictsContainer.isAtEnd {
            let nested = try conflictsContainer.superDecoder()
            decoded.append(try SyncConflictDTO.decode(from: nested))
        }
        conflicts = decoded
    }
}
