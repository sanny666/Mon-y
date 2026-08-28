import Foundation
import PDFKit
import Security
import UIKit
import UniformTypeIdentifiers

struct PendingReceipt: Sendable {
    var jpeg: Data
    var note: String?
}

/// Cross-process inbox for receipts shared from bank apps (Share Extension → main app).
/// Uses the shared keychain group already entitled on app, widget, and share targets.
enum ReceiptInbox {
    private static let service = "com.sany.fintrack.shared.receipt"
    private static let jpegAccount = "pendingJPEG"
    private static let noteAccount = "pendingNote"
    private static let accessGroup = "W8NW533LT9.com.sany.fintrack.shared"

    static var hasPending: Bool {
        jpegData() != nil
    }

    static func save(jpeg: Data, note: String?) throws {
        guard !jpeg.isEmpty else { throw InboxError.unsupported }
        setValue(jpeg, account: jpegAccount)
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            delete(account: noteAccount)
        } else {
            setValue(Data(trimmed.utf8), account: noteAccount)
        }
    }

    /// Reads the pending receipt without removing it from the inbox.
    static func peek() -> PendingReceipt? {
        guard let jpeg = jpegData(), !jpeg.isEmpty else { return nil }
        return PendingReceipt(jpeg: jpeg, note: noteValue())
    }

    static func consume() -> PendingReceipt? {
        guard let receipt = peek() else { return nil }
        clear()
        return receipt
    }

    /// Clears the inbox after save or when the user explicitly dismisses the draft.
    static func clear() {
        delete(account: jpegAccount)
        delete(account: noteAccount)
    }

    /// Copies a file the system handed the app ("Open in monёy") into the inbox as JPEG.
    static func ingestFile(at url: URL) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: url)
        guard let jpeg = jpeg(from: data, filename: url.lastPathComponent) else {
            throw InboxError.unsupported
        }
        try save(jpeg: jpeg, note: nil)
    }

    static func jpeg(from data: Data, filename: String = "", typeIdentifier: String? = nil) -> Data? {
        if let image = UIImage(data: data) {
            return compressedJPEG(from: image)
        }
        let name = filename.lowercased()
        let isPDF = typeIdentifier == UTType.pdf.identifier
            || name.hasSuffix(".pdf")
            || data.starts(with: [0x25, 0x50, 0x44, 0x46])
        if isPDF {
            return jpeg(fromPDF: data)
        }
        return nil
    }

    static func compressedJPEG(from image: UIImage, maxSide: CGFloat = 1400) -> Data? {
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        let scale = longest > maxSide ? maxSide / longest : 1
        let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        if let tight = scaled.jpegData(compressionQuality: 0.72), tight.count <= 380_000 {
            return tight
        }
        return scaled.jpegData(compressionQuality: 0.55)
    }

    private static func jpeg(fromPDF data: Data) -> Data? {
        guard let document = PDFDocument(data: data), let page = document.page(at: 0) else {
            return nil
        }
        let bounds = page.bounds(for: .mediaBox)
        let longest = max(bounds.width, bounds.height)
        let scale = longest > 0 ? min(2, 1400 / longest) : 1
        let size = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
        return compressedJPEG(from: image)
    }

    private static func jpegData() -> Data? {
        value(account: jpegAccount)
    }

    private static func noteValue() -> String? {
        guard let data = value(account: noteAccount) else { return nil }
        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (text?.isEmpty == false) ? text : nil
    }

    private static func value(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func setValue(_ data: Data, account: String) {
        delete(account: account)
        var attributes = baseQuery(account: account)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup
        ]
    }

    enum InboxError: LocalizedError {
        case unsupported

        var errorDescription: String? {
            switch self {
            case .unsupported:
                return "Этот файл нельзя прикрепить как чек."
            }
        }
    }
}
