import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let openButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .large)
    private var didFinishIngest = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        Task { await ingestAndHandoff() }
    }

    private func setupUI() {
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        statusLabel.text = "Сохраняю чек…"
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        var config = UIButton.Configuration.filled()
        config.cornerStyle = .large
        config.buttonSize = .large
        config.title = "Открыть monёy"
        openButton.configuration = config
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.isHidden = true
        openButton.addAction(UIAction { [weak self] _ in
            self?.openHostAppAndFinish()
        }, for: .touchUpInside)

        view.addSubview(spinner)
        view.addSubview(statusLabel)
        view.addSubview(openButton)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -36),
            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            openButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            openButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            openButton.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor)
        ])
    }

    private func ingestAndHandoff() async {
        let payload = await loadSharedPayload()
        if let jpeg = payload.jpeg {
            try? ReceiptInbox.save(jpeg: jpeg, note: payload.note)
        }
        QuickAddFlag.markPending()
        didFinishIngest = true

        await MainActor.run {
            spinner.stopAnimating()
            spinner.isHidden = true
            statusLabel.text = "Чек готов. Откройте monёy, чтобы добавить транзакцию."
            openButton.isHidden = false
            // Try auto-open; iOS often blocks this from Share Extension — button remains.
            openHostApp()
        }
    }

    private func openHostAppAndFinish() {
        openHostApp()
        // Give SpringBoard a moment to switch apps before tearing down the extension.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private struct Payload {
        var jpeg: Data?
        var note: String?
    }

    private func loadSharedPayload() async -> Payload {
        var jpegData: Data?
        var note: String?
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        for item in items {
            if let text = item.attributedContentText?.string, note == nil {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                // Don't treat a bare amount/date as merchant note.
                if !trimmed.isEmpty, trimmed.rangeOfCharacter(from: .letters) != nil {
                    note = trimmed
                }
            }
            for provider in item.attachments ?? [] {
                if jpegData == nil, let data = await loadJPEG(from: provider) {
                    jpegData = data
                }
                if note == nil, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let text = await loadString(from: provider, type: UTType.plainText.identifier) {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.rangeOfCharacter(from: .letters) != nil {
                        note = trimmed
                    }
                }
            }
        }
        return Payload(jpeg: jpegData, note: note)
    }

    private func loadJPEG(from provider: NSItemProvider) async -> Data? {
        let imageTypes = [UTType.image, .jpeg, .png, .heic, .tiff]
        for type in imageTypes where provider.hasItemConformingToTypeIdentifier(type.identifier) {
            if let data = await loadData(from: provider, type: type.identifier),
               let jpeg = ReceiptInbox.jpeg(from: data, typeIdentifier: type.identifier) {
                return jpeg
            }
            if let image = await loadImage(from: provider, type: type.identifier),
               let jpeg = ReceiptInbox.compressedJPEG(from: image) {
                return jpeg
            }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier),
           let data = await loadData(from: provider, type: UTType.pdf.identifier),
           let jpeg = ReceiptInbox.jpeg(from: data, typeIdentifier: UTType.pdf.identifier) {
            return jpeg
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let url = await loadFileURL(from: provider) {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            if let data = try? Data(contentsOf: url) {
                return ReceiptInbox.jpeg(from: data, filename: url.lastPathComponent)
            }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = await loadURL(from: provider), url.isFileURL,
           let data = try? Data(contentsOf: url) {
            return ReceiptInbox.jpeg(from: data, filename: url.lastPathComponent)
        }
        return nil
    }

    private func loadData(from provider: NSItemProvider, type: String) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func loadImage(from provider: NSItemProvider, type: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let image = item as? UIImage {
                    continuation.resume(returning: image)
                } else if let url = item as? URL, let data = try? Data(contentsOf: url) {
                    continuation.resume(returning: UIImage(data: data))
                } else if let data = item as? Data {
                    continuation.resume(returning: UIImage(data: data))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                continuation.resume(returning: item as? URL)
            }
        }
    }

    private func loadString(from provider: NSItemProvider, type: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func openHostApp() {
        guard let url = URL(string: "mony://add") else { return }

        // 1) Prefer extensionContext.open when available (works with user gesture).
        if let context = extensionContext {
            context.open(url) { _ in }
        }

        // 2) Walk responder chain for UIApplication.open
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            let selector = sel_registerName("openURL:")
            if current.responds(to: selector) {
                _ = current.perform(selector, with: url)
            }
            responder = current.next
        }
    }
}
