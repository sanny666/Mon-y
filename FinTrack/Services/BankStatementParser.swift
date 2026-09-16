import Compression
import Foundation
import PDFKit

struct BankStatementRow: Sendable, Equatable {
    var date: Date
    var amount: Double
    var type: TransactionType
    var note: String
    var categoryHint: String
    var tags: [String]
}

struct BankStatementParseResult: Sendable {
    var sourceName: String
    var rows: [BankStatementRow]
}

enum BankImportError: LocalizedError {
    case emptyFile
    case unreadable
    case noTransactions
    case unsupportedExcel
    case invalidFile
    case unscannablePDF

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "Файл пустой."
        case .unreadable:
            return "Не удалось прочитать файл. Сохраните выписку как CSV, XLSX или PDF с текстом."
        case .noTransactions:
            return "В файле нет операций. Проверьте, что это выписка, а не чек."
        case .unsupportedExcel:
            return "Бинарный Excel (.xls) не поддерживается. Откройте файл в Numbers/Excel и сохраните как CSV или XLSX. HTML-таблицы с расширением .xls уже читаются."
        case .invalidFile:
            return "Не получилось разобрать выписку."
        case .unscannablePDF:
            return "В PDF нет распознаваемого текста. Сохраните выписку как CSV/XLSX или экспортируйте текстовый PDF."
        }
    }
}

enum BankStatementParser {
    static func parse(data: Data, filename: String) throws -> BankStatementParseResult {
        guard !data.isEmpty else { throw BankImportError.emptyFile }

        let table: [[String]]
        if isPDF(data) {
            table = try PDFTable.read(data)
        } else if isOLECompound(data) {
            throw BankImportError.unsupportedExcel
        } else if isZIP(data) {
            table = try XLSXTable.read(data)
        } else if looksLikeHTML(data) {
            table = try HTMLTable.read(data)
        } else {
            table = try CSVTable.read(data)
        }

        let rows = try rows(from: table, filename: filename)
        guard !rows.isEmpty else { throw BankImportError.noTransactions }
        return BankStatementParseResult(sourceName: detectSource(filename: filename, table: table), rows: rows)
    }

    static func matchCategory(
        note: String,
        hint: String,
        type: TransactionType,
        categories: [Category]
    ) -> Category? {
        let needed: CategoryType = type == .income ? .income : .expense
        let pool = categories.filter { !$0.isDeleted && $0.type == needed }
        guard type != .transfer, !pool.isEmpty else { return nil }

        let haystack = normalizeMatchText(note + " " + hint)
        let terms = TransactionParser.voiceSearchTerms(itemName: note, transcript: hint.isEmpty ? note : note + " " + hint)
        if let hit = CategoryVoiceMatcher.match(terms: terms, type: type, categories: pool) {
            return hit.category
        }

        if let hinted = matchByName(hint, in: pool) {
            return hinted
        }
        if let named = matchByName(note, in: pool) {
            return named
        }

        // Prefer delivery when food markers appear with Yandex/Go.
        if needed == .expense,
           haystack.contains("яндекс") || haystack.contains("yandex"),
           foodDeliveryMarkers.contains(where: { haystack.contains($0) }),
           let delivery = pool.first(where: { $0.name.caseInsensitiveCompare("Доставка") == .orderedSame }) {
            return delivery
        }

        var best: (category: Category, score: Int)?
        for rule in keywordRules where rule.type == needed {
            guard containsToken(haystack, rule.keyword) else { continue }
            guard let category = pool.first(where: { $0.name.caseInsensitiveCompare(rule.categoryName) == .orderedSame })
                    ?? pool.first(where: { $0.displayName.localizedCaseInsensitiveContains(rule.categoryName) })
            else { continue }
            let score = rule.keyword.count * 2 + rule.bonus + (category.isSubcategory ? 8 : 0)
            if best == nil || score > best!.score {
                best = (category, score)
            }
        }
        return best?.category
    }

    private static let foodDeliveryMarkers = [
        "еда", "eda", "eats", "food", "доставк", "lavka", "лавк"
    ]

    private static func normalizeMatchText(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "[*._/\\\\|+]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func fingerprint(date: Date, amount: Double, note: String) -> String {
        let day = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        let normalized = note
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(Int(day))|\(String(format: "%.2f", amount))|\(normalized.prefix(48))"
    }

    // MARK: - Table → rows

    private static func rows(from table: [[String]], filename: String) throws -> [BankStatementRow] {
        guard let headerIndex = findHeaderRow(in: table) else {
            return try inferWithoutHeader(table)
        }
        let headers = table[headerIndex].map(normalizeHeader)
        let map = ColumnMap.detect(headers: headers)
        guard map.isUsable else {
            return try inferWithoutHeader(Array(table.dropFirst(headerIndex)))
        }

        let body = table.dropFirst(headerIndex + 1)
        let signedValues = body.compactMap { raw -> Double? in
            map.amount.flatMap { parseAmount(raw[safe: $0] ?? "") }
        }
        let usesSignedConvention = signedValues.contains { $0 < 0 }

        var parsed: [BankStatementRow] = []
        parsed.reserveCapacity(max(table.count - headerIndex - 1, 0))

        for raw in body {
            if let row = parseRow(raw, map: map, usesSignedConvention: usesSignedConvention) {
                parsed.append(row)
            }
        }
        if parsed.isEmpty, filename.lowercased().contains("kaspi") || headers.contains(where: { $0.contains("kaspi") }) {
            return try inferWithoutHeader(Array(table.dropFirst(headerIndex)))
        }
        return parsed
    }

    private static func parseRow(_ raw: [String], map: ColumnMap, usesSignedConvention: Bool) -> BankStatementRow? {
        let dateText = map.date.flatMap { raw[safe: $0] } ?? ""
        let timeText = map.time.flatMap { raw[safe: $0] } ?? ""
        guard let date = parseDate(dateText, time: timeText) else { return nil }

        let note = [
            map.description.flatMap { raw[safe: $0] },
            map.note.flatMap { raw[safe: $0] }
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")

        if isSummary(note) { return nil }

        let typeText = map.type.flatMap { raw[safe: $0] } ?? ""
        let hint = map.category.flatMap { raw[safe: $0] } ?? ""
        let tags = (map.tags.flatMap { raw[safe: $0] } ?? "")
            .split(whereSeparator: { $0 == ";" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let amount: Double
        let type: TransactionType

        if let signed = map.amount.flatMap({ parseAmount(raw[safe: $0] ?? "") }), signed != 0 {
            amount = abs(signed)
            type = resolveType(
                signedAmount: signed,
                typeText: typeText,
                note: note,
                usesSignedConvention: usesSignedConvention
            )
        } else {
            let debit = map.debit.flatMap { parseAmount(raw[safe: $0] ?? "") } ?? 0
            let credit = map.credit.flatMap { parseAmount(raw[safe: $0] ?? "") } ?? 0
            if debit != 0 && credit == 0 {
                amount = abs(debit)
                type = .expense
            } else if credit != 0 && debit == 0 {
                amount = abs(credit)
                type = .income
            } else {
                return nil
            }
        }

        guard amount > 0 else { return nil }
        return BankStatementRow(
            date: date,
            amount: amount,
            type: type,
            note: note,
            categoryHint: hint,
            tags: tags
        )
    }

    private static func inferWithoutHeader(_ table: [[String]]) throws -> [BankStatementRow] {
        let usesSignedConvention = table.contains { row in
            row.contains { (parseAmount($0) ?? 0) < 0 }
        }
        var parsed: [BankStatementRow] = []
        for raw in table {
            let cells = raw.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            guard cells.count >= 2 else { continue }

            var date: Date?
            var dateIndex: Int?
            for (index, cell) in cells.enumerated() where parseDate(cell, time: "") != nil {
                date = parseDate(cell, time: "")
                dateIndex = index
                break
            }
            guard let date, let dateIndex else { continue }

            var amount: Double?
            var amountIndex: Int?
            for (index, cell) in cells.enumerated() where index != dateIndex {
                if let value = parseAmount(cell), value != 0, !looksLikeDate(cell) {
                    amount = value
                    amountIndex = index
                    break
                }
            }
            guard let amount, let amountIndex, amount != 0 else { continue }

            let note = cells.enumerated()
                .filter { $0.offset != dateIndex && $0.offset != amountIndex }
                .map(\.element)
                .joined(separator: " · ")
            if isSummary(note) { continue }

            parsed.append(
                BankStatementRow(
                    date: date,
                    amount: abs(amount),
                    type: resolveType(
                        signedAmount: amount,
                        typeText: "",
                        note: note,
                        usesSignedConvention: usesSignedConvention
                    ),
                    note: note,
                    categoryHint: "",
                    tags: []
                )
            )
        }
        return parsed
    }

    private static func findHeaderRow(in table: [[String]]) -> Int? {
        let limit = min(table.count, 25)
        var best: (index: Int, score: Int)?
        for index in 0..<limit {
            let score = ColumnMap.detect(headers: table[index].map(normalizeHeader)).score
            if score >= 4, best == nil || score > best!.score {
                best = (index, score)
            }
        }
        return best?.index
    }

    private static func detectSource(filename: String, table: [[String]]) -> String {
        let blob = (filename + " " + table.prefix(8).flatMap { $0 }.joined(separator: " ")).lowercased()
        if blob.contains("kaspi") { return "Kaspi" }
        if blob.contains("halyk") || blob.contains("homebank") || blob.contains("народн") { return "Halyk" }
        if blob.contains("forte") { return "Forte" }
        if blob.contains("jusan") { return "Jusan" }
        if blob.contains("freedom") { return "Freedom" }
        if blob.contains("bcc") || blob.contains("центркредит") { return "BCC" }
        if blob.contains("monёy") || blob.contains("money-transactions") { return "monёy" }
        return "Банк"
    }

    private static func resolveType(
        signedAmount: Double,
        typeText: String,
        note: String,
        usesSignedConvention: Bool
    ) -> TransactionType {
        let text = (typeText + " " + note).lowercased()
        if text.contains("перевод") && (text.contains("между") || text.contains("свой") || text.contains("transfer")
            || text.contains("own") || text.contains("внутренн")) {
            return .transfer
        }
        if text.contains("p2p") || text.contains("peer to peer") {
            // P2P to other people stays expense/income by sign; own-account wording is transfer above.
            if text.contains("свой") || text.contains("между счёт") || text.contains("между счет") {
                return .transfer
            }
        }
        switch typeText.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Доход", "Income": return .income
        case "Расход", "Expense": return .expense
        case "Перевод", "Transfer": return .transfer
        default: break
        }
        if text.contains("пополнен") || text.contains("зачислен") || text.contains("входящ")
            || text.contains("зарплат") || text.contains("кэшбэк") || text.contains("cashback")
            || text.contains("возврат") || text.contains("refund") || text.contains("начислен") {
            return .income
        }
        if text.contains("покупк") || text.contains("оплат") || text.contains("списан")
            || text.contains("комисс") || text.contains("вывод") || text.contains("kaspi qr") {
            return .expense
        }
        if usesSignedConvention {
            return signedAmount < 0 ? .expense : .income
        }
        return .expense
    }

    private static func isSummary(_ text: String) -> Bool {
        statementSummary(text)
    }

    private static func normalizeHeader(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matchByName(_ text: String, in pool: [Category]) -> Category? {
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        if let exact = pool.first(where: { $0.displayName.caseInsensitiveCompare(needle) == .orderedSame }) {
            return exact
        }
        if let exact = pool.first(where: { $0.name.caseInsensitiveCompare(needle) == .orderedSame }) {
            return exact
        }
        return pool
            .filter { needle.localizedCaseInsensitiveContains($0.name) && $0.name.count >= 4 }
            .sorted { lhs, rhs in
                if lhs.isSubcategory != rhs.isSubcategory { return lhs.isSubcategory && !rhs.isSubcategory }
                return lhs.name.count > rhs.name.count
            }
            .first
    }

    private static func containsToken(_ haystack: String, _ keyword: String) -> Bool {
        guard !keyword.isEmpty else { return false }
        guard let range = haystack.range(of: keyword) else { return false }
        let beforeOK: Bool = {
            guard range.lowerBound > haystack.startIndex else { return true }
            let prev = haystack[haystack.index(before: range.lowerBound)]
            return !prev.isLetter && !prev.isNumber
        }()
        let afterOK: Bool = {
            guard range.upperBound < haystack.endIndex else { return true }
            let next = haystack[range.upperBound]
            return !next.isLetter && !next.isNumber
        }()
        return beforeOK && afterOK
    }
}

// MARK: - Amount / date

private func parseAmount(_ raw: String) -> Double? {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }
    var negative = false
    if s.hasPrefix("(") && s.hasSuffix(")") {
        negative = true
        s.removeFirst()
        s.removeLast()
    }
    if let first = s.first, "-−–".contains(first) {
        negative = true
        s.removeFirst()
    } else if s.hasPrefix("+") {
        s.removeFirst()
    }

    for token in ["₸", "₽", "$", "€", "KZT", "RUB", "USD", "EUR", "тг", "тенге"] {
        s = s.replacingOccurrences(of: token, with: "", options: .caseInsensitive)
    }
    s = s.replacingOccurrences(of: "\u{00A0}", with: "")
    s = s.replacingOccurrences(of: "\u{202F}", with: "")
    s = s.replacingOccurrences(of: " ", with: "")
    s = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }

    if s.contains(",") && s.contains(".") {
        if let comma = s.lastIndex(of: ","), let dot = s.lastIndex(of: "."), comma > dot {
            s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else {
            s = s.replacingOccurrences(of: ",", with: "")
        }
    } else if s.contains(",") {
        let parts = s.split(separator: ",", omittingEmptySubsequences: false)
        if parts.count == 2, parts[1].count <= 2 {
            s = s.replacingOccurrences(of: ",", with: ".")
        } else {
            s = s.replacingOccurrences(of: ",", with: "")
        }
    }

    guard let value = Double(s) else { return nil }
    return negative ? -abs(value) : value
}

private func parseDate(_ raw: String, time: String) -> Date? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if let serial = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
       serial > 20_000, serial < 80_000 {
        let unix = (serial - 25569) * 86_400
        return Date(timeIntervalSince1970: unix)
    }

    let combined: String
    let timeTrimmed = time.trimmingCharacters(in: .whitespacesAndNewlines)
    if !timeTrimmed.isEmpty, !trimmed.contains(":") {
        combined = trimmed + " " + timeTrimmed
    } else {
        combined = trimmed
    }

    for formatter in DateParse.formatters {
        if let date = formatter.date(from: combined) { return date }
        if combined != trimmed, let date = formatter.date(from: trimmed) { return date }
    }

    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: combined) { return date }
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: combined)
}

private func looksLikeDate(_ raw: String) -> Bool {
    parseDate(raw, time: "") != nil && parseAmount(raw) == nil
}

private enum DateParse {
    static let formatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "dd.MM.yyyy HH:mm",
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy",
            "d.M.yyyy HH:mm",
            "d.M.yyyy",
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy",
            "dd-MM-yyyy HH:mm",
            "dd-MM-yyyy",
            // Two-digit year (KZ bank exports)
            "dd.MM.yy HH:mm",
            "dd.MM.yy HH:mm:ss",
            "dd.MM.yy",
            "d.M.yy HH:mm",
            "d.M.yy",
            "dd/MM/yy HH:mm",
            "dd/MM/yy",
            "dd-MM-yy HH:mm",
            "dd-MM-yy",
            "yy-MM-dd HH:mm",
            "yy-MM-dd",
            // US-style when day > 12 is unambiguous via formatter left-to-right after EU formats
            "MM/dd/yyyy HH:mm",
            "MM/dd/yyyy",
            "M/d/yyyy HH:mm",
            "M/d/yyyy",
            "MM/dd/yy",
            "M/d/yy"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = format
            // Map 00–69 → 2000–2069, 70–99 → 1970–1999 for two-digit years.
            formatter.twoDigitStartDate = Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 2000, month: 1, day: 1))
            return formatter
        }
    }()
}

// MARK: - Columns

private struct ColumnMap {
    var date: Int?
    var time: Int?
    var amount: Int?
    var debit: Int?
    var credit: Int?
    var description: Int?
    var type: Int?
    var category: Int?
    var note: Int?
    var tags: Int?
    var score = 0

    var isUsable: Bool {
        date != nil && (amount != nil || debit != nil || credit != nil)
    }

    static func detect(headers: [String]) -> ColumnMap {
        var map = ColumnMap()
        for (index, header) in headers.enumerated() {
            guard !header.isEmpty else { continue }
            if map.date == nil, matches(header, ["дата", "date", "time date", "операции"]) && !header.contains("обработ") {
                if header.contains("дата") || header == "date" || header.contains("транзак") {
                    map.date = index
                    map.score += 3
                    continue
                }
            }
            if map.time == nil, header == "время" || header == "time" {
                map.time = index
                map.score += 1
                continue
            }
            if map.debit == nil, header.contains("дебет") || header == "debit" || header == "списание" {
                map.debit = index
                map.score += 3
                continue
            }
            if map.credit == nil, header.contains("кредит") || header == "credit" || header == "зачисление" {
                map.credit = index
                map.score += 3
                continue
            }
            if map.amount == nil, header.contains("сумм") || header == "amount" || header == "sum" {
                map.amount = index
                map.score += 3
                continue
            }
            if map.type == nil, header == "тип" || header == "type" || header.contains("вид операц") {
                map.type = index
                map.score += 1
                continue
            }
            if map.category == nil, header.contains("категор") || header == "category" {
                map.category = index
                map.score += 1
                continue
            }
            if map.tags == nil, header.contains("тег") || header == "tags" {
                map.tags = index
                map.score += 1
                continue
            }
            if map.note == nil, header.contains("замет") || header == "note" || header == "memo" {
                map.note = index
                map.score += 1
                continue
            }
            if map.description == nil, matches(header, [
                "описание", "назначен", "операц", "детал", "merchant", "details",
                "narrative", "контрагент", "получател", "комментар"
            ]) {
                map.description = index
                map.score += 2
            }
        }
        if map.date == nil {
            for (index, header) in headers.enumerated() where header.contains("дата") || header == "date" {
                map.date = index
                map.score += 2
                break
            }
        }
        return map
    }

    private static func matches(_ header: String, _ needles: [String]) -> Bool {
        needles.contains { header.contains($0) }
    }
}

// MARK: - Category keywords

private struct KeywordRule {
    let keyword: String
    let categoryName: String
    let type: CategoryType
    let bonus: Int

    init(keyword: String, categoryName: String, type: CategoryType, bonus: Int = 0) {
        self.keyword = keyword
        self.categoryName = categoryName
        self.type = type
        self.bonus = bonus
    }
}

private let keywordRules: [KeywordRule] = [
    .init(keyword: "magnum", categoryName: "Супермаркет", type: .expense),
    .init(keyword: "small", categoryName: "Супермаркет", type: .expense),
    .init(keyword: "ramstore", categoryName: "Супермаркет", type: .expense),
    .init(keyword: "galmart", categoryName: "Супермаркет", type: .expense),
    .init(keyword: "monopole", categoryName: "Супермаркет", type: .expense),
    .init(keyword: "airba", categoryName: "Супермаркет", type: .expense),
    .init(keyword: "супермаркет", categoryName: "Супермаркет", type: .expense),
    .init(keyword: "продукты", categoryName: "Продукты", type: .expense),
    .init(keyword: "glovo", categoryName: "Доставка", type: .expense, bonus: 12),
    .init(keyword: "wolt", categoryName: "Доставка", type: .expense, bonus: 12),
    .init(keyword: "яндекс еда", categoryName: "Доставка", type: .expense, bonus: 40),
    .init(keyword: "yandex eats", categoryName: "Доставка", type: .expense, bonus: 40),
    .init(keyword: "yandex eda", categoryName: "Доставка", type: .expense, bonus: 40),
    .init(keyword: "яндекс лавка", categoryName: "Доставка", type: .expense, bonus: 40),
    .init(keyword: "yandex lavka", categoryName: "Доставка", type: .expense, bonus: 40),
    .init(keyword: "indrive", categoryName: "Такси", type: .expense, bonus: 10),
    .init(keyword: "in drive", categoryName: "Такси", type: .expense, bonus: 10),
    .init(keyword: "яндекс го", categoryName: "Такси", type: .expense, bonus: 20),
    .init(keyword: "yandex go", categoryName: "Такси", type: .expense, bonus: 20),
    .init(keyword: "яндекс такси", categoryName: "Такси", type: .expense, bonus: 30),
    .init(keyword: "yandex taxi", categoryName: "Такси", type: .expense, bonus: 30),
    .init(keyword: "яндекс", categoryName: "Такси", type: .expense),
    .init(keyword: "yandex", categoryName: "Такси", type: .expense),
    .init(keyword: "uber", categoryName: "Такси", type: .expense),
    .init(keyword: "такси", categoryName: "Такси", type: .expense),
    .init(keyword: "bolt", categoryName: "Такси", type: .expense),
    .init(keyword: "helio", categoryName: "Бензин", type: .expense),
    .init(keyword: "gazprom", categoryName: "Бензин", type: .expense),
    .init(keyword: "sinooil", categoryName: "Бензин", type: .expense),
    .init(keyword: "qazaqoil", categoryName: "Бензин", type: .expense),
    .init(keyword: "бензин", categoryName: "Бензин", type: .expense),
    .init(keyword: "аи-95", categoryName: "Бензин", type: .expense),
    .init(keyword: "аи-92", categoryName: "Бензин", type: .expense),
    .init(keyword: "парков", categoryName: "Парковка", type: .expense),
    .init(keyword: "onay", categoryName: "Билет", type: .expense),
    .init(keyword: "starbucks", categoryName: "Кофейня", type: .expense),
    .init(keyword: "coffeebooma", categoryName: "Кофейня", type: .expense),
    .init(keyword: "кофе", categoryName: "Кофейня", type: .expense),
    .init(keyword: "coffee", categoryName: "Кофейня", type: .expense),
    .init(keyword: "kfc", categoryName: "Фастфуд", type: .expense),
    .init(keyword: "burger", categoryName: "Фастфуд", type: .expense),
    .init(keyword: "mcdonald", categoryName: "Фастфуд", type: .expense),
    .init(keyword: "dodo", categoryName: "Фастфуд", type: .expense),
    .init(keyword: "додо", categoryName: "Фастфуд", type: .expense),
    .init(keyword: "ресторан", categoryName: "Ресторан", type: .expense),
    .init(keyword: "алсеко", categoryName: "Коммуналка", type: .expense),
    .init(keyword: "кск", categoryName: "Коммуналка", type: .expense),
    .init(keyword: "коммунал", categoryName: "Коммуналка", type: .expense),
    .init(keyword: "beeline", categoryName: "Интернет", type: .expense),
    .init(keyword: "tele2", categoryName: "Интернет", type: .expense),
    .init(keyword: "kcell", categoryName: "Интернет", type: .expense),
    .init(keyword: "activ", categoryName: "Интернет", type: .expense),
    .init(keyword: "казахтелеком", categoryName: "Интернет", type: .expense),
    .init(keyword: "аренда", categoryName: "Аренда", type: .expense),
    .init(keyword: "netflix", categoryName: "Подписки", type: .expense),
    .init(keyword: "spotify", categoryName: "Подписки", type: .expense),
    .init(keyword: "youtube", categoryName: "Подписки", type: .expense),
    .init(keyword: "apple.com", categoryName: "Подписки", type: .expense),
    .init(keyword: "icloud", categoryName: "Подписки", type: .expense),
    .init(keyword: "steam", categoryName: "Игры", type: .expense),
    .init(keyword: "playstation", categoryName: "Игры", type: .expense),
    .init(keyword: "кинопарк", categoryName: "Кино", type: .expense),
    .init(keyword: "chaplin", categoryName: "Кино", type: .expense),
    .init(keyword: "аптека", categoryName: "Аптека", type: .expense),
    .init(keyword: "europharma", categoryName: "Аптека", type: .expense),
    .init(keyword: "биосфер", categoryName: "Аптека", type: .expense),
    .init(keyword: "fitness", categoryName: "Спорт", type: .expense),
    .init(keyword: "world class", categoryName: "Спорт", type: .expense),
    .init(keyword: "клиника", categoryName: "Врач", type: .expense),
    .init(keyword: "стоматолог", categoryName: "Врач", type: .expense),
    .init(keyword: "wildberries", categoryName: "Маркетплейс", type: .expense),
    .init(keyword: "wilberries", categoryName: "Маркетплейс", type: .expense),
    .init(keyword: "вайлдберриз", categoryName: "Маркетплейс", type: .expense),
    .init(keyword: "ozon", categoryName: "Маркетплейс", type: .expense),
    .init(keyword: "озон", categoryName: "Маркетплейс", type: .expense),
    .init(keyword: "kaspi магазин", categoryName: "Маркетплейс", type: .expense, bonus: 10),
    .init(keyword: "горилла", categoryName: "Энергетики", type: .expense, bonus: 30),
    .init(keyword: "gorilla", categoryName: "Энергетики", type: .expense, bonus: 30),
    .init(keyword: "энергос", categoryName: "Энергетики", type: .expense, bonus: 20),
    .init(keyword: "энергетик", categoryName: "Энергетики", type: .expense, bonus: 20),
    .init(keyword: "red bull", categoryName: "Энергетики", type: .expense, bonus: 25),
    .init(keyword: "redbull", categoryName: "Энергетики", type: .expense, bonus: 25),
    .init(keyword: "ред булл", categoryName: "Энергетики", type: .expense, bonus: 25),
    .init(keyword: "monster energy", categoryName: "Энергетики", type: .expense, bonus: 20),
    .init(keyword: "стики", categoryName: "Табак", type: .expense, bonus: 20),
    .init(keyword: "iqos", categoryName: "Табак", type: .expense, bonus: 20),
    .init(keyword: "heets", categoryName: "Табак", type: .expense, bonus: 15),
    .init(keyword: "сигареты", categoryName: "Табак", type: .expense),
    .init(keyword: "зарплат", categoryName: "Основная", type: .income),
    .init(keyword: "salary", categoryName: "Основная", type: .income),
    .init(keyword: "премия", categoryName: "Премия", type: .income),
    .init(keyword: "фриланс", categoryName: "Фриланс", type: .income),
    .init(keyword: "freelance", categoryName: "Фриланс", type: .income)
]

// MARK: - CSV

private enum CSVTable {
    static func read(_ data: Data) throws -> [[String]] {
        let text = try decodeText(data)
        let lines = splitLines(text)
        guard !lines.isEmpty else { throw BankImportError.emptyFile }
        let delimiter = detectDelimiter(in: lines)
        return lines.map { splitCSVLine($0, delimiter: delimiter) }
    }

    private static func decodeText(_ data: Data) throws -> String {
        if data.starts(with: [0xEF, 0xBB, 0xBF]), let text = String(data: data.dropFirst(3), encoding: .utf8) {
            return text
        }
        if data.starts(with: [0xFF, 0xFE]), let text = String(data: data, encoding: .utf16LittleEndian) {
            return text
        }
        if data.starts(with: [0xFE, 0xFF]), let text = String(data: data, encoding: .utf16BigEndian) {
            return text
        }
        if let text = String(data: data, encoding: .utf8), !text.contains("\u{FFFD}") {
            return text
        }
        if let text = String(data: data, encoding: .windowsCP1251) {
            return text
        }
        throw BankImportError.unreadable
    }

    private static func splitLines(_ text: String) -> [String] {
        var lines: [String] = []
        var current = ""
        var inQuotes = false
        for ch in text {
            if ch == "\"" {
                inQuotes.toggle()
                current.append(ch)
            } else if !inQuotes && (ch == "\n" || ch == "\r") {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { lines.append(current) }
                current = ""
            } else if ch != "\r" {
                current.append(ch)
            }
        }
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { lines.append(current) }
        return lines
    }

    private static func detectDelimiter(in lines: [String]) -> Character {
        let sample = Array(lines.prefix(12))
        let candidates: [Character] = [";", ",", "\t", "|"]
        var best: (Character, Int) = (",", 0)
        for delimiter in candidates {
            let counts = sample.map { splitCSVLine($0, delimiter: delimiter).count }
            guard let maxCount = counts.max(), maxCount >= 2 else { continue }
            let consistent = counts.filter { $0 == maxCount }.count
            let score = consistent * 10 + maxCount
            if score > best.1 { best = (delimiter, score) }
        }
        return best.0
    }

    private static func splitCSVLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var index = line.startIndex
        while index < line.endIndex {
            let ch = line[index]
            if ch == "\"" {
                let next = line.index(after: index)
                if inQuotes, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    index = next
                } else {
                    inQuotes.toggle()
                }
            } else if ch == delimiter && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(ch)
            }
            index = line.index(after: index)
        }
        fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }
}

// MARK: - HTML (banks often export .xls as HTML table)

private enum HTMLTable {
    static func read(_ data: Data) throws -> [[String]] {
        let text: String
        if let utf8 = String(data: data, encoding: .utf8), !utf8.contains("\u{FFFD}") {
            text = utf8
        } else if let cp1251 = String(data: data, encoding: .windowsCP1251) {
            text = cp1251
        } else {
            throw BankImportError.unreadable
        }

        var rows: [[String]] = []
        var currentRow: [String] = []
        let pattern = #"(?is)<tr\b[^>]*>(.*?)</tr>"#
        guard let rowRegex = try? NSRegularExpression(pattern: pattern) else {
            throw BankImportError.invalidFile
        }
        let cellRegex = try? NSRegularExpression(pattern: #"(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>"#)
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        for match in rowRegex.matches(in: text, range: full) {
            guard match.numberOfRanges > 1 else { continue }
            let inner = ns.substring(with: match.range(at: 1))
            currentRow = []
            let innerNS = inner as NSString
            let innerFull = NSRange(location: 0, length: innerNS.length)
            for cell in cellRegex?.matches(in: inner, range: innerFull) ?? [] {
                guard cell.numberOfRanges > 1 else { continue }
                let raw = innerNS.substring(with: cell.range(at: 1))
                let cleaned = decodeHTMLEntities(stripTags(raw))
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                currentRow.append(cleaned)
            }
            if !currentRow.isEmpty {
                rows.append(currentRow)
            }
        }

        if rows.isEmpty { throw BankImportError.noTransactions }
        return rows
    }

    private static func stripTags(_ raw: String) -> String {
        raw.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&amp;", with: "&", options: .caseInsensitive)
            .replacingOccurrences(of: "&lt;", with: "<", options: .caseInsensitive)
            .replacingOccurrences(of: "&gt;", with: ">", options: .caseInsensitive)
            .replacingOccurrences(of: "&quot;", with: "\"", options: .caseInsensitive)
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}

// MARK: - PDF

private enum PDFTable {
    static func read(_ data: Data) throws -> [[String]] {
        guard let document = PDFDocument(data: data) else {
            throw BankImportError.invalidFile
        }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index),
                  let text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty
            else { continue }
            pages.append(text)
        }
        let blob = pages.joined(separator: "\n")
        guard !blob.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BankImportError.unscannablePDF
        }

        if let table = parseDelimited(blob), table.count >= 2 {
            return table
        }
        return parseLooseLines(blob)
    }

    private static func parseDelimited(_ text: String) -> [[String]]? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard lines.count >= 2 else { return nil }

        let candidates: [Character] = ["\t", ";", "|", ","]
        for delimiter in candidates {
            let rows = lines.map { splitKeepingEmpty($0, delimiter: delimiter) }
            let widths = rows.map(\.count)
            guard let maxWidth = widths.max(), maxWidth >= 3 else { continue }
            let rich = widths.filter { $0 == maxWidth }.count
            if rich >= max(2, lines.count / 3) {
                return rows
            }
        }
        return nil
    }

    private static func parseLooseLines(_ text: String) -> [[String]] {
        // Synthetic header so ColumnMap / inferWithoutHeader can work.
        var rows: [[String]] = [["Дата", "Сумма", "Описание"]]
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let datePattern = try? NSRegularExpression(
            pattern: #"(\d{1,2}[./-]\d{1,2}[./-]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)"#
        )
        let amountPattern = try? NSRegularExpression(
            pattern: #"([-+−–]?\(?\d{1,3}(?:[\s\u00A0\u202F]?\d{3})*(?:[.,]\d{1,2})?\)?)\s*(?:₸|тг|kzt|₽|rub)?"#,
            options: .caseInsensitive
        )

        for line in lines {
            let ns = line as NSString
            let full = NSRange(location: 0, length: ns.length)
            guard let datePattern,
                  let amountPattern,
                  let dateMatch = datePattern.firstMatch(in: line, range: full),
                  dateMatch.numberOfRanges > 1
            else { continue }

            let dateText = ns.substring(with: dateMatch.range(at: 1))
            guard parseDate(dateText, time: "") != nil else { continue }

            var amountText: String?
            let amountMatches = amountPattern.matches(in: line, range: full)
            for match in amountMatches.reversed() {
                guard match.numberOfRanges > 1 else { continue }
                let candidate = ns.substring(with: match.range(at: 1))
                // Skip if this span is inside the date.
                if NSIntersectionRange(match.range(at: 1), dateMatch.range(at: 1)).length > 0 { continue }
                if parseAmount(candidate) != nil {
                    amountText = candidate
                    break
                }
            }
            guard let amountText else { continue }

            var note = line
            note = (note as NSString).replacingCharacters(in: dateMatch.range(at: 1), with: " ")
            if let amountRange = note.range(of: amountText) {
                note.removeSubrange(amountRange)
            }
            note = note
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if statementSummary(note) { continue }
            rows.append([dateText, amountText, note])
        }
        return rows
    }

    private static func splitKeepingEmpty(_ line: String, delimiter: Character) -> [String] {
        line.split(separator: delimiter, omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

// MARK: - XLSX

private enum XLSXTable {
    static func read(_ data: Data) throws -> [[String]] {
        let files = try MiniZip.entries(from: data)
        let shared = parseSharedStrings(files["xl/sharedStrings.xml"] ?? files["xl/SharedStrings.xml"])
        let sheetData = files["xl/worksheets/sheet1.xml"]
            ?? files.first(where: { $0.key.hasPrefix("xl/worksheets/sheet") && $0.key.hasSuffix(".xml") })?.value
        guard let sheetData else { throw BankImportError.invalidFile }
        return try parseSheet(sheetData, shared: shared)
    }

    private static func parseSharedStrings(_ data: Data?) -> [String] {
        guard let data else { return [] }
        let parser = SharedStringsXML()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return parser.strings
    }

    private static func parseSheet(_ data: Data, shared: [String]) throws -> [[String]] {
        let parser = SheetXML(shared: shared)
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { throw BankImportError.invalidFile }
        return parser.rows
    }
}

private final class SharedStringsXML: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var current = ""
    private var capture = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        if elementName == "si" {
            current = ""
        } else if elementName == "t" {
            capture = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capture { current += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        if elementName == "t" {
            capture = false
        } else if elementName == "si" {
            strings.append(current)
        }
    }
}

private final class SheetXML: NSObject, XMLParserDelegate {
    let shared: [String]
    var rows: [[String]] = []
    private var currentRow: [String] = []
    private var currentType = ""
    private var currentRef = ""
    private var currentText = ""
    private var capture = false

    init(shared: [String]) {
        self.shared = shared
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        switch elementName {
        case "row":
            if !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = []
            }
        case "c":
            currentRef = attributes["r"] ?? ""
            currentType = attributes["t"] ?? ""
            currentText = ""
        case "v", "t":
            capture = true
            currentText = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capture { currentText += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        switch elementName {
        case "v", "t":
            capture = false
        case "c":
            let value: String
            if currentType == "s",
               let index = Int(currentText.trimmingCharacters(in: .whitespacesAndNewlines)),
               shared.indices.contains(index) {
                value = shared[index]
            } else {
                value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let column = columnIndex(currentRef)
            if column >= 0 {
                while currentRow.count <= column { currentRow.append("") }
                currentRow[column] = value
            }
        case "row":
            if !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = []
            }
        default:
            break
        }
    }

    private func columnIndex(_ ref: String) -> Int {
        let letters = ref.prefix { $0.isLetter }
        var value = 0
        for ch in letters.uppercased() {
            guard let ascii = ch.asciiValue else { return -1 }
            value = value * 26 + Int(ascii) - 64
        }
        return value - 1
    }
}

// MARK: - ZIP (xlsx)

private enum MiniZip {
    static func entries(from data: Data) throws -> [String: Data] {
        guard let eocd = findEOCD(in: data) else { throw BankImportError.invalidFile }
        let cdOffset = Int(eocd.cdOffset)
        let cdSize = Int(eocd.cdSize)
        guard cdOffset >= 0, cdOffset + cdSize <= data.count else { throw BankImportError.invalidFile }

        var result: [String: Data] = [:]
        var cursor = cdOffset
        let cdEnd = cdOffset + cdSize
        while cursor + 46 <= cdEnd {
            guard data[cursor] == 0x50, data[cursor + 1] == 0x4B,
                  data[cursor + 2] == 0x01, data[cursor + 3] == 0x02
            else { break }
            let method = u16(data, cursor + 10)
            let compressedSize = Int(u32(data, cursor + 20))
            let uncompressedSize = Int(u32(data, cursor + 24))
            let nameLen = Int(u16(data, cursor + 28))
            let extraLen = Int(u16(data, cursor + 30))
            let commentLen = Int(u16(data, cursor + 32))
            let localOffset = Int(u32(data, cursor + 42))
            let nameStart = cursor + 46
            guard nameStart + nameLen <= data.count else { throw BankImportError.invalidFile }
            let name = String(data: data.subdata(in: nameStart..<(nameStart + nameLen)), encoding: .utf8) ?? ""
            result[name] = try readFile(
                data: data,
                localOffset: localOffset,
                method: method,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize
            )
            cursor = nameStart + nameLen + extraLen + commentLen
        }
        return result
    }

    private static func readFile(
        data: Data,
        localOffset: Int,
        method: UInt16,
        compressedSize: Int,
        uncompressedSize: Int
    ) throws -> Data {
        guard localOffset + 30 <= data.count else { throw BankImportError.invalidFile }
        let nameLen = Int(u16(data, localOffset + 26))
        let extraLen = Int(u16(data, localOffset + 28))
        let dataStart = localOffset + 30 + nameLen + extraLen
        guard dataStart + compressedSize <= data.count else { throw BankImportError.invalidFile }
        let payload = data.subdata(in: dataStart..<(dataStart + compressedSize))
        switch method {
        case 0:
            return payload
        case 8:
            guard uncompressedSize > 0, uncompressedSize < 20_000_000 else { throw BankImportError.invalidFile }
            return try inflate(payload, uncompressedSize: uncompressedSize)
        default:
            throw BankImportError.invalidFile
        }
    }

    private struct EOCD {
        var cdSize: UInt32
        var cdOffset: UInt32
    }

    private static func findEOCD(in data: Data) -> EOCD? {
        let maxScan = min(data.count, 65_557)
        guard maxScan >= 22 else { return nil }
        let start = data.count - maxScan
        var index = data.count - 22
        while index >= start {
            if data[index] == 0x50, data[index + 1] == 0x4B,
               data[index + 2] == 0x05, data[index + 3] == 0x06 {
                let commentLen = Int(u16(data, index + 20))
                if index + 22 + commentLen == data.count {
                    return EOCD(cdSize: u32(data, index + 12), cdOffset: u32(data, index + 16))
                }
            }
            index -= 1
        }
        return nil
    }

    private static func inflate(_ input: Data, uncompressedSize: Int) throws -> Data {
        var output = Data(count: uncompressedSize)
        let written = output.withUnsafeMutableBytes { outBuf -> Int in
            input.withUnsafeBytes { inBuf -> Int in
                guard let inPtr = inBuf.bindMemory(to: UInt8.self).baseAddress,
                      let outPtr = outBuf.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    outPtr,
                    uncompressedSize,
                    inPtr,
                    input.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard written > 0 else { throw BankImportError.invalidFile }
        if written < uncompressedSize {
            output.removeSubrange(written...)
        }
        return output
    }
}

private func isZIP(_ data: Data) -> Bool {
    data.count >= 4 && data[0] == 0x50 && data[1] == 0x4B && data[2] == 0x03 && data[3] == 0x04
}

private func isPDF(_ data: Data) -> Bool {
    guard data.count >= 5 else { return false }
    // %PDF-
    return data[0] == 0x25 && data[1] == 0x50 && data[2] == 0x44 && data[3] == 0x46 && data[4] == 0x2D
}

private func looksLikeHTML(_ data: Data) -> Bool {
    let sampleCount = min(data.count, 2048)
    guard sampleCount > 0 else { return false }
    let sample = data.prefix(sampleCount)
    let text = String(data: sample, encoding: .utf8)
        ?? String(data: sample, encoding: .windowsCP1251)
        ?? ""
    let lower = text.lowercased()
    return lower.contains("<html") || lower.contains("<table") || lower.contains("<tr")
}

private func statementSummary(_ text: String) -> Bool {
    let value = text.lowercased()
    return value.hasPrefix("итог")
        || value.hasPrefix("всего")
        || value.contains("остаток")
        || value.contains("баланс на")
        || value == "баланс"
}

private func isOLECompound(_ data: Data) -> Bool {
    data.count >= 8
        && data[0] == 0xD0 && data[1] == 0xCF && data[2] == 0x11 && data[3] == 0xE0
}

private func u16(_ data: Data, _ offset: Int) -> UInt16 {
    UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
}

private func u32(_ data: Data, _ offset: Int) -> UInt32 {
    UInt32(data[offset])
        | UInt32(data[offset + 1]) << 8
        | UInt32(data[offset + 2]) << 16
        | UInt32(data[offset + 3]) << 24
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
