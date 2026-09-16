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
                .init(name: "Премия", icon: "gift.fill"),
                .init(name: "Аванс", icon: "calendar")
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
            name: "Прочее",
            icon: "arrow.down.circle.fill",
            colorHex: "#4CAF78",
            type: .income,
            subcategories: [
                .init(name: "Кешбэк", icon: "creditcard.fill"),
                .init(name: "Возврат", icon: "arrow.uturn.backward.circle.fill"),
                .init(name: "Подарок", icon: "gift.fill")
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
                .init(name: "Доставка", icon: "shippingbox.fill"),
                .init(name: "Напитки", icon: "cup.and.saucer.fill"),
                .init(name: "Энергетики", icon: "bolt.fill")
            ]
        ),
        CategorySeed(
            name: "Кафе",
            icon: "fork.knife",
            colorHex: "#B85C38",
            type: .expense,
            subcategories: [
                .init(name: "Ресторан", icon: "fork.knife"),
                .init(name: "Кофейня", icon: "cup.and.saucer.fill"),
                .init(name: "Фастфуд", icon: "takeoutbag.and.cup.and.straw.fill"),
                .init(name: "Столовая", icon: "tray.fill")
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
                .init(name: "Парковка", icon: "parkingsign.circle.fill"),
                .init(name: "Каршеринг", icon: "car.side.fill"),
                .init(name: "Мойка", icon: "drop.fill"),
                .init(name: "Штрафы", icon: "exclamationmark.triangle.fill")
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
                .init(name: "Интернет", icon: "wifi"),
                .init(name: "Мобильная", icon: "iphone"),
                .init(name: "Ремонт", icon: "wrench.and.screwdriver.fill")
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
                .init(name: "Игры", icon: "gamecontroller.fill"),
                .init(name: "Концерты", icon: "music.mic")
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
        ),
        CategorySeed(
            name: "Привычки",
            icon: "smoke.fill",
            colorHex: "#6D4C41",
            type: .expense,
            subcategories: [
                .init(name: "Табак", icon: "smoke.fill"),
                .init(name: "Алкоголь", icon: "wineglass.fill")
            ]
        ),
        CategorySeed(
            name: "Покупки",
            icon: "bag.fill",
            colorHex: "#00897B",
            type: .expense,
            subcategories: [
                .init(name: "Одежда", icon: "tshirt.fill"),
                .init(name: "Техника", icon: "laptopcomputer"),
                .init(name: "Маркетплейс", icon: "shippingbox.fill"),
                .init(name: "Хозтовары", icon: "shower.fill")
            ]
        ),
        CategorySeed(
            name: "Красота",
            icon: "sparkles",
            colorHex: "#D81B60",
            type: .expense,
            subcategories: [
                .init(name: "Салон", icon: "sparkles"),
                .init(name: "Барбер", icon: "scissors"),
                .init(name: "Косметика", icon: "paintpalette.fill")
            ]
        ),
        CategorySeed(
            name: "Семья",
            icon: "figure.2.and.child.holdinghands",
            colorHex: "#F57C00",
            type: .expense,
            subcategories: [
                .init(name: "Дети", icon: "figure.and.child.holdinghands"),
                .init(name: "Подарки", icon: "gift.fill"),
                .init(name: "Животные", icon: "pawprint.fill")
            ]
        ),
        CategorySeed(
            name: "Образование",
            icon: "book.fill",
            colorHex: "#3949AB",
            type: .expense,
            subcategories: [
                .init(name: "Курсы", icon: "graduationcap.fill"),
                .init(name: "Книги", icon: "book.fill")
            ]
        ),
        CategorySeed(
            name: "Путешествия",
            icon: "airplane",
            colorHex: "#0288D1",
            type: .expense,
            subcategories: [
                .init(name: "Авиа", icon: "airplane"),
                .init(name: "Отель", icon: "bed.double.fill"),
                .init(name: "Тур", icon: "map.fill")
            ]
        ),
        CategorySeed(
            name: "Финансы",
            icon: "building.columns.fill",
            colorHex: "#546E7A",
            type: .expense,
            subcategories: [
                .init(name: "Комиссия", icon: "percent"),
                .init(name: "Кредит", icon: "creditcard.fill"),
                .init(name: "Налоги", icon: "doc.text.fill")
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
        let needle = normalizeCategoryName(name)
        return defaultTree.first(where: { normalizeCategoryName($0.name) == needle })?.subcategories ?? []
    }

    struct ItemDictionarySeed {
        let itemName: String
        let categoryName: String
        let aliases: [String]
    }

    /// Cold-start mappings for voice / dictionary matching (subcategory or root name).
    static let defaultDictionary: [ItemDictionarySeed] = [
        // Продукты
        .init(itemName: "продукты", categoryName: "Супермаркет", aliases: ["молоко", "хлеб", "яйца", "мясо", "еда"]),
        .init(itemName: "супермаркет", categoryName: "Супермаркет", aliases: [
            "magnum", "магнум", "small", "смолл", "ramstore", "рамстор", "galmart", "галмарт",
            "monopole", "airba", "магазин", "пятерочка", "ашан"
        ]),
        .init(itemName: "рынок", categoryName: "Рынок", aliases: ["базар", "овощи", "фрукты", "зелень"]),
        .init(itemName: "доставка", categoryName: "Доставка", aliases: [
            "glovo", "глово", "wolt", "вольт", "яндекс еда", "яндекс лавка", "лавка"
        ]),
        .init(itemName: "вода", categoryName: "Напитки", aliases: [
            "cola", "кола", "пепси", "pepsi", "сок", "лимонад", "газировка", "боржоми", "tasty"
        ]),

        // Энергетики — «горилла 620», «энергос 600»
        .init(itemName: "горилла", categoryName: "Энергетики", aliases: ["gorilla", "gorilla energy"]),
        .init(itemName: "энергос", categoryName: "Энергетики", aliases: [
            "энергетик", "энергетики", "энерджи", "energy", "энергетик напиток"
        ]),
        .init(itemName: "ред булл", categoryName: "Энергетики", aliases: ["red bull", "redbull", "редбулл"]),
        .init(itemName: "монстр", categoryName: "Энергетики", aliases: ["monster", "monster energy"]),
        .init(itemName: "берн", categoryName: "Энергетики", aliases: ["burn"]),
        .init(itemName: "адреналин", categoryName: "Энергетики", aliases: ["adrenaline", "adrenaline rush", "адреналин раш"]),
        .init(itemName: "флеш", categoryName: "Энергетики", aliases: ["flash up", "flashup"]),

        // Кафе
        .init(itemName: "кофе", categoryName: "Кофейня", aliases: [
            "coffee", "капучино", "латте", "эспрессо", "американо", "раф", "флэт уайт", "чай"
        ]),
        .init(itemName: "кофейня", categoryName: "Кофейня", aliases: [
            "starbucks", "старбакс", "coffeebooma", "coffee boom"
        ]),
        .init(itemName: "кафе", categoryName: "Ресторан", aliases: ["ресторан", "обед", "ужин", "завтрак"]),
        .init(itemName: "столовая", categoryName: "Столовая", aliases: ["бизнес ланч", "ланч"]),
        .init(itemName: "фастфуд", categoryName: "Фастфуд", aliases: [
            "kfc", "кфс", "burger", "бургер", "mcdonald", "макдак", "макдональдс", "додо", "dodo",
            "бургер кинг", "burger king", "hardees", "хардис", "pizza", "пицца", "суши", "роллы",
            "донер", "шаурма", "шаверма"
        ]),

        // Транспорт
        .init(itemName: "такси", categoryName: "Такси", aliases: [
            "uber", "убер", "bolt", "болт", "indrive", "индрайв", "in drive", "яндекс", "yandex",
            "таси", "такса", "taksi", "таксист"
        ]),
        .init(itemName: "бензин", categoryName: "Бензин", aliases: [
            "заправка", "аи-92", "аи-95", "аи-98", "дизель", "солярка", "helio", "гелиос",
            "gazprom", "газпром", "sinooil", "синоил", "qazaqoil", "казахойл", "petrol"
        ]),
        .init(itemName: "билет", categoryName: "Билет", aliases: [
            "метро", "автобус", "onay", "онай", "проезд", "транспорт", "трамвай"
        ]),
        .init(itemName: "парковка", categoryName: "Парковка", aliases: ["паркинг", "стоянка"]),
        .init(itemName: "каршеринг", categoryName: "Каршеринг", aliases: ["yandex drive", "яндекс драйв", "carsharing"]),
        .init(itemName: "мойка", categoryName: "Мойка", aliases: ["автомойка", "помыть машину"]),
        .init(itemName: "штраф", categoryName: "Штрафы", aliases: ["штрафы", "камера", "пдд", "гибдд"]),

        // Жильё / связь
        .init(itemName: "аренда", categoryName: "Аренда", aliases: ["квартира", "жильё", "квартиру", "хата"]),
        .init(itemName: "коммуналка", categoryName: "Коммуналка", aliases: [
            "кск", "алсеко", "электричество", "свет", "газ", "отопление", "вода квитанция", "кпу"
        ]),
        .init(itemName: "интернет", categoryName: "Интернет", aliases: [
            "wifi", "вайфай", "казахтелеком", "telecom"
        ]),
        .init(itemName: "связь", categoryName: "Мобильная", aliases: [
            "beeline", "билайн", "tele2", "теле2", "kcell", "келл", "activ", "актив",
            "баланс", "симка", "мобильная", "сотовая"
        ]),
        .init(itemName: "ремонт", categoryName: "Ремонт", aliases: ["мастер", "сантехник", "электрик"]),

        // Развлечения
        .init(itemName: "кино", categoryName: "Кино", aliases: ["кинопарк", "chaplin", "чаплин", "фильм", "imax"]),
        .init(itemName: "подписки", categoryName: "Подписки", aliases: [
            "netflix", "нетфликс", "spotify", "спотифай", "youtube", "ютуб", "icloud", "айклауд",
            "apple music", "apple.com", "yandex plus", "яндекс плюс", "ivi", "иви"
        ]),
        .init(itemName: "игры", categoryName: "Игры", aliases: [
            "steam", "стим", "playstation", "плейстейшен", "xbox", "donat", "донат", "game"
        ]),
        .init(itemName: "концерт", categoryName: "Концерты", aliases: ["концерты", "билет на концерт", "клуб", "вечеринка"]),

        // Здоровье
        .init(itemName: "аптека", categoryName: "Аптека", aliases: [
            "лекарства", "таблетки", "europharma", "еврофарма", "биосфер", "biosphere"
        ]),
        .init(itemName: "врач", categoryName: "Врач", aliases: [
            "стоматолог", "клиника", "анализы", "больница", "поликлиника", "лор"
        ]),
        .init(itemName: "спорт", categoryName: "Спорт", aliases: [
            "fitness", "фитнес", "абонемент", "world class", "зал", "тренажёрка", "бассейн"
        ]),

        // Привычки
        .init(itemName: "стики", categoryName: "Табак", aliases: [
            "iqos", "айкос", "heets", "хитс", "glo", "гло", "сигареты", "табак", "вейп", "vape",
            "электронка", "пар", "марлборо", "winston", "парламент",
            "одноразка", "одноразовка", "одноразовые"
        ]),
        .init(itemName: "пиво", categoryName: "Алкоголь", aliases: [
            "алкоголь", "вино", "водка", "виски", "коньяк", "бар", "кальян"
        ]),

        // Покупки
        .init(itemName: "одежда", categoryName: "Одежда", aliases: [
            "обувь", "кроссовки", "футболка", "штаны", "h&m", "zara", "massimo"
        ]),
        .init(itemName: "техника", categoryName: "Техника", aliases: [
            "телефон", "айфон", "iphone", "ноут", "наушники", "airpods", "зарядка"
        ]),
        .init(itemName: "вайлдберриз", categoryName: "Маркетплейс", aliases: [
            "wildberries", "wb", "озон", "ozon", "kaspi магазин", "каспи магазин", "маркетплейс"
        ]),
        .init(itemName: "хозяйство", categoryName: "Хозтовары", aliases: [
            "бытовая", "порошок", "хозяйственный", "fix price", "фикспрайс"
        ]),

        // Красота
        .init(itemName: "салон", categoryName: "Салон", aliases: ["маникюр", "педикюр", "брови", "ресницы", "косметолог"]),
        .init(itemName: "барбер", categoryName: "Барбер", aliases: ["стрижка", "барбершоп", "парикмахер"]),
        .init(itemName: "косметика", categoryName: "Косметика", aliases: ["крем", "шампунь", "парфюм", "духи"]),

        // Семья
        .init(itemName: "дети", categoryName: "Дети", aliases: ["садик", "няня", "подгузники", "игрушки", "школа"]),
        .init(itemName: "подарок", categoryName: "Подарки", aliases: ["подарки", "цветы", "букет", "день рождения"]),
        .init(itemName: "собака", categoryName: "Животные", aliases: ["кот", "кошка", "вет", "ветклиника", "корм", "животные"]),

        // Образование
        .init(itemName: "курсы", categoryName: "Курсы", aliases: ["учеба", "учёба", "репетитор", "английский"]),
        .init(itemName: "книги", categoryName: "Книги", aliases: ["книга", "литрес", "меломан"]),

        // Путешествия
        .init(itemName: "самолёт", categoryName: "Авиа", aliases: ["авиа", "аэрофлот", "air astana", "flyarystan", "билет самолёт"]),
        .init(itemName: "отель", categoryName: "Отель", aliases: ["гостиница", "booking", "airbnb"]),
        .init(itemName: "тур", categoryName: "Тур", aliases: ["путешествие", "отпуск", "поездка"]),

        // Финансы
        .init(itemName: "комиссия", categoryName: "Комиссия", aliases: ["комиссии", "снятие", "банкомат", "atm"]),
        .init(itemName: "кредит", categoryName: "Кредит", aliases: ["рассрочка", "каспи кредит", "платёж по кредиту"]),
        .init(itemName: "налог", categoryName: "Налоги", aliases: ["налоги", "штраф налоговой", "гп", "егов"]),

        // Доходы
        .init(itemName: "зарплата", categoryName: "Основная", aliases: ["salary", "зп"]),
        .init(itemName: "аванс", categoryName: "Аванс", aliases: []),
        .init(itemName: "премия", categoryName: "Премия", aliases: ["бонус"]),
        .init(itemName: "фриланс", categoryName: "Фриланс", aliases: ["freelance", "подработка"]),
        .init(itemName: "кешбэк", categoryName: "Кешбэк", aliases: ["cashback", "кэшбек"]),
        .init(itemName: "возврат", categoryName: "Возврат", aliases: ["рефанд", "refund"])
    ]

    static func resolveCategory(named name: String, in categories: [Category]) -> Category? {
        let keys = equivalentCategoryNames(name)
        guard !keys.isEmpty else { return nil }
        return categories.first { keys.contains(normalizeCategoryName($0.name)) }
    }

    static func equivalentCategoryNames(_ name: String) -> Set<String> {
        let needle = normalizeCategoryName(name)
        guard !needle.isEmpty else { return [] }
        var keys: Set<String> = [needle]
        if let aliases = categoryNameAliases[needle] {
            keys.formUnion(aliases)
        }
        for (canonical, aliases) in categoryNameAliases where aliases.contains(needle) {
            keys.insert(canonical)
            keys.formUnion(aliases)
        }
        return keys
    }

    /// User may have created a close custom name before the seed existed.
    private static let categoryNameAliases: [String: [String]] = [
        "энергетики": ["энергетик", "энергос"],
        "табак": ["сигареты", "стики"],
        "мобильная": ["связь"],
        "маркетплейс": ["вайлдберриз", "озон"]
    ]

    static func normalizeCategoryName(_ name: String) -> String {
        name
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
