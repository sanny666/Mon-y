import Foundation

enum VoiceParseLexicon {
    static let expenseMarkers = [
        "потратила", "купила", "потратил", "заплатил", "оплатил", "купил",
        "заплатила", "оплатила", "потрачено", "купили"
    ]

    static let incomeMarkers = [
        "перевели мне", "получила", "получил", "скинули", "скинул",
        "зарплата", "заработал", "заработала"
    ]

    static let transferMarkers = [
        "перевёл на", "перевела на", "положил на", "положила на", "снял с", "сняла с",
        "перевёл", "перевела", "перевел", "перекинул", "перекинула", "перевод"
    ]

    static let relativeDateMarkers: [(marker: String, dayOffset: Int)] = [
        ("позавчера", -2),
        ("вчера", -1),
        ("сегодня", 0)
    ]

    static let fillerWords: Set<String> = [
        "за", "в", "на", "с", "мне", "я", "то", "это", "что", "как", "у", "от", "до", "по", "и", "а"
    ]

    static let thousandWords: Set<String> = [
        "тыща", "тыщи", "тыщу", "тыщей", "тыще", "тыщой", "тища",
        "тысяча", "тысячи", "тысячу", "тысячей", "тысяч",
        "тыс"
    ]

    static let millionWords: Set<String> = [
        "миллион", "миллиона", "миллионов", "миллиончик",
        "лям", "ляма", "лямов", "лимон", "лимона", "лимонов"
    ]

    static let currencyWords: Set<String> = [
        "тг", "тенге", "kzt", "₸", "руб", "рубль", "рубля", "рублей", "₽",
        "долл", "доллар", "доллара", "долларов", "usd", "$"
    ]

    /// Spoken 0...900 used as building blocks ("двести тридцать", "две тыщи").
    static let numberWordValues: [String: Double] = [
        "ноль": 0, "нуль": 0,
        "один": 1, "одна": 1, "одно": 1, "одну": 1,
        "два": 2, "две": 2, "двое": 2,
        "три": 3, "трое": 3,
        "четыре": 4, "пять": 5, "шесть": 6, "семь": 7, "восемь": 8, "девять": 9,
        "десять": 10,
        "одиннадцать": 11, "двенадцать": 12, "тринадцать": 13, "четырнадцать": 14,
        "пятнадцать": 15, "шестнадцать": 16, "семнадцать": 17, "восемнадцать": 18,
        "девятнадцать": 19,
        "двадцать": 20, "тридцать": 30, "сорок": 40, "пятьдесят": 50,
        "шестьдесят": 60, "семьдесят": 70, "восемьдесят": 80, "девяносто": 90,
        "сто": 100, "двести": 200, "триста": 300, "четыреста": 400, "пятьсот": 500,
        "шестьсот": 600, "семьсот": 700, "восемьсот": 800, "девятьсот": 900,
        "полтора": 1.5, "полторы": 1.5,
        "полтыщи": 500, "полтысячи": 500
    ]

    static let cardAccountMarkers = ["с карты", "картой", "с карточки", "с карточкой"]
    static let cashAccountMarkers = [
        "наличными", "наличкой", "кешем", "кэшем", "наличные", "наличных", "с наличных", "с наличными"
    ]

    static func scaleValue(for token: String) -> Double? {
        if thousandWords.contains(token) { return 1_000 }
        if millionWords.contains(token) { return 1_000_000 }
        return nil
    }

    static func isAmountToken(_ raw: String) -> Bool {
        let token = VoiceStringMatching.normalizeItemName(raw)
        guard !token.isEmpty else { return false }
        if thousandWords.contains(token)
            || millionWords.contains(token)
            || currencyWords.contains(token)
            || numberWordValues[token] != nil {
            return true
        }
        return TransactionParser.digitValue(token) != nil
    }

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
    /// True when transcript contained вчера/сегодня/позавчера (or similar).
    var hasExplicitDate: Bool = false
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
        // Keep short words intact so "такси" does not collapse to "так"
        // and fuzzy-match aliases like "кск".
        guard normalized.count >= 6 else { return normalized }
        return String(normalized.dropLast(min(2, normalized.count - 4)))
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
        parseSegment(input.text, input: input)
    }

    /// Splits a transcript into multiple transactions when several amounts are spoken.
    static func parseMultiple(_ input: VoiceParseInput) -> [VoiceParseResult] {
        let normalized = VoiceStringMatching.normalizeItemName(input.text)
        guard !normalized.isEmpty else { return [] }

        let segments = splitIntoSegments(normalized)
        guard !segments.isEmpty else {
            let single = parseSegment(normalized, input: input)
            return single.amount != nil ? [single] : []
        }

        var results: [VoiceParseResult] = []
        var inheritedDay: Date?

        for segment in segments {
            var result = parseSegment(segment, input: input)
            guard let amount = result.amount, amount > 0 else { continue }

            if !result.hasExplicitDate, let inheritedDay {
                result.date = mergeDate(
                    dayStart: inheritedDay,
                    hour: Calendar.current.component(.hour, from: result.date),
                    minute: Calendar.current.component(.minute, from: result.date),
                    calendar: .current,
                    fallback: result.date
                )
            }

            if result.hasExplicitDate {
                inheritedDay = Calendar.current.startOfDay(for: result.date)
            } else if inheritedDay == nil {
                inheritedDay = Calendar.current.startOfDay(for: result.date)
            }

            results.append(result)
        }

        return results
    }

    private static func parseSegment(_ text: String, input: VoiceParseInput) -> VoiceParseResult {
        let calendar = Calendar.current
        var working = VoiceStringMatching.normalizeItemName(text)
        guard !working.isEmpty else {
            return VoiceParseResult(date: input.now)
        }

        let (type, afterType) = extractType(from: working)
        working = afterType

        let (dayStart, afterDate, hasExplicitDate) = extractRelativeDate(
            from: working,
            now: input.now,
            calendar: calendar
        )
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
            toAccountID: toAccountID,
            hasExplicitDate: hasExplicitDate
        )
    }

    private static func splitIntoSegments(_ text: String) -> [String] {
        let tokens = text.split { $0.isWhitespace }.map(String.init)
        guard !tokens.isEmpty else { return [] }

        let amounts = findAllSpokenAmounts(in: tokens)
        let verbs = findTypeMarkerTokenRanges(in: tokens)

        if amounts.count >= 2, verbs.count >= 2 {
            return splitByVerbMarkers(tokens: tokens, verbs: verbs)
                .map { collapseSpaces($0) }
                .filter { !$0.isEmpty }
        }

        if amounts.count >= 2 {
            return splitByAmounts(tokens: tokens, amounts: amounts)
                .map { collapseSpaces($0) }
                .filter { !$0.isEmpty }
        }

        return [text]
    }

    private static func splitByVerbMarkers(
        tokens: [String],
        verbs: [(start: Int, end: Int)]
    ) -> [String] {
        var segments: [String] = []
        for (index, verb) in verbs.enumerated() {
            let start = index == 0 ? 0 : verb.start
            let end = index + 1 < verbs.count ? verbs[index + 1].start : tokens.count
            guard start < end, start < tokens.count else { continue }
            let slice = tokens[start..<min(end, tokens.count)]
            segments.append(slice.joined(separator: " "))
        }
        // Leading words before first verb (e.g. "вчера") belong to first segment — already included when index==0 starts at 0.
        // If first verb starts after 0, first segment already has them. Good.
        // But when index > 0 we start at verb.start, so words between verbs are in previous segment. Good.
        // Fix first segment: if verbs[0].start > 0, first iteration starts at 0 — includes leading date. Good.
        return segments
    }

    private static func splitByAmounts(
        tokens: [String],
        amounts: [SpokenAmountHit]
    ) -> [String] {
        var segments: [String] = []
        for (index, amount) in amounts.enumerated() {
            let start = index == 0 ? 0 : amounts[index - 1].end
            let end = index + 1 < amounts.count ? amounts[index + 1].start : tokens.count
            guard start < end else { continue }
            let slice = tokens[start..<min(end, tokens.count)]
            segments.append(slice.joined(separator: " "))
            _ = amount
        }
        return segments
    }

    private static func findTypeMarkerTokenRanges(in tokens: [String]) -> [(start: Int, end: Int)] {
        let joined = tokens.joined(separator: " ")
        var hits: [(start: Int, end: Int, location: Int)] = []

        for marker in VoiceParseLexicon.typeMarkers {
            var searchStart = joined.startIndex
            while searchStart < joined.endIndex,
                  let range = joined.range(of: marker.marker, range: searchStart..<joined.endIndex) {
                let prefix = String(joined[joined.startIndex..<range.lowerBound])
                let startToken = prefix.isEmpty ? 0 : prefix.split { $0.isWhitespace }.count
                let markerTokenCount = marker.marker.split { $0.isWhitespace }.count
                let location = joined.distance(from: joined.startIndex, to: range.lowerBound)
                hits.append((startToken, startToken + markerTokenCount, location))
                searchStart = range.upperBound
            }
        }

        hits.sort { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return (rhs.end - rhs.start) > (lhs.end - lhs.start)
        }

        var selected: [(start: Int, end: Int)] = []
        var lastEnd = -1
        for hit in hits {
            if hit.start >= lastEnd {
                selected.append((hit.start, hit.end))
                lastEnd = hit.end
            }
        }
        return selected
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
    ) -> (Date, String, Bool) {
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
        return (dayStart, collapseSpaces(working), dayOffset != nil)
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
        let tokens = text.split { $0.isWhitespace }.map(String.init)
        if let hit = findSpokenAmount(in: tokens) {
            var remaining = tokens
            remaining.removeSubrange(hit.start..<hit.end)
            return (hit.amount, collapseSpaces(remaining.joined(separator: " ")))
        }
        return (nil, text)
    }

    private struct SpokenAmountHit {
        var amount: Double
        var start: Int
        var end: Int
        var score: Int
    }

    private static func findAllSpokenAmounts(in tokens: [String]) -> [SpokenAmountHit] {
        let candidates = collectSpokenAmountCandidates(in: tokens)
            .sorted { lhs, rhs in
                if lhs.start != rhs.start { return lhs.start < rhs.start }
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return (lhs.end - lhs.start) > (rhs.end - rhs.start)
            }

        var selected: [SpokenAmountHit] = []
        var lastEnd = 0
        for hit in candidates where hit.start >= lastEnd {
            selected.append(hit)
            lastEnd = hit.end
        }
        return selected
    }

    private static func findSpokenAmount(in tokens: [String]) -> SpokenAmountHit? {
        collectSpokenAmountCandidates(in: tokens).max { lhs, rhs in
            let lhsSpan = lhs.end - lhs.start
            let rhsSpan = rhs.end - rhs.start
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            if lhsSpan != rhsSpan { return lhsSpan < rhsSpan }
            return lhs.start > rhs.start
        }
    }

    private static func collectSpokenAmountCandidates(in tokens: [String]) -> [SpokenAmountHit] {
        var candidates: [SpokenAmountHit] = []

        func consider(amount: Double, start: Int, end: Int, score: Int) {
            guard end > start, amount > 0 else { return }
            var actualEnd = end
            if actualEnd < tokens.count {
                let next = VoiceStringMatching.normalizeItemName(tokens[actualEnd])
                if VoiceParseLexicon.currencyWords.contains(next) {
                    actualEnd += 1
                }
            }
            candidates.append(SpokenAmountHit(amount: amount, start: start, end: actualEnd, score: score))
        }

        for start in 0..<tokens.count {
            let token = VoiceStringMatching.normalizeItemName(tokens[start])

            if let scale = VoiceParseLexicon.scaleValue(for: token) {
                if let remainder = consumeNumeric(tokens: tokens, from: start + 1) {
                    consider(amount: scale + remainder.value, start: start, end: remainder.end, score: 30)
                } else {
                    consider(amount: scale, start: start, end: start + 1, score: 25)
                }
                continue
            }

            guard let numeric = consumeNumeric(tokens: tokens, from: start) else { continue }
            if numeric.end < tokens.count {
                let scaleToken = VoiceStringMatching.normalizeItemName(tokens[numeric.end])
                if let scale = VoiceParseLexicon.scaleValue(for: scaleToken) {
                    var end = numeric.end + 1
                    var remainder = 0.0
                    if let parsed = consumeNumeric(tokens: tokens, from: end) {
                        remainder = parsed.value
                        end = parsed.end
                    }
                    consider(
                        amount: numeric.value * scale + remainder,
                        start: start,
                        end: end,
                        score: 40
                    )
                    continue
                }
            }

            // Spoken money over ~2000: "2 пятьсот", "четыре двести", "4 ноль ноль".
            if isWholeThousandHead(numeric.value),
               let implicit = consumeImplicitThousandsRemainder(tokens: tokens, from: numeric.end) {
                consider(
                    amount: numeric.value * 1_000 + implicit.value,
                    start: start,
                    end: implicit.end,
                    score: 35
                )
            }

            consider(amount: numeric.value, start: start, end: numeric.end, score: 10)
        }

        return candidates
    }

    private static func isWholeThousandHead(_ value: Double) -> Bool {
        value >= 1 && value <= 99 && value == value.rounded()
    }

    /// Remainder after a short thousand head, without the word "тысяча".
    private static func consumeImplicitThousandsRemainder(
        tokens: [String],
        from start: Int
    ) -> (value: Double, end: Int)? {
        if let zerosEnd = consumeRoundZeros(tokens: tokens, from: start) {
            return (0, zerosEnd)
        }
        guard let rest = consumeBelowThousand(tokens: tokens, from: start) else { return nil }
        guard rest.value >= 100, rest.value <= 999 else { return nil }
        return rest
    }

    /// "ноль ноль" / "00" / "000" → round thousands ("четыре ноль ноль" = 4000).
    private static func consumeRoundZeros(tokens: [String], from start: Int) -> Int? {
        guard start < tokens.count else { return nil }
        let first = VoiceStringMatching.normalizeItemName(tokens[start])
        if first == "00" || first == "000" { return start + 1 }
        guard isZeroToken(first) else { return nil }
        guard start + 1 < tokens.count else { return nil }
        let second = VoiceStringMatching.normalizeItemName(tokens[start + 1])
        guard isZeroToken(second) else { return nil }
        return start + 2
    }

    private static func isZeroToken(_ token: String) -> Bool {
        if token == "ноль" || token == "нуль" { return true }
        if token == "0" || token == "00" || token == "000" { return true }
        return false
    }

    private static func consumeNumeric(tokens: [String], from start: Int) -> (value: Double, end: Int)? {
        if let below = consumeBelowThousand(tokens: tokens, from: start) {
            return below
        }
        guard start < tokens.count else { return nil }
        let token = VoiceStringMatching.normalizeItemName(tokens[start])
        guard VoiceParseLexicon.numberWordValues[token] == nil else { return nil }
        guard let digit = digitValue(token) else { return nil }
        return (digit, start + 1)
    }

    /// 1...999 in Russian place order (hundreds → tens → units).
    /// "четыре двести" does not become 204: hundreds cannot follow units.
    private static func consumeBelowThousand(tokens: [String], from start: Int) -> (value: Double, end: Int)? {
        guard start < tokens.count else { return nil }

        let firstToken = VoiceStringMatching.normalizeItemName(tokens[start])
        if VoiceParseLexicon.scaleValue(for: firstToken) != nil { return nil }
        if VoiceParseLexicon.currencyWords.contains(firstToken) { return nil }

        if VoiceParseLexicon.numberWordValues[firstToken] == nil,
           let digit = digitValue(firstToken),
           digit == digit.rounded(),
           digit >= 1, digit <= 999 {
            return (digit, start + 1)
        }

        var index = start
        var total: Double = 0
        var usedHundreds = false
        var usedTens = false
        var usedUnits = false

        while index < tokens.count {
            let token = VoiceStringMatching.normalizeItemName(tokens[index])
            if VoiceParseLexicon.scaleValue(for: token) != nil { break }
            if VoiceParseLexicon.currencyWords.contains(token) { break }

            if VoiceParseLexicon.numberWordValues[token] == nil,
               let digit = digitValue(token),
               digit == digit.rounded() {
                if total > 0, digit >= 1, digit <= 99, !usedTens, !usedUnits {
                    total += digit
                    usedTens = true
                    usedUnits = true
                    index += 1
                }
                break
            }

            guard let value = VoiceParseLexicon.numberWordValues[token] else { break }
            if value != value.rounded() {
                guard total == 0 else { break }
                return (value, index + 1)
            }

            if value >= 100, value <= 900, Int(value) % 100 == 0 {
                guard !usedHundreds, !usedTens, !usedUnits else { break }
                total += value
                usedHundreds = true
                index += 1
                continue
            }
            if value >= 10, value <= 19 {
                guard !usedTens, !usedUnits else { break }
                total += value
                usedTens = true
                usedUnits = true
                index += 1
                continue
            }
            if value >= 20, value <= 90, Int(value) % 10 == 0 {
                guard !usedTens, !usedUnits else { break }
                total += value
                usedTens = true
                index += 1
                continue
            }
            if value >= 1, value <= 9 {
                guard !usedUnits else { break }
                total += value
                usedUnits = true
                index += 1
                continue
            }
            break
        }

        guard index > start, total > 0 else { return nil }
        return (total, index)
    }

    /// Digits, `1,2к` / `1.2k`, and values with a glued currency suffix.
    static func digitValue(_ raw: String) -> Double? {
        var token = VoiceStringMatching.normalizeItemName(raw)
        guard !token.isEmpty else { return nil }

        for suffix in VoiceParseLexicon.currencyWords.sorted(by: { $0.count > $1.count }) {
            if token.hasSuffix(suffix) {
                token = String(token.dropLast(suffix.count))
                break
            }
        }
        token = token.trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty else { return nil }

        var multiplier = 1.0
        if token.hasSuffix("к") || token.hasSuffix("k") {
            let stem = String(token.dropLast())
            let normalizedStem = stem.replacingOccurrences(of: ",", with: ".")
            if !stem.isEmpty, Double(normalizedStem) != nil {
                multiplier = 1_000
                token = stem
            }
        }

        let normalized = token.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return nil }
        return value * multiplier
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
            guard !VoiceParseLexicon.fillerWords.contains(trimmed) else { return false }
            return !VoiceParseLexicon.isAmountToken(trimmed)
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
            guard !VoiceParseLexicon.isAmountToken(trimmed) else { continue }
            append(trimmed)
        }

        return terms
    }
}

enum CategoryVoiceMatcher {
    static func match(
        terms: [String],
        type: TransactionType,
        categories: [Category]
    ) -> (category: Category, term: String)? {
        let needed: CategoryType = type == .income ? .income : .expense
        var seen = Set<UUID>()
        let pool = categories.filter { category in
            !category.isDeleted && category.type == needed && seen.insert(category.id).inserted
        }
        guard type != .transfer, !pool.isEmpty else { return nil }

        for term in terms {
            let needle = VoiceStringMatching.normalizeItemName(term)
                .replacingOccurrences(of: "ё", with: "е")
            guard !needle.isEmpty else { continue }
            let exact = pool.filter {
                VoiceStringMatching.normalizeItemName($0.name)
                    .replacingOccurrences(of: "ё", with: "е") == needle
            }
            if let category = prefer(exact) {
                return (category, term)
            }
        }

        for term in terms where !term.contains(" ") && term.count >= 4 {
            let needle = VoiceStringMatching.normalizeItemName(term)
                .replacingOccurrences(of: "ё", with: "е")
            let stemmed = VoiceStringMatching.stem(needle)
            var best: (category: Category, distance: Int)?

            for category in pool {
                let name = VoiceStringMatching.normalizeItemName(category.name)
                    .replacingOccurrences(of: "ё", with: "е")
                guard name.count >= 4 else { continue }
                let distance = VoiceStringMatching.levenshteinDistance(
                    stemmed,
                    VoiceStringMatching.stem(name)
                )
                let maxLength = max(stemmed.count, VoiceStringMatching.stem(name).count)
                let threshold = maxLength <= 5 ? 1 : max(1, Int(Double(maxLength) * 0.25))
                guard distance > 0, distance <= threshold else { continue }
                if let current = best {
                    if distance < current.distance
                        || (distance == current.distance && category.isSubcategory && !current.category.isSubcategory) {
                        best = (category, distance)
                    }
                } else {
                    best = (category, distance)
                }
            }

            if let best {
                return (best.category, term)
            }
        }

        return nil
    }

    private static func prefer(_ categories: [Category]) -> Category? {
        categories.sorted { lhs, rhs in
            if lhs.isSubcategory != rhs.isSubcategory {
                return lhs.isSubcategory && !rhs.isSubcategory
            }
            return lhs.name.count > rhs.name.count
        }.first
    }
}
