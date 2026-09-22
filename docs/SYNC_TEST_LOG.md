# Sync edge-case test log

Дата прогона: 2026-08-26  
Клиент: monёy (локальный workspace)
Сервер: `http://localhost:3020` (Cursor workspace Backend-money)  
Контракт: [`API_CONTRACT.md`](API_CONTRACT.md)

Легенда: **PASS** / **FAIL** / **FIXED** (было сломано → починено в этом прогоне).

---

## 1. Конфликт версий (last-write-wins)

### Воспроизведение (API + код клиента)

1. Создана транзакция через `POST /v1/sync/push` (`amount=100`, `updatedAt=T0`).
2. Сервер обновлён: `PATCH /v1/transactions/:id` → `amount=999`, `updatedAt=T_server > T0`.
3. Клиентский push с **более старым** `updatedAt` и `amount=50`.

### Результат сервера

- Ответ push: `conflicts: [{ entity: "transaction", id, server: { amount: 999, updatedAt: … } }]`, `accepted.transactions: []`.
- Это корректный LWW: клиентская версия старше → конфликт + тело серверной версии.

### Баг в клиенте (до фикса)

- `SyncConflictDTO` игнорировал поле `server`.
- При конфликте делался полный `pull`, но `upsert*` **пропускал** применение, если локальная запись `!isSynced` и `local.updatedAt > remote` — серверная версия из конфликта могла не примениться.
- `recalculateBudgets()` после конфликта не гарантировался.

### Исправление

- Декодирование `conflicts[].server` по типу entity.
- `applyConflicts` → `upsert*(dto, force: true)` + `recalculateBudgets()`.
- Убраны eager HTTP-upsert в Network-репозиториях (источник правды для `isSynced` — только SyncEngine).

### Уточнение сценария «сначала PATCH на сервере, потом локальный edit»

Если локальный `save` ставит `updatedAt = now` **после** серверного PATCH, локальная версия **новее** → push принимается без конфликта (LWW). Проверено: push с `updatedAt` новее серверного → `accepted`, на сервере `amount=77`. Это ожидаемое поведение контракта, не баг.

| Подкейс | Статус |
|---------|--------|
| Local older → conflict + server payload | **PASS** (API) / **FIXED** (клиент применяет `server` + budget recalc) |
| Local newer → accept, overwrite server | **PASS** |

---

## 2. Обрыв сети посреди push / честность `isSynced`

### Аудит кода (до фикса)

- SyncEngine ставил `isSynced = true` **только** после успешного `api.post("/v1/sync/push")` по списку `accepted` — это правильно.
- **Риск:** `Network*Repository.eagerUpsert` мог поставить `isSynced = true` после одиночного `POST /entity`, параллельно с batch sync. При обрыве сети часть записей могла оказаться «synced» через eager, часть — нет; гонки с SyncEngine.

### Исправление

- Eager upsert / DELETE fire-and-forget убраны.
- Сеть для сущностей идёт только через SyncEngine (`push` / `pull` / attachments).
- При transport/timeout ошибке push исключения → `markSynced` не вызывается → `isSynced` остаётся `false` → повтор на следующем триггере.

### Проверка

| Подкейс | Статус |
|---------|--------|
| `isSynced=true` только после confirmed `accepted` | **FIXED** / **PASS** (code audit) |
| Повторный sync после сети досылает pending | **PASS** (by design: pending = `isSynced == false`) |

Полный UI-тест с авиарежимом mid-flight не автоматизировался; логика больше не помечает synced до ответа.

---

## 3. Refresh-токен на грани истечения

### Ограничение среды

Бэкенд крутится как Cursor cloud agent **Backend-money** на `localhost:3020`. Исходников `.env` в этом workspace нет — TTL access на сервере временно не меняли (остаётся `expiresIn: 900`).

### Эмуляция (эквивалент истекшего access)

Контракт: любой 401 на защищённом маршруте → `POST /v1/auth/refresh` → один retry.

| Подкейс | Как проверено | Статус |
|---------|---------------|--------|
| Валидный refresh выдаёт новые токены | `POST /v1/auth/refresh` → 200, новый `accessToken`, `expiresIn=900` | **PASS** |
| Невалидный refresh → 401 | `refreshToken: "nope"` → `401 unauthorized` | **PASS** (API) |
| Клиент при провале refresh | `APIClient` → `onAuthFailure` → `AuthManager.handleAuthFailure` → clear Keychain → `disableSyncedMode` + баннер «Сессия истекла» + кнопка «Войти снова» | **FIXED** / **PASS** (code) |
| Прозрачный retry после refresh | Уже в `APIClient.sendRaw` (один retry после coalesced refresh) | **PASS** (code) |

TTL на бэкенде обратно менять не пришлось (не трогали).

---

## 4. Tombstones (удаление в обе стороны)

### Server → client

1. Создали tx push.
2. `DELETE /v1/transactions/:id` → 204.
3. `GET /v1/sync?since=1970-…` отдаёт запись с `isDeleted: true`.

Клиент: pull применяет DTO с `isDeleted=true`; все `fetch*` в SwiftData/Network репозиториях фильтруют `isDeleted == false` → UI не показывает tombstone; после pull вызывается `recalculateBudgets()`.

| Статус | **PASS** |

### Client → server

1. Soft-delete локально (`isDeleted=true`, `isSynced=false`).
2. Push с `isDeleted: true` → `accepted`.
3. Sync dump: `isDeleted: true` на сервере.

| Статус | **PASS** |

---

## 5. Health-check индикатора и офлайн UX

### Settings статусы (после правок)

| Состояние | Индикатор |
|-----------|-----------|
| Idle | «Ожидание» |
| Syncing | «Синхронизация…» |
| Success | зелёный «OK · HH:mm» |
| Нет сети / timeout | `wifi.slash` + «Нет сети» / «Таймаут сети» |
| Прочая ошибка сервера | треугольник + «Ошибка сервера» |
| Сессия истекла | баннер + режим `.local` + «Войти снова» |

### Офлайн UX

- Save/delete пишут в SwiftData с `isSynced=false` без ожидания сети.
- Sync падает с `NetworkError.noConnection` → статус «Нет сети», очередь не сбрасывается.

| Статус | **PASS** (FIXED UI labels) |

---

## Сводка

| # | Кейс | Итог |
|---|------|------|
| 1 | Conflict LWW | **PASS** после фикса apply `conflicts[].server` + budget recalc |
| 2 | Mid-push / isSynced honesty | **PASS** после удаления eager upsert |
| 3 | Access refresh / expired refresh | **PASS** (API + client); TTL на сервере не меняли (нет доступа к `.env`) |
| 4 | Tombstones bidirectional | **PASS** |
| 5 | Status indicator + offline | **PASS** после уточнения статусов |

**Вывод:** sync-слой достаточно стабилен для перехода к умным фичам. Рекомендация на следующий этап: при наличии доступа к Backend-money `.env` один раз прогнать живой TTL access=30–60s end-to-end в UI.
