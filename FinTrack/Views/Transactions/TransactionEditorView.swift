import PhotosUI
import SwiftUI
import UIKit

struct TransactionEditorView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction?
    var initialJPEG: Data? = nil
    var initialNote: String? = nil

    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var date = Date.now
    @State private var note = ""
    @State private var tags: [String] = []
    @State private var tagDraft = ""
    @State private var attachmentURL: String?
    @State private var attachmentPreview: UIImage?
    @State private var pendingJPEG: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedAccountID: UUID?
    @State private var selectedToAccountID: UUID?
    @State private var selectedRootCategoryID: UUID?
    @State private var selectedSubcategoryID: UUID?
    @State private var accounts: [Account] = []
    @State private var rootCategories: [Category] = []
    @State private var errorMessage: String?

    private var filteredRoots: [Category] {
        guard type != .transfer else { return [] }
        let needed: CategoryType = type == .income ? .income : .expense
        return rootCategories.filter { $0.type == needed }
    }

    private var selectedRoot: Category? {
        filteredRoots.first(where: { $0.id == selectedRootCategoryID })
    }

    private var subcategories: [Category] {
        (selectedRoot?.children ?? []).sorted {
            $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Сумма", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2.weight(.semibold))
                }

                Section("Счета") {
                    Picker("Счёт", selection: $selectedAccountID) {
                        Text("Выберите").tag(Optional<UUID>.none)
                        ForEach(accounts, id: \.id) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }

                    if type == .transfer {
                        Picker("Куда", selection: $selectedToAccountID) {
                            Text("Выберите").tag(Optional<UUID>.none)
                            ForEach(accounts.filter { $0.id != selectedAccountID }, id: \.id) { account in
                                Text(account.name).tag(Optional(account.id))
                            }
                        }
                    }
                }

                if type != .transfer {
                    Section("Категория") {
                        Picker("Категория", selection: $selectedRootCategoryID) {
                            Text("Без категории").tag(Optional<UUID>.none)
                            ForEach(filteredRoots, id: \.id) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                        .onChange(of: selectedRootCategoryID) { _, _ in
                            selectedSubcategoryID = nil
                        }

                        if !subcategories.isEmpty {
                            Picker("Подкатегория", selection: $selectedSubcategoryID) {
                                Text("Без подкатегории").tag(Optional<UUID>.none)
                                ForEach(subcategories, id: \.id) { category in
                                    Text(category.name).tag(Optional(category.id))
                                }
                            }
                        }
                    }
                }

                Section {
                    DatePicker("Дата", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Дополнительно") {
                    tagsEditor
                    TextField("Комментарий", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                    photoEditor
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ModalCloseToolbarItem { dismiss() }
                ModalConfirmToolbarItem(isDisabled: !canSave) { save() }
                ToolbarItem(placement: .principal) {
                    typeSlider
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: type) { _, _ in
            selectedRootCategoryID = filteredRoots.first?.id
            selectedSubcategoryID = nil
            if type != .transfer {
                selectedToAccountID = nil
            }
        }
        .onChange(of: photoItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var typeSlider: some View {
        HStack(spacing: 18) {
            ForEach(TransactionType.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        type = item
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(item.title)
                            .font(.subheadline.weight(type == item ? .semibold : .regular))
                            .foregroundStyle(type == item ? .primary : .secondary)
                        Capsule()
                            .fill(type == item ? Color.accentColor : Color.clear)
                            .frame(height: 3)
                            .frame(maxWidth: 36)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tagsEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                FlowTagLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption.weight(.medium))
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }

            TextField("Тег (Enter или запятая)", text: $tagDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(commitTagDraft)
                .onChange(of: tagDraft) { _, newValue in
                    if newValue.contains(",") {
                        commitTagDraft()
                    }
                }
        }
    }

    private var photoEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preview = attachmentPreview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            attachmentURL = nil
                            attachmentPreview = nil
                            pendingJPEG = nil
                            photoItem = nil
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .red)
                                .padding(8)
                        }
                    }
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(
                    attachmentPreview == nil ? "Прикрепить фото" : "Заменить фото",
                    systemImage: "photo.on.rectangle"
                )
            }
        }
    }

    private var canSave: Bool {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard amount > 0, selectedAccountID != nil else { return false }
        if type == .transfer {
            return selectedToAccountID != nil && selectedToAccountID != selectedAccountID
        }
        return true
    }

    private func commitTagDraft() {
        let pieces = tagDraft
            .split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for piece in pieces where !tags.contains(piece) {
            tags.append(piece)
        }
        tagDraft = ""
    }

    private func load() {
        do {
            accounts = try container.accounts.fetchAll()
            rootCategories = try container.categories.fetchRoots()
            if let transaction {
                amountText = String(format: "%g", transaction.amount)
                type = transaction.type
                date = transaction.date
                note = transaction.note
                tags = transaction.tags
                attachmentURL = transaction.attachmentURL
                attachmentPreview = AttachmentStore.loadImage(from: transaction.attachmentURL)
                pendingJPEG = nil
                selectedAccountID = transaction.account?.id
                selectedToAccountID = transaction.toAccount?.id
                if let category = transaction.category {
                    if let parent = category.parent {
                        selectedRootCategoryID = parent.id
                        selectedSubcategoryID = category.id
                    } else {
                        selectedRootCategoryID = category.id
                        selectedSubcategoryID = nil
                    }
                }
                let remoteURL = transaction.attachmentURL
                Task {
                    if attachmentPreview == nil,
                       let image = await container.loadAttachmentImage(urlString: remoteURL) {
                        attachmentPreview = image
                    }
                }
            } else {
                selectedAccountID = accounts.first?.id
                selectedRootCategoryID = filteredRoots.first?.id
                if let initialJPEG, let image = UIImage(data: initialJPEG) {
                    pendingJPEG = initialJPEG
                    attachmentPreview = image
                    Task { await applyOCR(from: initialJPEG) }
                }
                if let initialNote, note.isEmpty {
                    note = initialNote
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolvedCategory() -> Category? {
        if let subID = selectedSubcategoryID,
           let sub = subcategories.first(where: { $0.id == subID }) {
            return sub
        }
        return selectedRoot
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let jpeg = image.jpegData(compressionQuality: 0.8) {
                pendingJPEG = jpeg
                attachmentPreview = image
                await applyOCR(from: jpeg)
            }
        } catch {
            errorMessage = "Не удалось загрузить фото"
        }
    }

    @MainActor
    private func applyOCR(from jpeg: Data) async {
        let result = await ReceiptOCR.recognize(jpeg: jpeg)
        if amountText.isEmpty, let amount = result.amount, amount > 0 {
            // Always use dot decimals for the amount field — never date-like formatting.
            if abs(amount.rounded() - amount) < 0.001 {
                amountText = String(Int(amount.rounded()))
            } else {
                amountText = String(format: "%.2f", amount)
            }
        }
        if let date = result.date {
            self.date = date
        }
        // Only fill note from OCR merchant text — never from amount/date leftovers.
        if note.isEmpty, let merchant = result.note, !merchant.isEmpty {
            note = merchant
        }
        if let category = BankStatementParser.matchCategory(
            note: note,
            hint: result.note ?? "",
            type: type,
            categories: rootCategories.flatMap { [$0] + $0.children }
        ) {
            if let parent = category.parent {
                selectedRootCategoryID = parent.id
                selectedSubcategoryID = category.id
            } else {
                selectedRootCategoryID = category.id
                selectedSubcategoryID = nil
            }
        }
    }

    private func save() {
        commitTagDraft()
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard let accountID = selectedAccountID,
              let account = accounts.first(where: { $0.id == accountID }) else { return }

        let toAccount = accounts.first(where: { $0.id == selectedToAccountID })
        let category = type == .transfer ? nil : resolvedCategory()
        let tagsValue = tags.joined(separator: ",")

        do {
            let resolvedAttachmentURL: String?
            if let pendingJPEG {
                resolvedAttachmentURL = try AttachmentStore.saveLocalJPEG(pendingJPEG)
            } else if attachmentPreview == nil {
                resolvedAttachmentURL = nil
            } else {
                resolvedAttachmentURL = attachmentURL
            }

            if let transaction {
                transaction.amount = amount
                transaction.type = type
                transaction.date = date
                transaction.note = note
                transaction.tagsCSV = tagsValue
                transaction.attachmentURL = resolvedAttachmentURL
                transaction.account = account
                transaction.toAccount = type == .transfer ? toAccount : nil
                transaction.category = category
                try container.transactions.save(transaction)
            } else {
                let item = Transaction(
                    amount: amount,
                    type: type,
                    date: date,
                    note: note,
                    tagsCSV: tagsValue,
                    account: account,
                    toAccount: type == .transfer ? toAccount : nil,
                    category: category,
                    attachmentURL: resolvedAttachmentURL
                )
                try container.transactions.save(item)
            }
            container.recalculateBudgets()
            container.notifyChange()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Simple wrapping layout for tag chips.
private struct FlowTagLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalHeight = y + rowHeight
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
