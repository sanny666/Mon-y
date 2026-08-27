import Foundation
import SwiftUI
import UIKit

enum AppStorageKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let defaultCurrency = "defaultCurrency"
    static let appTheme = "appTheme"
    static let appAccentHex = "appAccentHex"
    static let faceIDEnabled = "faceIDEnabled"
    static let hasSeededSubcategories = "hasSeededSubcategories"
    static let hasLaunchedInThisInstall = "hasLaunchedInThisInstall"
}

/// UserDefaults vanish on uninstall; Keychain often does not. First launch of a
/// fresh sandbox must drop leftover PIN / tokens so onboarding starts clean.
enum FreshInstall {
    static func resetStaleSecretsIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppStorageKeys.hasLaunchedInThisInstall) else { return }

        let keychain = KeychainStore()
        try? keychain.delete("auth.accessToken")
        try? keychain.delete("auth.refreshToken")
        try? keychain.delete("auth.userEmail")
        try? keychain.delete("auth.userName")
        try? keychain.delete("appLockPIN")
        WidgetSnapshotStore.clear()

        defaults.set(true, forKey: AppStorageKeys.hasLaunchedInThisInstall)
    }
}

enum Greeting {
    private static let russian = Locale(identifier: "ru_RU")

    static func title(at date: Date = .now) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Доброе утро"
        case 12..<17: return "Добрый день"
        case 17..<23: return "Добрый вечер"
        default: return "Доброй ночи"
        }
    }

    static func subtitle(at date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = russian
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d MMMM")
        return formatter.string(from: date)
    }
}

enum CurrencyFormatter {
    static func string(amount: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = currencyCode == "KZT" ? 0 : 2
        formatter.minimumFractionDigits = currencyCode == "KZT" ? 0 : 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount) \(currencyCode)"
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 38, 143, 107)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum IconPalette {
    static let accountIcons = [
        "creditcard.fill", "banknote.fill", "building.columns.fill",
        "dollarsign.circle.fill", "sterlingsign.circle.fill", "eurosign.circle.fill"
    ]

    static let categoryIcons = [
        "cart.fill", "bus.fill", "cup.and.saucer.fill", "house.fill",
        "film.fill", "heart.fill", "banknote.fill", "briefcase.fill",
        "gift.fill", "bolt.fill", "phone.fill", "fork.knife",
        "car.fill", "fuelpump.fill", "tram.fill", "parkingsign.circle.fill",
        "basket.fill", "shippingbox.fill", "wifi", "key.fill",
        "drop.fill", "gamecontroller.fill", "stethoscope", "figure.run",
        "laptopcomputer", "cross.case.fill", "takeoutbag.and.cup.and.straw.fill",
        "rectangle.stack.fill"
    ]

    static let colors = [
        "#268F6B", "#2F6FED", "#C45C26", "#8E44AD",
        "#E74C3C", "#5C6BC0", "#B85C38", "#1ABC9C",
        "#F39C12", "#34495E"
    ]
}

/// Semantic tints for icons (meaning-based, not the app accent).
enum SemanticIcon {
    static let chart = Color(hex: "#2F6FED")
    static let today = Color(hex: "#F5A524")
    static let flame = Color(hex: "#FF6B00")
    static let list = Color(hex: "#5C6BC0")
    static let tag = Color(hex: "#C45C26")
    static let budget = Color(hex: "#8E44AD")
    static let recurring = Color(hex: "#1ABC9C")
    static let goal = Color(hex: "#268F6B")
    static let export = Color(hex: "#5C6BC0")
    static let bank = Color(hex: "#2F6FED")
    static let settings = Color(hex: "#8E8E93")
}

/// Local file helpers for receipt photos until remote upload is wired.
enum AttachmentStore {
    private static var directory: URL {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = root.appendingPathComponent("attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes JPEG bytes and returns a `file://` URL string for `Transaction.attachmentURL`.
    static func saveLocalJPEG(_ data: Data, id: UUID = UUID()) throws -> String {
        let url = directory.appendingPathComponent("\(id.uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url.absoluteString
    }

    static func loadImage(from urlString: String?) -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        if url.isFileURL, let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        // Remote HTTPS: load when network layer is ready; skip for now.
        return nil
    }
}
