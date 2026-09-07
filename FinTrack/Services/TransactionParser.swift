import Foundation

enum VoiceParseLexicon {
    static let expenseMarkers = [
        "потратила", "купила", "потратил", "заплатил", "оплатил", "купил"
    ]

    static let incomeMarkers = [
        "перевели мне", "получила", "получил", "скинули", "скинул",
        "зарплата", "заработал"
    ]

    static let transferMarkers = [
        "перевёл на", "перевела на", "положил на", "снял с"
    ]

    static let relativeDateMarkers: [(marker: String, dayOffset: Int)] = [
        ("позавчера", -2),
        ("вчера", -1),
        ("сегодня", 0)
    ]

    static let fillerWords: Set<String> = [
        "за", "в", "на", "с", "мне", "я", "то", "это", "что", "как", "у", "от", "до", "по", "и", "а"
    ]

    static let cardAccountMarkers = ["с карты", "картой", "с карточки", "с карточкой"]
    static let cashAccountMarkers = ["наличными", "наличкой", "кешем", "кэшем", "наличные"]

    static var typeMarkers: [(marker: String, type: TransactionType)] {
        let all: [(String, TransactionType)] =
            transferMarkers.map { ($0, .transfer) }
            + incomeMarkers.map { ($0, .income) }
            + expenseMarkers.map { ($0, .expense) }
        return all
            .sorted { $0.0.count > $1.0.count }
            .map { (marker: $0.0, type: $0.1) }
    }
}

struct VoiceParseInput {
    var text: String
    var accounts: [Account]
    var defaultAccountID: UUID?
    var now: Date = .now
}

struct VoiceParseResult {
    var type: TransactionType = .expense
    var amount: Double?
    var date: Date
    var itemName: String = ""
    var accountID: UUID?
    var toAccountID: UUID?
    var matchHint: String?
    var matchedCategoryID: UUID?
}

enum VoiceStringMatching {
    static func normalizeItemName(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stem(_ text: String) -> String {
        let normalized = normalizeItemName(text)
        guard normalized.count > 4 else { return normalized }
        return String(normalized.dropLast(min(2, normalized.count - 3)))
    }

    static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        if lhs == rhs { return 0 }
        if lhs.isEmpty { return rhs.count }
        if rhs.isEmpty { return lhs.count }

        let left = Array(lhs)
        let right = Array(rhs)
        var previous = Array(0...right.count)
        var current = Array(repeating: 0, count: right.count + 1)

        for i in 0..<left.count {
            current[0] = i + 1
            for j in 0..<right.count {
                let cost = left[i] == right[j] ? 0 : 1
                current[j + 1] = min(
                    current[j] + 1,
                    previous[j + 1] + 1,
                    previous[j] + cost
                )
            }
            previous = current
        }
        return previous[right.count]
    }
}

enum TransactionParser {
    static func parse(_ input: VoiceParseInput) -> VoiceParseResult {
        let calendar = Calendar.current
        var working = VoiceStringMatching.normalizeItemName(input.text)
        guard !working.isEmpty else {
            return VoiceParseResult(date: input.now)
        }

        let (type, afterType) = extractType(from: working)
        working = afterType

        let (dayStart, afterDate) = extractRelativeDate(from: working, now: input.now, calendar: calendar)
        working = afterDate

        let (timeComponents, afterTime) = extractTime(from: working, now: input.now, calendar: calendar)
        working = afterTime

        let mergedDate = mergeDate(
            dayStart: dayStart,
            hour: timeComponents.hour,
            minute: timeComponents.minute,
            calendar: calendar,
            fallback: input.now
        )

        let (amount, afterAmount) = extractAmount(from: working)
        working = afterAmount

        let (accountID, toAccountID, afterAccount) = extractAccount(
            from: working,
            accounts: input.accounts,
            type: type,
            defaultAccountID: input.defaultAccountID
        )
        working = afterAccount

        let itemName = extractItemName(from: working)

        return VoiceParseResult(
            type: type,
            amount: amount,
            date: mergedDate,
            itemName: itemName,
            accountID: accountID,
            toAccountID: toAccountID
        )
    }

    private static func extractType(from text: String) -> (TransactionType, String) {
        for marker in VoiceParseLexicon.typeMarkers {
            if let range = text.range(of: marker.marker) {
                let remaining = text.replacingCharacters(in: range, with: " ")
                return (marker.type, collapseSpaces(remaining))
            }
        }
        return (.expense, text)
    }

    private static func extractRelativeDate(
        from text: String,
        now: Date,
        calendar: Calendar
    ) -> (Date, String) {
        var working = text
        var dayOffset: Int?

        for marker in VoiceParseLexicon.relativeDateMarkers {
            if let range = working.range(of: marker.marker) {
                dayOffset = marker.dayOffset
                working = working.replacingCharacters(in: range, with: " ")
                break
            }
        }

        let base = dayOffset.map { offset in
            calendar.date(byAdding: .day, value: offset, to: now) ?? now
        } ?? now
        let dayStart = calendar.startOfDay(for: base)
        return (dayStart, collapseSpaces(working))
    }

    private static func extractTime(
        from text: String,
        now: Date,
        calendar: Calendar
    ) -> (DateComponents, String) {
        let pattern = #"(?:^|\s)в\s+(\d{1,2})(?::(\d{2}))?\s*(?:час|часа|часов)?\s*(дня|ночи|утра|вечера)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            return (DateComponents(hour: hour, minute: minute), text)
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              let fullRange = Range(match.range, in: text),
              let hourRange = Range(match.range(at: 1), in: text) else {
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            return (DateComponents(hour: hour, minute: minute), text)
        }

        let hour = Int(text[hourRange]) ?? calendar.component(.hour, from: now)
        var minute = 0
        if match.range(at: 2).location != NSNotFound,
           let minuteRange = Range(match.range(at: 2), in: text) {
            minute = Int(text[minuteRange]) ?? 0
        }

        var period: String?
        if match.range(at: 3).location != NSNotFound,
           let periodRange = Range(match.range(at: 3), in: text) {
            period = String(text[periodRange])
        }

        let adjustedHour = adjustHour(hour: hour, period: period)
        let remaining = text.replacingCharacters(in: fullRange, with: " ")
        return (DateComponents(hour: adjustedHour, minute: minute), collapseSpaces(remaining))
    }

    private static func adjustHour(hour: Int, period: String?) -> Int {
        guard let period else { return hour }
        switch period {
        case "ночи", "утра":
            return hour == 12 ? 0 : hour
        case "дня", "вечера":
            if hour == 12 { return 12 }
            if hour >= 1 && hour <= 11 { return hour + 12 }
            return hour
        default:
            return hour
        }
    }

    private static func mergeDate(
        dayStart: Date,
        hour: Int?,
        minute: Int?,
        calendar: Calendar,
        fallback: Date
    ) -> Date {
        let dayParts = calendar.dateComponents([.year, .month, .day], from: dayStart)
        let resolvedHour = hour ?? calendar.component(.hour, from: fallback)
        let resolvedMinute = minute ?? calendar.component(.minute, from: fallback)
        return calendar.date(
            from: DateComponents(
                year: dayParts.year,
                month: dayParts.month,
                day: dayParts.day,
                hour: resolvedHour,
                minute: resolvedMinute
            )
        ) ?? fallback
    }

    private static func extractAmount(from text: String) -> (Double?, String) {
        let pattern = #"(\d+(?:[.,]\d+)?)\s*(?:тг|тенге|kzt|₸|руб|₽|долл|\$|usd)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return (nil, text)
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              let fullRange = Range(match.range, in: text),
              let numberRange = Range(match.range(at: 1), in: text) else {
            return (nil, text)
        }

        let numberString = text[numberRange].replacingOccurrences(of: ",", with: ".")
        let amount = Double(numberString)
        let remaining = text.replacingCharacters(in: fullRange, with: " ")
        return (amount, collapseSpaces(remaining))
    }

    private static func extractAccount(
        from text: String,
        accounts: [Account],
        type: TransactionType,
        defaultAccountID: UUID?
    ) -> (UUID?, UUID?, String) {
        var working = text
        var accountID: UUID?
        var toAccountID: UUID?

        for marker in VoiceParseLexicon.cardAccountMarkers {
            if let range = working.range(of: marker) {
                accountID = accounts.first(where: { $0.type == .card })?.id ?? accountID
                working = working.replacingCharacters(in: range, with: " ")
            }
        }

        for marker in VoiceParseLexicon.cashAccountMarkers {
            if let range = working.range(of: marker) {
                accountID = accounts.first(where: { $0.type == .cash })?.id ?? accountID
                working = working.replacingCharacters(in: range, with: " ")
            }
        }

        for account in accounts {
            let name = VoiceStringMatching.normalizeItemName(account.name)
            guard name.count >= 2 else { continue }
            if working.contains(name) {
                if type == .transfer {
                    if toAccountID == nil {
                        toAccountID = account.id
                    } else if accountID == nil {
                        accountID = account.id
                    }
                } else {
                    accountID = account.id
                }
                working = working.replacingOccurrences(of: name, with: " ")
            }
        }

        if accountID == nil {
            accountID = defaultAccountID ?? accounts.first?.id
        }

        return (accountID, toAccountID, collapseSpaces(working))
    }

    private static func extractItemName(from text: String) -> String {
        let tokens = text.split(separator: " ").map(String.init)
        let filtered = tokens.filter { token in
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            return !VoiceParseLexicon.fillerWords.contains(trimmed)
        }
        return collapseSpaces(filtered.joined(separator: " "))
    }

    private static func collapseSpaces(_ text: String) -> String {
        VoiceStringMatching.normalizeItemName(text)
    }

    /// Search terms for dictionary / category matching: item name first, then meaningful transcript tokens.
    static func voiceSearchTerms(itemName: String, transcript: String) -> [String] {
        var terms: [String] = []
        var seen = Set<String>()

        func append(_ raw: String) {
            let normalized = VoiceStringMatching.normalizeItemName(raw)
            guard !normalized.isEmpty, !seen.contains(normalized) else { return }
            seen.insert(normalized)
            terms.append(normalized)
        }

        append(itemName)

        let normalized = VoiceStringMatching.normalizeItemName(transcript)
        for token in normalized.split(separator: " ").map(String.init) {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !VoiceParseLexicon.fillerWords.contains(trimmed) else { continue }
            if Double(trimmed.replacingOccurrences(of: ",", with: ".")) != nil { continue }
            append(trimmed)
        }

        return terms
    }
}
