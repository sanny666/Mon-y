import Foundation
import SwiftUI
import UIKit

enum AppAccentGroup: String, CaseIterable, Identifiable {
    case greens = "Зелёные"
    case teals = "Бирюза"
    case blues = "Синие"
    case purples = "Фиолетовые"
    case pinks = "Розовые"
    case reds = "Красные"
    case oranges = "Оранжевые"
    case yellows = "Жёлтые"
    case neutrals = "Нейтральные"

    var id: String { rawValue }
}

struct AppAccentPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let hex: String
    let group: AppAccentGroup

    init(_ name: String, hex: String, group: AppAccentGroup) {
        self.id = hex.uppercased()
        self.name = name
        self.hex = hex.uppercased()
        self.group = group
    }
}

enum AppAccent {
    static let defaultHex = "#268F6B"
    static let dynamicNegativeHex = "#D43D35"
    static let dynamicNeutralHex = "#E37A22"
    static let dynamicPositiveHex = "#238B62"

    static let presets: [AppAccentPreset] = [
        // Зелёные
        .init("Изумруд", hex: "#268F6B", group: .greens),
        .init("Мята", hex: "#2BB673", group: .greens),
        .init("Лес", hex: "#1B5E3B", group: .greens),
        .init("Лайм", hex: "#7CB342", group: .greens),
        .init("Шалфей", hex: "#6B8F71", group: .greens),
        .init("Олива", hex: "#808000", group: .greens),
        // Бирюза
        .init("Бирюза", hex: "#1ABC9C", group: .teals),
        .init("Волны", hex: "#26A69A", group: .teals),
        .init("Аквамарин", hex: "#00BFA5", group: .teals),
        .init("Морской", hex: "#00897B", group: .teals),
        .init("Циан", hex: "#00ACC1", group: .teals),
        .init("Ледник", hex: "#4DB6AC", group: .teals),
        // Синие
        .init("Океан", hex: "#2F6FED", group: .blues),
        .init("Кобальт", hex: "#1565C0", group: .blues),
        .init("Индиго", hex: "#3F51B5", group: .blues),
        .init("Небо", hex: "#42A5F5", group: .blues),
        .init("Василёк", hex: "#5C6BC0", group: .blues),
        .init("Ультрамарин", hex: "#1A237E", group: .blues),
        // Фиолетовые
        .init("Слива", hex: "#8E44AD", group: .purples),
        .init("Лаванда", hex: "#9575CD", group: .purples),
        .init("Виноград", hex: "#6A1B9A", group: .purples),
        .init("Аметист", hex: "#AB47BC", group: .purples),
        .init("Фиалка", hex: "#7E57C2", group: .purples),
        .init("Орхидея", hex: "#9C27B0", group: .purples),
        // Розовые
        .init("Фуксия", hex: "#E91E63", group: .pinks),
        .init("Роза", hex: "#EC407A", group: .pinks),
        .init("Малина", hex: "#C2185B", group: .pinks),
        .init("Пион", hex: "#F06292", group: .pinks),
        .init("Коралл", hex: "#FF6F61", group: .pinks),
        .init("Магента", hex: "#D81B60", group: .pinks),
        // Красные
        .init("Киноварь", hex: "#E74C3C", group: .reds),
        .init("Рубин", hex: "#C62828", group: .reds),
        .init("Томат", hex: "#E53935", group: .reds),
        .init("Бордо", hex: "#880E4F", group: .reds),
        .init("Алый", hex: "#D32F2F", group: .reds),
        .init("Терракота", hex: "#B85C38", group: .reds),
        // Оранжевые
        .init("Янтарь", hex: "#C45C26", group: .oranges),
        .init("Тыква", hex: "#FB8C00", group: .oranges),
        .init("Персик", hex: "#FF8A65", group: .oranges),
        .init("Мандарин", hex: "#FF7043", group: .oranges),
        .init("Медь", hex: "#D84315", group: .oranges),
        .init("Карамель", hex: "#EF6C00", group: .oranges),
        // Жёлтые
        .init("Шафран", hex: "#F39C12", group: .yellows),
        .init("Золото", hex: "#F9A825", group: .yellows),
        .init("Горчица", hex: "#C0A145", group: .yellows),
        .init("Солнце", hex: "#FDD835", group: .yellows),
        .init("Мёд", hex: "#FFB300", group: .yellows),
        // Нейтральные
        .init("Графит", hex: "#34495E", group: .neutrals),
        .init("Сланец", hex: "#546E7A", group: .neutrals),
        .init("Уголь", hex: "#263238", group: .neutrals),
        .init("Какао", hex: "#6D4C41", group: .neutrals),
        .init("Камень", hex: "#78909C", group: .neutrals)
    ]

    static func presets(in group: AppAccentGroup) -> [AppAccentPreset] {
        presets.filter { $0.group == group }
    }

    static func preset(forHex hex: String) -> AppAccentPreset? {
        let key = hex.uppercased()
        return presets.first { $0.hex == key }
    }

    /// Relative luminance 0…1; used for checkmark contrast on swatches.
    static func luminance(hex: String) -> Double {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r: Double
        let g: Double
        let b: Double
        switch cleaned.count {
        case 6:
            r = Double(int >> 16) / 255
            g = Double(int >> 8 & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        case 8:
            r = Double(int >> 16 & 0xFF) / 255
            g = Double(int >> 8 & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            return 0.3
        }
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    static func checkmarkColor(forHex hex: String) -> Color {
        luminance(hex: hex) > 0.62 ? Color.black.opacity(0.75) : Color.white
    }

    /// A balance-aware accent that stays recognizable and readable at any amount.
    /// The logarithmic scale prevents very large balances from flattening the range.
    static func dynamicHex(for totalBalance: Double) -> String {
        let base: UIColor
        if totalBalance < 0 {
            base = UIColor(Color(hex: dynamicNegativeHex))
        } else if totalBalance > 0 {
            base = UIColor(Color(hex: dynamicPositiveHex))
        } else {
            base = UIColor(Color(hex: dynamicNeutralHex))
        }

        let magnitude = min(log10(abs(totalBalance) + 1) / 7, 1)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return totalBalance < 0 ? dynamicNegativeHex : totalBalance > 0 ? dynamicPositiveHex : dynamicNeutralHex
        }

        let adjustedSaturation = min(1, saturation * (0.72 + 0.28 * magnitude))
        let adjustedBrightness = min(0.82, brightness + 0.08 * (1 - magnitude))
        return Color(
            hue: Double(hue),
            saturation: Double(adjustedSaturation),
            brightness: Double(adjustedBrightness)
        ).toHexRGB() ?? dynamicPositiveHex
    }
}

extension Color {
    /// Converts a SwiftUI Color to `#RRGGBB` for AppStorage.
    func toHexRGB() -> String? {
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            var white: CGFloat = 0
            guard ui.getWhite(&white, alpha: &a) else { return nil }
            let v = Int((white * 255).rounded())
            return String(format: "#%02X%02X%02X", v, v, v)
        }
        let ri = Int((r * 255).rounded())
        let gi = Int((g * 255).rounded())
        let bi = Int((b * 255).rounded())
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }
}

private struct AppAccentColorKey: EnvironmentKey {
    static let defaultValue = Color(hex: AppAccent.defaultHex)
}

extension EnvironmentValues {
    var appAccentColor: Color {
        get { self[AppAccentColorKey.self] }
        set { self[AppAccentColorKey.self] = newValue }
    }
}
