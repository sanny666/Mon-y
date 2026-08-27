import Foundation
import UIKit
import Vision

struct ReceiptOCRResult: Sendable {
    var amount: Double?
    var date: Date?
    var note: String?
}

enum ReceiptOCR {
    static func recognize(jpeg: Data) async -> ReceiptOCRResult {
        guard let image = UIImage(data: jpeg),
              let cgImage = image.cgImage else {
            return ReceiptOCRResult()
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ru-RU", "kk-KZ", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ReceiptOCRResult()
        }

        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return parse(lines: lines)
    }

    static func parse(lines: [String]) -> ReceiptOCRResult {
        ReceiptOCRResult(
            amount: extractAmount(from: lines),
            date: extractDate(from: lines),
            note: extractNote(from: lines)
        )
    }

    // MARK: - Amount

    private static func extractAmount(from lines: [String]) -> Double? {
        var best: (value: Double, score: Int)?

        for (index, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let lower = line.lowercased()
            if isNoiseAmountLine(lower) { continue }

            // Strip dates/times so "27.08.2026" never becomes amount 27.08.
            let cleaned = strippingDatesAndTimes(line)
            let cleanedLower = cleaned.lowercased()
            let next = index + 1 < lines.count
                ? lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            let currency = hasCurrency(line)
                || hasCurrency(cleaned)
                || isCurrencyToken(next)
            let keyword = containsAmountKeyword(cleanedLower) || containsAmountKeyword(lower)
            let prevKeyword = index > 0 && containsAmountKeyword(lines[index - 1].lowercased())
            let kaspiStyle = looksLikeKaspiAmountLine(cleaned) || looksLikeKaspiAmountLine(line)

            // Prefer dedicated "2 100 T" / "2100₸" hits first.
            for value in kaspiAmountMatches(in: cleaned) + kaspiAmountMatches(in: line) {
                let score = 90
                if best == nil || score > best!.score {
                    best = (value, score)
                }
            }

            for value in amountMatches(in: cleaned) {
                var score = 0
                if kaspiStyle { score += 55 }
                if currency { score += 50 }
                if keyword { score += 45 }
                if prevKeyword { score += 35 }
                if hasThousandGrouping(cleaned) { score += 30 }
                if !currency && !keyword && !prevKeyword && !kaspiStyle { score += 5 }
                score += min(Int(value), 100_000) / 2_000
                if value < 50, !currency, !keyword, !prevKeyword, !kaspiStyle { score -= 30 }

                if best == nil || score > best!.score {
                    best = (value, score)
                }
            }
        }

        // Thousand-grouped amounts ("2 100") are enough even without a currency glyph.
        guard let best, best.score >= 25 else { return nil }
        return best.value
    }

    /// Kaspi receipts: big green "2 100 T" — Vision often reads ₸ as Latin/Cyrillic T.
    private static func kaspiAmountMatches(in line: String) -> [Double] {
        let pattern = #"(?<!\d)(\d{1,3}(?:[ \u00A0\u202F]\d{3})+|\d+)([.,]\d{1,2})?\s*[TТ₸tт]\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = line as NSString
        return regex.matches(in: line, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges >= 2,
                  let intRange = Range(match.range(at: 1), in: line) else { return nil }
            let intPart = String(line[intRange])
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\u{00A0}", with: "")
                .replacingOccurrences(of: "\u{202F}", with: "")
            var frac = ""
            if match.numberOfRanges >= 3, let fracRange = Range(match.range(at: 2), in: line) {
                frac = String(line[fracRange]).replacingOccurrences(of: ",", with: ".")
            }
            return Double(intPart + frac)
        }
    }

    private static func looksLikeKaspiAmountLine(_ line: String) -> Bool {
        line.range(
            of: #"^\s*\d{1,3}(?:[ \u00A0\u202F]\d{3})+(?:[.,]\d{1,2})?\s*[TТ₸tт]?\s*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func isCurrencyToken(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return ["T", "Т", "t", "т", "₸", "тг", "Тг", "KZT", "kzt"].contains(t)
    }

    private static func amountMatches(in line: String) -> [Double] {
        let pattern = #"(?<!\d)(\d{1,3}(?:[ \u00A0\u202F]\d{3})+|\d+)([.,]\d{1,2})?(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = line as NSString
        return regex.matches(in: line, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            guard match.numberOfRanges >= 2,
                  let intRange = Range(match.range(at: 1), in: line) else { return nil }
            let intPart = String(line[intRange])
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\u{00A0}", with: "")
                .replacingOccurrences(of: "\u{202F}", with: "")
            var frac = ""
            if match.numberOfRanges >= 3, let fracRange = Range(match.range(at: 2), in: line) {
                frac = String(line[fracRange]).replacingOccurrences(of: ",", with: ".")
            }
            let text = intPart + frac
            guard let value = Double(text), value > 0, value < 100_000_000 else { return nil }
            if frac.isEmpty, (1900...2100).contains(Int(value)) { return nil }
            return value
        }
    }

    private static func hasThousandGrouping(_ line: String) -> Bool {
        line.range(of: #"\d[ \u00A0\u202F]\d{3}"#, options: .regularExpression) != nil
    }

    private static func strippingDatesAndTimes(_ line: String) -> String {
        let patterns = [
            #"\d{1,2}[./-]\d{1,2}[./-]\d{2,4}(?:[ T]\d{1,2}:\d{2}(?::\d{2})?)?"#,
            #"\d{4}-\d{2}-\d{2}(?:[ T]\d{1,2}:\d{2}(?::\d{2})?)?"#,
            #"\b\d{1,2}:\d{2}(?::\d{2})?\b"#
        ]
        var result = line
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        return result
    }

    private static func hasCurrency(_ line: String) -> Bool {
        let lower = line.lowercased()
        if lower.contains("₸")
            || lower.contains("тг")
            || lower.contains("kzt")
            || lower.contains("тенге")
            || lower.contains("₽")
            || lower.contains("rub")
            || lower.contains("$")
            || lower.contains("usd")
            || lower.contains("€")
            || lower.contains("eur") {
            return true
        }
        // Kaspi: Vision often reads ₸ as a lone "T"/"Т" after the number.
        return line.range(
            of: #"\d\s*[TТtт]\b"#,
            options: .regularExpression
        ) != nil
    }

    private static func containsAmountKeyword(_ lower: String) -> Bool {
        [
            "сумма", "итого", "всего", "к оплате", "оплачено", "списано",
            "amount", "total", "paid", "charge", "дебет", "расход"
        ].contains { lower.contains($0) }
    }

    private static func isNoiseAmountLine(_ lower: String) -> Bool {
        lower.contains("бин")
            || lower.contains("****")
            || (lower.contains("комисси") && lower.contains("%"))
            || lower.contains("курс")
            || lower.contains("дата")
            || lower.contains("время")
    }

    // MARK: - Date

    private static func extractDate(from lines: [String]) -> Date? {
        let formats = [
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy HH:mm",
            "dd.MM.yyyy",
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "dd.MM.yy HH:mm",
            "dd.MM.yy"
        ]
        let formatters = formats.map { format -> DateFormatter in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = format
            return formatter
        }

        let pattern = #"\d{1,2}[./-]\d{1,2}[./-]\d{2,4}(?:[ T]\d{1,2}:\d{2}(?::\d{2})?)?|\d{4}-\d{2}-\d{2}(?:[ T]\d{1,2}:\d{2}(?::\d{2})?)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        for line in lines {
            let ns = line as NSString
            for match in regex.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
                guard let range = Range(match.range, in: line) else { continue }
                let original = String(line[range])
                let dotted = original
                    .replacingOccurrences(of: "/", with: ".")
                    .replacingOccurrences(of: "-", with: ".")
                for formatter in formatters {
                    if let date = formatter.date(from: original) { return date }
                    if let date = formatter.date(from: dotted) { return date }
                    if let date = formatter.date(from: original.replacingOccurrences(of: ".", with: "-")) {
                        return date
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Note

    private static func extractNote(from lines: [String]) -> String? {
        let skip: [String] = [
            "чек", "квитанц", "успешно", "оплачено", "платеж",
            "kaspi", "halyk", "homebank", "forte", "jusan", "freedom",
            "сумма", "итого", "всего", "дата", "время", "комиссия", "карта",
            "телефон", "ттн", "rrn", "auth", "код", "тенге", "kzt"
        ]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3, trimmed.count <= 48 else { continue }
            let lower = trimmed.lowercased()
            if skip.contains(where: { lower.contains($0) }) { continue }
            if extractDate(from: [trimmed]) != nil { continue }
            if hasCurrency(trimmed) { continue }

            let cleaned = strippingDatesAndTimes(trimmed)
            let amounts = amountMatches(in: cleaned)
            let letters = trimmed.filter(\.isLetter).count
            // "2 500" / pure money lines are not merchant names.
            if !amounts.isEmpty, letters < 3 { continue }
            if letters < 3 { continue }
            return trimmed
        }
        return nil
    }
}
