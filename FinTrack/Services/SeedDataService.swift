import Foundation

enum SeedDataService {
    struct SubcategorySeed {
        let name: String
        let icon: String
    }

    struct CategorySeed {
        let name: String
        let icon: String
        let colorHex: String
        let type: CategoryType
        let subcategories: [SubcategorySeed]
    }

    static let defaultTree: [CategorySeed] = [
        CategorySeed(
            name: "Зарплата",
            icon: "banknote.fill",
            colorHex: "#2E7D4F",
            type: .income,
            subcategories: [
                .init(name: "Основная", icon: "banknote.fill"),
                .init(name: "Премия", icon: "gift.fill")
            ]
        ),
        CategorySeed(
            name: "Подработка",
            icon: "briefcase.fill",
            colorHex: "#3D8B6E",
            type: .income,
            subcategories: [
                .init(name: "Фриланс", icon: "laptopcomputer"),
                .init(name: "Разовые", icon: "bolt.fill")
            ]
        ),
        CategorySeed(
            name: "Продукты",
            icon: "cart.fill",
            colorHex: "#C45C26",
            type: .expense,
            subcategories: [
                .init(name: "Супермаркет", icon: "cart.fill"),
                .init(name: "Рынок", icon: "basket.fill"),
                .init(name: "Доставка", icon: "shippingbox.fill")
            ]
        ),
        CategorySeed(
            name: "Транспорт",
            icon: "bus.fill",
            colorHex: "#2F6FED",
            type: .expense,
            subcategories: [
                .init(name: "Такси", icon: "car.fill"),
                .init(name: "Бензин", icon: "fuelpump.fill"),
                .init(name: "Билет", icon: "tram.fill"),
                .init(name: "Парковка", icon: "parkingsign.circle.fill")
            ]
        ),
        CategorySeed(
            name: "Кафе",
            icon: "cup.and.saucer.fill",
            colorHex: "#B85C38",
            type: .expense,
            subcategories: [
                .init(name: "Ресторан", icon: "fork.knife"),
                .init(name: "Кофейня", icon: "cup.and.saucer.fill"),
                .init(name: "Фастфуд", icon: "takeoutbag.and.cup.and.straw.fill")
            ]
        ),
        CategorySeed(
            name: "Жильё",
            icon: "house.fill",
            colorHex: "#5C6BC0",
            type: .expense,
            subcategories: [
                .init(name: "Аренда", icon: "key.fill"),
                .init(name: "Коммуналка", icon: "drop.fill"),
                .init(name: "Интернет", icon: "wifi")
            ]
        ),
        CategorySeed(
            name: "Развлечения",
            icon: "film.fill",
            colorHex: "#8E44AD",
            type: .expense,
            subcategories: [
                .init(name: "Кино", icon: "film.fill"),
                .init(name: "Подписки", icon: "rectangle.stack.fill"),
                .init(name: "Игры", icon: "gamecontroller.fill")
            ]
        ),
        CategorySeed(
            name: "Здоровье",
            icon: "heart.fill",
            colorHex: "#E74C3C",
            type: .expense,
            subcategories: [
                .init(name: "Аптека", icon: "cross.case.fill"),
                .init(name: "Врач", icon: "stethoscope"),
                .init(name: "Спорт", icon: "figure.run")
            ]
        )
    ]

    /// Builds a full category tree (parents with children attached).
    static func defaultCategories() -> [Category] {
        defaultTree.map { seed in
            let parent = Category(
                name: seed.name,
                icon: seed.icon,
                colorHex: seed.colorHex,
                type: seed.type
            )
            for sub in seed.subcategories {
                let child = Category(
                    name: sub.name,
                    icon: sub.icon,
                    colorHex: seed.colorHex,
                    type: seed.type,
                    parent: parent
                )
                parent.children.append(child)
            }
            return parent
        }
    }

    /// Subcategory definitions keyed by parent name (for upgrade of existing DBs).
    static func subcategorySeeds(forParentName name: String) -> [SubcategorySeed] {
        defaultTree.first(where: { $0.name == name })?.subcategories ?? []
    }

    struct ItemDictionarySeed {
        let itemName: String
        let categoryName: String
        let aliases: [String]
    }

    /// Cold-start mappings for voice / dictionary matching (subcategory or root name).
    static let defaultDictionary: [ItemDictionarySeed] = [
        .init(itemName: "кофе", categoryName: "Кофейня", aliases: ["coffee", "капучино", "латте"]),
        .init(itemName: "такси", categoryName: "Такси", aliases: ["uber", "bolt", "indrive", "яндекс"]),
        .init(itemName: "бензин", categoryName: "Бензин", aliases: ["заправка", "аи-92", "аи-95"]),
        .init(itemName: "продукты", categoryName: "Супермаркет", aliases: ["молоко", "хлеб", "яйца", "мясо"]),
        .init(itemName: "супермаркет", categoryName: "Супермаркет", aliases: ["magnum", "small", "магазин"]),
        .init(itemName: "доставка", categoryName: "Доставка", aliases: ["glovo", "wolt", "яндекс еда"]),
        .init(itemName: "ресторан", categoryName: "Ресторан", aliases: ["обед", "ужин"]),
        .init(itemName: "фастфуд", categoryName: "Фастфуд", aliases: ["kfc", "burger", "mcdonald", "додо"]),
        .init(itemName: "аптека", categoryName: "Аптека", aliases: ["лекарства", "таблетки"]),
        .init(itemName: "врач", categoryName: "Врач", aliases: ["стоматолог", "клиника", "анализы"]),
        .init(itemName: "спорт", categoryName: "Спорт", aliases: ["fitness", "фитнес", "абонемент"]),
        .init(itemName: "кино", categoryName: "Кино", aliases: ["кинопарк", "chaplin", "фильм"]),
        .init(itemName: "подписки", categoryName: "Подписки", aliases: ["netflix", "spotify", "youtube", "icloud"]),
        .init(itemName: "игры", categoryName: "Игры", aliases: ["steam", "playstation"]),
        .init(itemName: "аренда", categoryName: "Аренда", aliases: ["квартира", "жильё"]),
        .init(itemName: "коммуналка", categoryName: "Коммуналка", aliases: ["кск", "алсеко", "электричество"]),
        .init(itemName: "интернет", categoryName: "Интернет", aliases: ["beeline", "tele2", "kcell", "wifi"]),
        .init(itemName: "парковка", categoryName: "Парковка", aliases: []),
        .init(itemName: "билет", categoryName: "Билет", aliases: ["метро", "автобус", "onay"]),
        .init(itemName: "зарплата", categoryName: "Основная", aliases: ["salary", "аванс"]),
        .init(itemName: "премия", categoryName: "Премия", aliases: ["бонус"]),
        .init(itemName: "фриланс", categoryName: "Фриланс", aliases: ["freelance", "подработка"]),
        .init(itemName: "рынок", categoryName: "Рынок", aliases: ["базар", "овощи"]),
        .init(itemName: "транспорт", categoryName: "Билет", aliases: ["проезд"]),
        .init(itemName: "кафе", categoryName: "Кофейня", aliases: ["чай", "напиток"])
    ]

    static func resolveCategory(named name: String, in categories: [Category]) -> Category? {
        categories.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
    }
}
