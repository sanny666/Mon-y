import Foundation

/// Sync orchestration stub. Not wired into AppContainer yet.
/// See docs/API_CONTRACT.md §6 Synchronization.
final class SyncEngine {
    /// TODO: Collect local rows with `isSynced == false` (including `isDeleted == true` tombstones),
    /// POST /v1/sync/push with `{ entity: { changes: [...] } }`, mark accepted as synced, handle `conflicts`.
    /// Before push: upload pending local `file://` attachments via POST /v1/transactions/:id/attachment.
    func pushPendingChanges() async throws {
        throw NetworkError.unimplemented(endpoint: "POST /v1/sync/push")
    }

    /// TODO: GET /v1/sync?since=<ISO8601>, apply `changes` (upsert live + soft-delete when `isDeleted: true`),
    /// store `serverTime` as next since cursor.
    /// After applying changes: call `AppContainer.recalculateBudgets()` (same path as local transaction save)
    /// so budgets stay correct when transactions arrive from another device — see SYNC_READINESS.md §4.
    func pullRemoteChanges(since: Date?) async throws {
        _ = since
        throw NetworkError.unimplemented(endpoint: "GET /v1/sync?since=")
    }
}
