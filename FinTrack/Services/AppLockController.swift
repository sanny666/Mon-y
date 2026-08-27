import Foundation
import LocalAuthentication
import Observation

@Observable
@MainActor
final class AppLockController {
    private enum KeychainKey {
        static let pin = "appLockPIN"
    }

    private let keychain = KeychainStore()

    private(set) var isLocked = false
    private(set) var isAuthenticating = false
    private(set) var lastErrorMessage: String?
    /// Observable flag — `hasPIN` alone is computed from Keychain.
    private(set) var pinIsSet = false

    static let requiredPINLength = 4

    var hasPIN: Bool { pinIsSet }

    init() {
        pinIsSet = (try? keychain.get(KeychainKey.pin))?.isEmpty == false
    }

    var isBiometryAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometrySymbolName: String {
        switch LAContext().biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.fill"
        }
    }

    var biometryTitle: String {
        switch LAContext().biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Биометрия"
        }
    }

    func lockIfNeeded(enabled: Bool) {
        guard enabled, hasPIN else {
            isLocked = false
            return
        }
        isLocked = true
    }

    func unlockWithoutAuth() {
        isLocked = false
        lastErrorMessage = nil
    }

    func setPIN(_ pin: String) throws {
        guard Self.isValidPIN(pin) else {
            throw AppLockError.invalidPIN
        }
        try keychain.set(pin, forKey: KeychainKey.pin)
        pinIsSet = true
    }

    func matchesPIN(_ pin: String) -> Bool {
        guard let stored = try? keychain.get(KeychainKey.pin) else { return false }
        return stored == pin
    }

    @discardableResult
    func verifyPIN(_ pin: String) -> Bool {
        let ok = matchesPIN(pin)
        if ok {
            isLocked = false
            lastErrorMessage = nil
        } else {
            lastErrorMessage = "Неверный PIN"
        }
        return ok
    }

    func clearPIN() throws {
        try keychain.delete(KeychainKey.pin)
        pinIsSet = false
        isLocked = false
    }

    static func isValidPIN(_ pin: String) -> Bool {
        pin.count == requiredPINLength && pin.allSatisfy(\.isNumber)
    }

    /// Prefer biometrics when allowed; otherwise caller should show PIN pad.
    @discardableResult
    func authenticateWithBiometrics(reason: String = "Разблокируйте monёy") async -> Bool {
        guard !isAuthenticating else { return false }
        guard isBiometryAvailable else {
            lastErrorMessage = "Биометрия недоступна. Введите PIN."
            return false
        }

        let context = LAContext()
        context.localizedCancelTitle = "Ввести PIN"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            lastErrorMessage = Self.message(for: error)
            return false
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if success {
                isLocked = false
                lastErrorMessage = nil
            }
            return success
        } catch {
            // User cancelled or failed — fall back to PIN UI.
            if let laError = error as? LAError, laError.code == .userCancel || laError.code == .userFallback {
                lastErrorMessage = nil
            } else {
                lastErrorMessage = error.localizedDescription
            }
            return false
        }
    }

    private static func message(for error: NSError?) -> String {
        guard let error else {
            return "Биометрия недоступна. Введите PIN."
        }
        switch LAError.Code(rawValue: error.code) {
        case .passcodeNotSet:
            return "Сначала установите код-пароль на устройстве."
        case .biometryNotAvailable, .biometryNotEnrolled:
            return "Биометрия недоступна. Введите PIN."
        default:
            return error.localizedDescription
        }
    }
}

enum AppLockError: LocalizedError {
    case invalidPIN

    var errorDescription: String? {
        switch self {
        case .invalidPIN:
            return "PIN должен состоять из \(AppLockController.requiredPINLength) цифр."
        }
    }
}
