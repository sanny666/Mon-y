import Foundation

enum CSVExportService {
    struct ExportResult {
        let fileURL: URL
        let rowCount: Int
    }

    enum ExportError: LocalizedError {
        case noTransactions
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .noTransactions:
                return "Нет транзакций для экспорта."
            case .writeFailed(let message):
                return "Не удалось сохранить CSV: \(message)"
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func export(transactions: [Transaction]) throws -> ExportResult {
        guard !transactions.isEmpty else {
            throw ExportError.noTransactions
        }

        var lines: [String] = [
            csvLine(["Дата", "Тип", "Сумма", "Валюта", "Счёт", "Счёт назначения", "Категория", "Заметка", "Теги"])
        ]

        for tx in transactions {
            let currency = tx.account?.currency ?? AppCurrency.kzt.rawValue
            lines.append(
                csvLine([
                    dateFormatter.string(from: tx.date),
                    tx.type.title,
                    formatAmount(tx.amount),
                    currency,
                    tx.account?.name ?? "",
                    tx.toAccount?.name ?? "",
                    tx.category?.displayName ?? "",
                    tx.note,
                    tx.tags.joined(separator: "; ")
                ])
            )
        }

        let body = lines.joined(separator: "\r\n")
        // UTF-8 BOM helps Excel open Cyrillic correctly.
        let bom = "\u{FEFF}"
        let data = Data((bom + body).utf8)

        let fileName = "money-transactions-\(fileDateFormatter.string(from: .now)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }

        return ExportResult(fileURL: url, rowCount: transactions.count)
    }

    private static func formatAmount(_ amount: Double) -> String {
        String(format: "%.2f", amount)
    }

    private static func csvLine(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    private static func escape(_ value: String) -> String {
        let needsQuotes = value.contains(",")
            || value.contains("\"")
            || value.contains("\n")
            || value.contains("\r")
        guard needsQuotes else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
