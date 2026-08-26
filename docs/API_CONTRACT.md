# FinTrack API Contract

Контракт REST API для бэкенда и клиента. Base path: **`/v1`**.  
JSON: **camelCase**. Мультитенантность: все данные scoped по `userId` из JWT.

Связанный аудит клиента: [`SYNC_READINESS.md`](SYNC_READINESS.md).

---

## 1. Общие правила

### Даты

ISO 8601 с таймзоной и миллисекундами:

```
yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX
```

Пример: `2026-08-26T07:41:00.000Z`

### Идентификаторы

- Первичный ключ сущности — клиентский **`id`** (UUID string).
- `POST` идемпотентен: upsert по `id`.
- Локальные поля клиента `isSynced` и `serverID` **не** входят в JSON.
- Поле **`isDeleted`** входит в JSON всех сущностей (tombstone / soft delete). Отдельного списка `deleted: [uuid]` в sync **нет**.

### Tombstones (мягкое удаление)

| Правило | Детали |
|---------|--------|
| Модель | У каждой сущности `isDeleted: boolean` (default `false`) |
| CRUD DELETE | Сервер ставит `isDeleted=true`, обновляет `updatedAt` (не hard-delete) |
| Sync | Записи с `isDeleted: true` идут в обычном потоке изменений (`changes` / `upserted`) |
| Клиент после pull | Получив `isDeleted: true`, помечает локальный tombstone (или hard-delete локально, если история не нужна) |
| Retention | Tombstone на сервере хранится **30 дней**, затем фоновая джоба физически чистит. *Уточнить позже* при необходимости |
| CRUD GET list | По умолчанию отдаёт только `isDeleted=false`; query `?includeDeleted=true` — опционально |

### Auth

Все запросы **кроме** `/v1/auth/*` требуют заголовок:

```
Authorization: Bearer <accessToken>
```

### Content-Type

- JSON: `application/json`
- Вложения: `multipart/form-data` (см. §7)

### Ошибки

Тело:

```json
{
  "code": "validation_error",
  "message": "Human-readable message",
  "details": { "field": "email", "reason": "invalid" }
}
```

| HTTP | Когда | Действие клиента |
|------|--------|------------------|
| **401** | невалидный / истёкший access token | вызвать `POST /auth/refresh`; при неудаче — logout |
| **409** | конфликт версий (`updatedAt` клиента старше серверного) | применить серверную версию из тела / UI conflict |
| **422** | валидация полей | показать `message` / `details` |
| 400 | bad request | |
| 404 | сущность не найдена | |
| 429 | rate limit | retry later |

**409 Conflict body** (пример):

```json
{
  "code": "version_conflict",
  "message": "Server has a newer version",
  "details": {
    "entity": "account",
    "server": { /* полная схема Account */ }
  }
}
```

Правило concurrency: last-write-wins по `updatedAt`. Если клиент присылает `updatedAt` **старше** серверного → **409**. Если новее или равны → принять клиентскую версию (при равных — клиент выигрывает).

---

## 2. Auth

### POST `/v1/auth/register`

**Request:**

```json
{
  "email": "user@example.com",
  "password": "secret-min-8",
  "name": "Sany"
}
```

| Поле | Тип | Обязательно |
|------|-----|-------------|
| `email` | string | да |
| `password` | string | да (min 8) |
| `name` | string | нет |

**Response `201`:** см. AuthTokens ниже.

### POST `/v1/auth/login`

**Request:**

```json
{
  "email": "user@example.com",
  "password": "secret-min-8"
}
```

**Response `200`:** AuthTokens.

### POST `/v1/auth/refresh`

**Request:**

```json
{
  "refreshToken": "<refresh>"
}
```

**Response `200`:** AuthTokens (ротация refresh рекомендуется).

### POST `/v1/auth/logout`

**Request:**

```json
{
  "refreshToken": "<refresh>"
}
```

**Response `204`:** пусто. Инвалидация refresh на сервере.

### AuthTokens (ответ register / login / refresh)

```json
{
  "accessToken": "<jwt>",
  "refreshToken": "<opaque-or-jwt>",
  "expiresIn": 900,
  "refreshExpiresIn": 2592000,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "name": "Sany"
  }
}
```

| Поле | Значение |
|------|----------|
| `expiresIn` | **900** секунд (15 мин) — TTL access |
| `refreshExpiresIn` | **2592000** секунд (30 дней) — TTL refresh |
| `user.id` | UUID string |
| `user.name` | string \| null |

---

## 3. Энумы (string)

| Enum | Values |
|------|--------|
| `AccountType` | `cash`, `card`, `deposit` |
| `TransactionType` | `income`, `expense`, `transfer` |
| `CategoryType` | `income`, `expense` |
| `BudgetPeriod` | `monthly` |
| `RecurringFrequency` | `weekly`, `monthly`, `yearly` |

---

## 4. Схемы сущностей

UUID в JSON — **string**. Связи — `*Id` поля, не вложенные объекты.

### Account

```json
{
  "id": "uuid",
  "name": "Карта",
  "type": "card",
  "currency": "KZT",
  "initialBalance": 100000.0,
  "icon": "creditcard.fill",
  "colorHex": "#268F6B",
  "createdAt": "2026-08-26T07:41:00.000Z",
  "updatedAt": "2026-08-26T07:41:00.000Z",
  "isDeleted": false
}
```

| Поле | Тип | Обязательно | Примечание |
|------|-----|-------------|------------|
| `id` | string (UUID) | да | |
| `name` | string | да | |
| `type` | AccountType | да | |
| `currency` | string | да | ISO 4217 |
| `initialBalance` | number | да | |
| `icon` | string | да | |
| `colorHex` | string | да | |
| `createdAt` | string (ISO8601) | да | |
| `updatedAt` | string (ISO8601) | да | concurrency |
| `isDeleted` | boolean | да | tombstone |

### Category

```json
{
  "id": "uuid",
  "name": "Продукты",
  "icon": "cart.fill",
  "colorHex": "#C45C26",
  "type": "expense",
  "parentId": null,
  "updatedAt": "2026-08-26T07:41:00.000Z",
  "isDeleted": false
}
```

| Поле | Тип | Обязательно |
|------|-----|-------------|
| `id` | string (UUID) | да |
| `name` | string | да |
| `icon` | string | да |
| `colorHex` | string | да |
| `type` | CategoryType | да |
| `parentId` | string (UUID) \| null | нет (default null) |
| `updatedAt` | string (ISO8601) | да |
| `isDeleted` | boolean | да |

### Transaction

```json
{
  "id": "uuid",
  "amount": 1500.5,
  "type": "expense",
  "date": "2026-08-26T07:41:00.000Z",
  "note": "Магазин",
  "tags": ["еда", "дом"],
  "attachmentURL": null,
  "accountId": "uuid",
  "toAccountId": null,
  "categoryId": "uuid",
  "updatedAt": "2026-08-26T07:41:00.000Z",
  "isDeleted": false
}
```

| Поле | Тип | Обязательно | Примечание |
|------|-----|-------------|------------|
| `id` | string (UUID) | да | |
| `amount` | number | да | > 0 |
| `type` | TransactionType | да | |
| `date` | string (ISO8601) | да | |
| `note` | string | да | может быть `""` |
| `tags` | string[] | да | не CSV |
| `attachmentURL` | string \| null | нет | HTTPS URL после upload; бинарь **не** в JSON (§7) |
| `accountId` | string (UUID) \| null | нет | обязателен для income/expense |
| `toAccountId` | string (UUID) \| null | нет | для `transfer` |
| `categoryId` | string (UUID) \| null | нет | |
| `updatedAt` | string (ISO8601) | да | |
| `isDeleted` | boolean | да | |

### Budget

```json
{
  "id": "uuid",
  "limitAmount": 50000.0,
  "period": "monthly",
  "currentSpent": 12000.0,
  "categoryId": "uuid",
  "notifiedAt80": false,
  "notifiedAt100": false,
  "updatedAt": "2026-08-26T07:41:00.000Z",
  "isDeleted": false
}
```

| Поле | Тип | Обязательно | Примечание |
|------|-----|-------------|------------|
| `id` | string (UUID) | да | |
| `limitAmount` | number | да | |
| `period` | BudgetPeriod | да | |
| `currentSpent` | number | да | **клиент пересчитывает** после pull; сервер хранит как есть |
| `categoryId` | string (UUID) \| null | нет | |
| `notifiedAt80` | boolean | да | клиент: одно уведомление на 80% за период; сброс в новом периоде |
| `notifiedAt100` | boolean | да | клиент: одно уведомление на 100%+ за период; сброс в новом периоде |
| `updatedAt` | string (ISO8601) | да | |
| `isDeleted` | boolean | да | |

### Goal

```json
{
  "id": "uuid",
  "name": "Отпуск",
  "targetAmount": 500000.0,
  "currentAmount": 120000.0,
  "deadline": "2026-12-31T00:00:00.000Z",
  "icon": "flag.fill",
  "colorHex": "#268F6B",
  "updatedAt": "2026-08-26T07:41:00.000Z",
  "isDeleted": false
}
```

| Поле | Тип | Обязательно |
|------|-----|-------------|
| `id` | string (UUID) | да |
| `name` | string | да |
| `targetAmount` | number | да |
| `currentAmount` | number | да |
| `deadline` | string (ISO8601) \| null | нет |
| `icon` | string | да |
| `colorHex` | string | да |
| `updatedAt` | string (ISO8601) | да |
| `isDeleted` | boolean | да |

### RecurringTransaction

```json
{
  "id": "uuid",
  "amount": 25000.0,
  "type": "expense",
  "note": "Аренда",
  "frequency": "monthly",
  "nextDate": "2026-09-01T00:00:00.000Z",
  "accountId": "uuid",
  "categoryId": "uuid",
  "updatedAt": "2026-08-26T07:41:00.000Z",
  "isDeleted": false
}
```

| Поле | Тип | Обязательно |
|------|-----|-------------|
| `id` | string (UUID) | да |
| `amount` | number | да |
| `type` | TransactionType | да |
| `note` | string | да |
| `frequency` | RecurringFrequency | да |
| `nextDate` | string (ISO8601) | да |
| `accountId` | string (UUID) \| null | нет |
| `categoryId` | string (UUID) \| null | нет |
| `updatedAt` | string (ISO8601) | да |
| `isDeleted` | boolean | да |

---

## 5. CRUD-эндпоинты

Для каждой коллекции одинаковый набор. `:id` — UUID string.

### Accounts — `/v1/accounts`

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/v1/accounts` | — | `200` `{ "items": [Account] }` |
| GET | `/v1/accounts/:id` | — | `200` Account |
| POST | `/v1/accounts` | Account | `201` Account (upsert by id) |
| PATCH | `/v1/accounts/:id` | partial Account | `200` Account |
| DELETE | `/v1/accounts/:id` | — | `204` |

### Categories — `/v1/categories`

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/v1/categories` | — | `200` `{ "items": [Category] }` |
| GET | `/v1/categories/:id` | — | `200` Category |
| POST | `/v1/categories` | Category | `201` Category |
| PATCH | `/v1/categories/:id` | partial | `200` Category |
| DELETE | `/v1/categories/:id` | — | `204` |

Query (опционально): `?type=expense`, `?rootsOnly=true`.

### Transactions — `/v1/transactions`

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/v1/transactions` | — | `200` `{ "items": [Transaction] }` |
| GET | `/v1/transactions/:id` | — | `200` Transaction |
| POST | `/v1/transactions` | Transaction | `201` Transaction |
| PATCH | `/v1/transactions/:id` | partial | `200` Transaction |
| DELETE | `/v1/transactions/:id` | — | `204` |

Query (опционально): `accountId`, `categoryId`, `startDate`, `endDate`, `limit`.

### Budgets — `/v1/budgets`

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/v1/budgets` | — | `200` `{ "items": [Budget] }` |
| GET | `/v1/budgets/:id` | — | `200` Budget |
| POST | `/v1/budgets` | Budget | `201` Budget |
| PATCH | `/v1/budgets/:id` | partial | `200` Budget |
| DELETE | `/v1/budgets/:id` | — | `204` |

### Goals — `/v1/goals`

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/v1/goals` | — | `200` `{ "items": [Goal] }` |
| GET | `/v1/goals/:id` | — | `200` Goal |
| POST | `/v1/goals` | Goal | `201` Goal |
| PATCH | `/v1/goals/:id` | partial | `200` Goal |
| DELETE | `/v1/goals/:id` | — | `204` |

### Recurring transactions — `/v1/recurring-transactions`

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/v1/recurring-transactions` | — | `200` `{ "items": [RecurringTransaction] }` |
| GET | `/v1/recurring-transactions/:id` | — | `200` RecurringTransaction |
| POST | `/v1/recurring-transactions` | RecurringTransaction | `201` |
| PATCH | `/v1/recurring-transactions/:id` | partial | `200` |
| DELETE | `/v1/recurring-transactions/:id` | — | `204` |

Cascade на сервере: soft-delete Account/Category должен каскадно помечать зависимые записи `isDeleted=true` (или возвращать 422 при нарушении FK — зафиксировать при реализации). Soft-delete через `DELETE` HTTP = `isDeleted=true`, не физическое удаление.

---

## 6. Синхронизация

### GET `/v1/sync?since=<ISO8601>`

Инкрементальный pull: все сущности с `updatedAt > since` (строго больше), **включая** записи с `isDeleted: true` (tombstones в том же потоке).

Отдельного массива `deleted: [uuid]` **нет** — удаления едут как обычные объекты с `isDeleted: true`.

**Response `200`:**

```json
{
  "serverTime": "2026-08-26T08:00:00.000Z",
  "accounts": {
    "changes": [ /* Account, в т.ч. isDeleted: true */ ]
  },
  "categories": {
    "changes": []
  },
  "transactions": {
    "changes": []
  },
  "budgets": {
    "changes": []
  },
  "goals": {
    "changes": []
  },
  "recurringTransactions": {
    "changes": []
  }
}
```

| Поле | Тип | Описание |
|------|-----|----------|
| `serverTime` | ISO8601 | клиент сохраняет как следующий `since` |
| `*.changes` | array | сущности с `updatedAt > since` (живые и tombstones) |

Без `since` (или epoch) — полный dump всех не-очищенных записей (включая tombstones младше retention).

**Клиент при применении change с `isDeleted: true`:** помечает локальный tombstone (`isDeleted=true`) или физически удаляет локальную копию, если история на устройстве не нужна. После успешного push tombstone можно hard-delete локально при `isSynced=true`.

### POST `/v1/sync/push`

Батч локальных изменений. Записи с `isDeleted: true` — **часть обычного батча**, не отдельный эндпоинт.

**Request:**

```json
{
  "accounts": {
    "changes": [ /* Account incl. isDeleted: true */ ]
  },
  "categories": { "changes": [] },
  "transactions": { "changes": [] },
  "budgets": { "changes": [] },
  "goals": { "changes": [] },
  "recurringTransactions": { "changes": [] }
}
```

**Response `200`:**

```json
{
  "serverTime": "2026-08-26T08:00:00.000Z",
  "accepted": {
    "accounts": ["uuid"],
    "categories": [],
    "transactions": [],
    "budgets": [],
    "goals": [],
    "recurringTransactions": []
  },
  "conflicts": [
    {
      "entity": "account",
      "id": "uuid",
      "server": { /* Account */ }
    }
  ]
}
```

- Успешные changes → id в `accepted`; клиент ставит `isSynced = true`.
- Конфликт по `updatedAt` → запись в `conflicts` (HTTP 200 для батча; одиночный CRUD может вернуть 409).
- Порядок применения на сервере: categories → accounts → transactions / budgets / recurring → goals (FK).

### Retention tombstones

Сервер хранит soft-deleted записи **30 дней** с момента `updatedAt` удаления, затем фоновая джоба hard-delete. *Политика 30 дней — дефолт, уточнить позже.*

---

## 7. Вложения транзакций

Бинарные данные **никогда** не входят в entity JSON / sync batch. В sync синкается только строка `attachmentURL`.

### Ограничения

| Параметр | Значение |
|----------|----------|
| Макс. размер | **5 MB** |
| Форматы | `image/jpeg`, `image/png` |
| Поле multipart | `file` |

Превышение размера / неверный MIME → **422**.

### Эндпоинты

| Method | Path | Описание |
|--------|------|----------|
| **POST** | `/v1/transactions/:id/attachment` | `multipart/form-data` с полем `file`. Сохраняет файл в object storage, пишет HTTPS URL в `attachmentURL`, обновляет `updatedAt`. **Response `200`:** `{ "attachmentURL": "https://…", "updatedAt": "…" }` |
| **GET** | `/v1/transactions/:id/attachment` | **302 Redirect** на `attachmentURL` (signed/public CDN URL). Если вложения нет → **404**. Клиент также может качать файл напрямую по `attachmentURL` из entity |
| **DELETE** | `/v1/transactions/:id/attachment` | Удаляет файл, ставит `attachmentURL: null`, обновляет `updatedAt`. **Response `204`** |

После POST/DELETE транзакция попадает в следующий `GET /sync` с новым `attachmentURL` / `null`.

Локально до upload клиент может хранить `file://…` в `attachmentURL`; перед push нужно загрузить файл через POST attachment и подменить URL на серверный.

---

## 8. Чеклист для бэкенд-агента

- [ ] `/v1/auth/register|login|refresh|logout` + JWT access 15m / refresh 30d
- [ ] Bearer на всех non-auth маршрутах
- [ ] CRUD × 6 сущностей; DELETE = soft-delete (`isDeleted=true`)
- [ ] `isDeleted` во всех схемах; sync через `changes` (tombstones в потоке, без отдельного `deleted[]`)
- [ ] Retention tombstones 30 дней (+ фоновая чистка)
- [ ] `GET /v1/sync?since=` + `POST /v1/sync/push`
- [ ] Optimistic concurrency по `updatedAt` (409 / conflicts в push)
- [ ] Attachment: POST/GET(302)/DELETE, max 5MB, jpeg/png, ответ с `attachmentURL`
- [ ] Ошибки 401 / 409 / 422 в формате `{ code, message, details? }`
- [ ] ISO8601 dates with timezone
