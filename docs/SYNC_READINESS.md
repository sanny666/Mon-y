# Sync Readiness — monёy

Аудит локального MVP перед синхронизацией с собственным сервером.  
Сетевой слой **не подключён** в DI. Реализация HTTP и офлайн-очереди — следующий шаг после бэкенда по [`API_CONTRACT.md`](API_CONTRACT.md).

---

## 1. SwiftData-модели

Все модели в `FinTrack/Models/`. У каждой: `id: UUID` с `@Attribute(.unique)`, плюс поля синка `updatedAt`, `isSynced`, `isDeleted`, `serverID`.

Энумы хранятся как `*Raw: String` (см. `FinTrack/Models/Enums.swift`).

### Account (`Account.swift`)

| Поле | Тип | Примечание |
|------|-----|------------|
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | |
| `typeRaw` | `String` | → `AccountType`: `cash`, `card`, `deposit` |
| `currency` | `String` | ISO-код, напр. `KZT` |
| `initialBalance` | `Double` | |
| `icon` | `String` | SF Symbol |
| `colorHex` | `String` | |
| `createdAt` | `Date` | |
| `updatedAt` | `Date` | sync |
| `isSynced` | `Bool` | sync, default `false` |
| `isDeleted` | `Bool` | soft-delete / tombstone, default `false` |
| `serverID` | `String?` | sync, локально; в API не уходит |
| `transactions` | `[Transaction]` | cascade, inverse `Transaction.account` |
| `incomingTransfers` | `[Transaction]` | nullify, inverse `Transaction.toAccount` |
| `recurringTemplates` | `[RecurringTransaction]` | cascade, inverse `RecurringTransaction.account` |

Computed: `type: AccountType`.

### Transaction (`Transaction.swift`)

| Поле | Тип | Примечание |
|------|-----|------------|
| `id` | `UUID` | `@Attribute(.unique)` |
| `amount` | `Double` | |
| `typeRaw` | `String` | → `TransactionType`: `income`, `expense`, `transfer` |
| `date` | `Date` | дата операции |
| `note` | `String` | |
| `tagsCSV` | `String` | локально CSV; в API — `tags: [String]` |
| `attachmentURL` | `String?` | HTTPS после upload или локальный `file://`; бинарь отдельно |
| `updatedAt` | `Date` | sync |
| `isSynced` | `Bool` | sync |
| `isDeleted` | `Bool` | soft-delete |
| `serverID` | `String?` | sync |
| `account` | `Account?` | счёт списания |
| `toAccount` | `Account?` | назначение перевода |
| `category` | `Category?` | |

Computed: `type`, `tags`.

### Category (`Category.swift`)

| Поле | Тип | Примечание |
|------|-----|------------|
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | |
| `icon` | `String` | |
| `colorHex` | `String` | |
| `typeRaw` | `String` | → `CategoryType`: `income`, `expense` |
| `updatedAt` | `Date` | sync |
| `isSynced` | `Bool` | sync |
| `isDeleted` | `Bool` | soft-delete |
| `serverID` | `String?` | sync |
| `parent` | `Category?` | подкатегория |
| `children` | `[Category]` | cascade |
| `transactions` | `[Transaction]` | nullify |
| `budgets` | `[Budget]` | cascade |
| `recurringTemplates` | `[RecurringTransaction]` | nullify |

Computed: `type`, `isSubcategory`, `displayName`, `matchingIDs`.

### Budget (`Budget.swift`)

| Поле | Тип | Примечание |
|------|-----|------------|
| `id` | `UUID` | `@Attribute(.unique)` |
| `limitAmount` | `Double` | |
| `periodRaw` | `String` | → `BudgetPeriod`: `monthly` |
| `currentSpent` | `Double` | денормализовано; клиент пересчитывает |
| `updatedAt` | `Date` | sync |
| `isSynced` | `Bool` | sync |
| `isDeleted` | `Bool` | soft-delete |
| `serverID` | `String?` | sync |
| `category` | `Category?` | |

Computed: `period`, `progress`.

### Goal (`Goal.swift`)

| Поле | Тип | Примечание |
|------|-----|------------|
| `id` | `UUID` | `@Attribute(.unique)` |
| `name` | `String` | |
| `targetAmount` | `Double` | |
| `currentAmount` | `Double` | |
| `deadline` | `Date?` | |
| `icon` | `String` | |
| `colorHex` | `String` | |
| `updatedAt` | `Date` | sync |
| `isSynced` | `Bool` | sync |
| `isDeleted` | `Bool` | soft-delete |
| `serverID` | `String?` | sync |

Relationships: нет. Computed: `progress`.

### RecurringTransaction (`RecurringTransaction.swift`)

| Поле | Тип | Примечание |
|------|-----|------------|
| `id` | `UUID` | `@Attribute(.unique)` |
| `amount` | `Double` | |
| `typeRaw` | `String` | → `TransactionType` |
| `note` | `String` | |
| `frequencyRaw` | `String` | → `RecurringFrequency`: `weekly`, `monthly`, `yearly` |
| `nextDate` | `Date` | |
| `updatedAt` | `Date` | sync |
| `isSynced` | `Bool` | sync |
| `isDeleted` | `Bool` | soft-delete |
| `serverID` | `String?` | sync |
| `account` | `Account?` | |
| `category` | `Category?` | |

Computed: `type`, `frequency`.

### Связи (обзор)

```
Account ──cascade──► Transaction.account
Account ──nullify──► Transaction.toAccount
Account ──cascade──► RecurringTransaction.account
Category ──cascade──► Category.children (parent)
Category ──nullify──► Transaction.category
Category ──cascade──► Budget.category
Category ──nullify──► RecurringTransaction.category
Goal — без связей
```

---

## 2. Repository-протоколы

Файл: `FinTrack/Repositories/RepositoryProtocols.swift`  
Реализации: `FinTrack/Repositories/SwiftDataRepositories.swift`

### AccountRepository → `SwiftDataAccountRepository`

| Метод | Описание |
|-------|----------|
| `fetchAll() throws -> [Account]` | все, sort by name |
| `fetch(id: UUID) throws -> Account?` | по id |
| `save(_ account: Account) throws` | insert если detached + save |
| `delete(_ account: Account) throws` | delete + save |

### CategoryRepository → `SwiftDataCategoryRepository`

| Метод | Описание |
|-------|----------|
| `fetchAll() throws -> [Category]` | |
| `fetch(id: UUID) throws -> Category?` | |
| `fetch(type: CategoryType) throws -> [Category]` | фильтр по typeRaw |
| `fetchRoots() throws -> [Category]` | parent == nil |
| `fetchRoots(type: CategoryType) throws -> [Category]` | |
| `fetchChildren(of parent: Category) throws -> [Category]` | |
| `save(_ category: Category) throws` | |
| `delete(_ category: Category) throws` | |

### TransactionRepository → `SwiftDataTransactionRepository`

| Метод | Описание |
|-------|----------|
| `fetchAll() throws -> [Transaction]` | sort date desc |
| `fetch(id: UUID) throws -> Transaction?` | |
| `fetchRecent(limit: Int) throws -> [Transaction]` | |
| `fetch(accountID: UUID) throws -> [Transaction]` | account или toAccount |
| `fetch(filter: TransactionFilter) throws -> [Transaction]` | account/category/dates/search |
| `save(_ transaction: Transaction) throws` | |
| `delete(_ transaction: Transaction) throws` | |

`TransactionFilter`: `accountID?`, `categoryID?`, `startDate?`, `endDate?`, `searchText`.

### BudgetRepository → `SwiftDataBudgetRepository`

| Метод | Описание |
|-------|----------|
| `fetchAll() throws -> [Budget]` | |
| `fetch(id: UUID) throws -> Budget?` | |
| `save(_ budget: Budget) throws` | |
| `delete(_ budget: Budget) throws` | |

### GoalRepository → `SwiftDataGoalRepository`

| Метод | Описание |
|-------|----------|
| `fetchAll() throws -> [Goal]` | |
| `fetch(id: UUID) throws -> Goal?` | |
| `save(_ goal: Goal) throws` | |
| `delete(_ goal: Goal) throws` | |

### RecurringTransactionRepository → `SwiftDataRecurringTransactionRepository`

| Метод | Описание |
|-------|----------|
| `fetchAll() throws -> [RecurringTransaction]` | sort nextDate |
| `fetch(id: UUID) throws -> RecurringTransaction?` | |
| `save(_ item: RecurringTransaction) throws` | |
| `delete(_ item: RecurringTransaction) throws` | |

Паттерн save: при `modelContext == nil` — `context.insert`, затем `updatedAt = .now`, `isSynced = false`, `context.save()`.

Паттерн delete: **soft-delete** — `isDeleted = true`, `updatedAt = .now`, `isSynced = false`, `context.save()` (без `context.delete`).

Все list/fetch-методы фильтруют `isDeleted == false` по умолчанию.

---

## 3. DI — где подменять реализацию

```
FinTrackApp
  └─ ModelContainer (Schema: 6 моделей)
       └─ RootView (@Environment(\.modelContext))
            └─ AppContainer(context:)          ← единственная точка wiring
                 ├─ accounts    = SwiftDataAccountRepository
                 ├─ categories  = SwiftDataCategoryRepository
                 ├─ transactions= SwiftDataTransactionRepository
                 ├─ budgets     = SwiftDataBudgetRepository
                 ├─ goals       = SwiftDataGoalRepository
                 ├─ recurring   = SwiftDataRecurringTransactionRepository
                 ├─ balanceService / budgetService
                 └─ refreshToken (UI invalidation)
                      │
                      ▼
            .environment(appContainer) → MainTabView / OnboardingView
                      │
            Views: @Environment(AppContainer.self)
            ViewModels: reload/delete(container:) → container.<repo>
```

**Файл wiring:** `FinTrack/App/AppContainer.swift` (инициализатор, строки ~19–28).

**Будущая подмена:** заменить `SwiftData*Repository` на сетевые/гибридные реализации (`Network*Repository` + локальный кэш) **только здесь**. View/ViewModel уже зависят от протоколов.

Заглушки `Network*Repository`, `AuthManager`, `SyncEngine` лежат в `FinTrack/Network/` и **не** подключены в `AppContainer`.

---

## 4. Пересчёт бюджетов (обязательно на pull)

**Где сейчас триггерится `AppContainer.recalculateBudgets()`:**
- `TransactionEditorView.save` — после локального save транзакции
- `TransactionsViewModel.delete` — после удаления транзакции
- `BudgetsViewModel.reload` / `BudgetEditorView.save`

Путь: `AppContainer.recalculateBudgets()` → `budgetService.recalculateAll(budgets:transactions:)` → `context.save()`.

**Требование для SyncEngine:** после применения входящих изменений в `pullRemoteChanges(since:)` **обязательно** вызвать тот же `recalculateBudgets()` (или эквивалент через `BudgetService`), а не только полагаться на локальный save. Иначе бюджеты на втором устройстве останутся stale, пока пользователь сам ничего не сохранит.

Зафиксировано в TODO `SyncEngine.pullRemoteChanges`.

---

## 5. Техдолг перед синком

| # | Проблема | Где | Риск |
|---|----------|-----|------|
| 1 | `recalculateBudgets()` вызывает `context.save()` в обход `BudgetRepository` | `AppContainer.swift` | `updatedAt`/`isSynced` бюджетов не обновятся при пересчёте spent — чинить до двустороннего синка бюджетов |
| 2 | Editor-вьюхи пишут в репо напрямую, минуя ViewModel | `*EditorView`, `OnboardingView` | не ломает контракт; слои расходятся |
| 3 | `SeedDataService` генерирует случайные UUID для дефолтных категорий | `SeedDataService.swift` | на двух устройствах «одинаковые» категории — разные id → дубли. **Блокер первого синка** |
| 4 | `Budget.currentSpent` денормализован | `BudgetService` | после pull всегда пересчитывать локально (см. §4) |
| 5 | Локальные `file://` в `attachmentURL` до upload | `AttachmentStore` | перед push — POST `/v1/transactions/:id/attachment`, подменить на HTTPS |
| 6 | Нет auth / сети в runtime | — | Face ID в Settings — UI-заглушка |

**Закрыто:** soft-delete (`isDeleted`), `attachmentURL` вместо blob, tombstones в sync-потоке контракта.

**Не является обходом репозитория:** ViewModels и Views не держат `ModelContext` (кроме `RootView` для создания контейнера). `@Query` не используется.

---

## 6. Вывод

| Артефакт | Статус |
|----------|--------|
| Модели с sync-полями + `isDeleted` + soft-delete | готово |
| `attachmentURL` + attachment API в контракте | готово |
| Пересчёт бюджетов на pull (док + SyncEngine TODO) | зафиксировано |
| Протоколы репозиториев | готово, DI на SwiftData |
| `docs/API_CONTRACT.md` | контракт для бэкенда |
| `FinTrack/Network/*` | заглушки, **не** в DI |
| HTTP, офлайн-очередь, подмена DI | **следующий шаг** |

Клиент готов к согласованию контракта. После поднятия бэкенда по `API_CONTRACT.md` — реализовать сеть, очередь несинкнутых записей (`isSynced == false`) и подключить `SyncEngine` / auth в `AppContainer`.
