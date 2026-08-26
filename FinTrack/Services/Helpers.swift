import Foundation
import SwiftUI
import UIKit

enum AppStorageKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let defaultCurrency = "defaultCurrency"
    static let appTheme = "appTheme"
    static let faceIDEnabled = "faceIDEnabled"
    static let hasSeededSubcategories = "hasSeededSubcategories"
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
