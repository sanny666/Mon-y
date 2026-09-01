import Foundation
import Security

enum QuickAddKind: String {
    case add
    case voice
}

/// Cross-process flag: Control / Action Button intent (widget) → main app.
/// Uses the shared keychain access group already entitled on both targets.
/// (`OpenURLIntent` with a custom scheme does not deliver `onOpenURL` from Controls.)
enum QuickAddFlag {
    private static let service = "com.sany.fintrack.shared.quickadd"
    private static let account = "pendingAddTransaction"
    /// Matches `$(AppIdentifierPrefix)com.sany.fintrack.shared` for team W8NW533LT9.
    private static let accessGroup = "W8NW533LT9.com.sany.fintrack.shared"

    static let didRequestNotification = Notification.Name("mony.quickAddTransaction")

    static func markPending(kind: QuickAddKind = .add) {
        let data = Data(kind.rawValue.utf8)
        let query: [String: Any] = baseQuery()
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)

        NotificationCenter.default.post(name: didRequestNotification, object: nil)
    }

    /// Returns the pending kind once, then clears it. Legacy `"1"` maps to `.add`.
    static func consumePending() -> QuickAddKind? {
        let query: [String: Any] = baseQuery().merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        SecItemDelete(baseQuery() as CFDictionary)

        guard status == errSecSuccess,
              let data = result as? Data,
              let raw = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        if raw == "1" { return .add }
        return QuickAddKind(rawValue: raw)
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup
        ]
    }
}
