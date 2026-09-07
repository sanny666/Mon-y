import PhotosUI
import SwiftUI
import UIKit

struct TransactionEditorView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.appAccentColor) private var accentColor
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction?
    var initialJPEG: Data? = nil
    var initialNote: String? = nil
    var fromSharedInbox: Bool = false

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
    @State private var showPhotoPicker = false
    @State private var showReceiptPreview = false
    @State private var didLoad = false
    @State private var selectedAccountID: UUID?
    @State private var selectedToAccountID: UUID?
    @State private var selectedRootCategoryID: UUID?
    @State private var selectedSubcategoryID: UUID?
    @State private var accounts: [Account] = []
    @State private var rootCategories: [Category] = []
    @State private var errorMessage: String?
    @State private var showVoiceCapture = false
    @State private var voiceDictionaryItemName: String?
    @State private var voiceMatchHint: String?
    @State private var suppressTypeCategoryReset = false
    @State private var showCategoryPicker = false
    @State private var showAccountEditor = false
    @State private var showAdditional = false
    @State private var loadError: String?
    @State private var pendingTransaction: Transaction?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case amount, note, tag }

    private var currencyCode: String {
        accounts.first(where: { $0.id == selectedAccountID })?.currency ?? AppCurrency.kzt.rawValue
    }

    private var filteredRoots: [Category] {
        guard type != .transfer else { return [] }
        let needed: CategoryType = type == .income ? .income : .expense
        return rootCategories.filter { $0.type == needed }
    }

    private var selectedRoot: Category? {
        filteredRoots.first(where: { $0.id == selectedRootCategoryID })
    }

    private var subcategories: [Category] {
        (selectedRoot?.children ?? [])
            .filter { !$0.isDeleted }
            .sorted {
                $0.name.localizedCompare($1.name) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    typeSlider

                    if let loadError {
                        MoneyCard { MoneyLoadError(message: loadError, retry: load) }
                    }

                    MoneyCard(tinted: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Сумма · \(currencyCode)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            TextField("0", text: $amountText, axis: .vertical)
                                .keyboardType(.decimalPad)
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .focused($focusedField, equals: .amount)
                                .accessibilityLabel("Сумма в \(currencyCode)")
                        }
                    }

                    accountSection

                    if type != .transfer {
                        MoneyCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    focusedField = nil
                                    showCategoryPicker = true
                                } label: {
                                    HStack(spacing: 12) {
                                        MoneyCategoryIcon(icon: resolvedCategory()?.icon ?? "square.grid.2x2",
                                                          color: Color(hex: resolvedCategory()?.colorHex ?? AppAccent.defaultHex))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Категория").font(.caption).foregroundStyle(.secondary)
                                            Text(resolvedCategory()?.displayName ?? "Без категории")
                                                .font(.body.weight(.medium)).foregroundStyle(.primary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider()
                                TextField("На что? Необязательно", text: $note, axis: .vertical)
                                    .lineLimit(1...4)
                                    .focused($focusedField, equals: .note)
                                    .frame(minHeight: 44)
                                if let voiceMatchHint {
                                    Text(voiceMatchHint).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    MoneyCard {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Дата").font(.headline)
                                DatePicker("Дата", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                DatePicker("Время", selection: $date, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        } else {
                            DatePicker("Дата", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                        }
                    }

                    MoneyCard {
                        DisclosureGroup(isExpanded: $showAdditional) {
                            VStack(alignment: .leading, spacing: 20) {
                                tagsEditor
                                photoEditor
                            }
                            .padding(.top, 16)
                        } label: {
                            Label("Дополнительно", systemImage: "slider.horizontal.3")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                                .frame(minHeight: 44)
                        }
                        .tint(.primary)
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(MoneyPalette.canvas)
            .navigationTitle(transaction == nil ? "Новая операция" : "Изменить операцию")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                saveBar
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть", systemImage: "xmark") { closeEditor() }
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Голосовой ввод", systemImage: "mic.fill") {
                        focusedField = nil
                        showVoiceCapture = true
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .sheet(isPresented: $showCategoryPicker) { categoryPicker }
        .sheet(isPresented: $showAccountEditor, onDismiss: reloadAccounts) {
            NavigationStack { AccountEditorView(account: nil) }
        }
        .onChange(of: tags) { _, value in
            if !value.isEmpty { showAdditional = true }
        }
        .onChange(of: attachmentURL) { _, value in
            if value != nil { showAdditional = true }
        }
        .onChange(of: pendingJPEG) { _, value in
            if value != nil { showAdditional = true }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            load()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .overlay {
            if showReceiptPreview, let preview = attachmentPreview {
                ReceiptImagePreview(image: preview) {
                    showReceiptPreview = false
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .onChange(of: type) { _, _ in
            guard !suppressTypeCategoryReset else { return }
            // Keep free-form purchases: don't force a category on type switch.
            if type == .transfer {
                selectedRootCategoryID = nil
                selectedSubcategoryID = nil
            } else if let rootID = selectedRootCategoryID,
                      !filteredRoots.contains(where: { $0.id == rootID }) {
                selectedRootCategoryID = nil
                selectedSubcategoryID = nil
            } else {
                selectedSubcategoryID = nil
            }
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
        .sheet(isPresented: $showVoiceCapture) {
            VoiceCaptureView { text in
                Task { await applyVoice(from: text) }
            }
        }
    }

    private var typeSlider: some View {
        MoneyPeriodPicker(title: "Тип операции", values: [TransactionType.expense, .income, .transfer],
                          selection: $type, label: { $0.title })
    }

    private var accountSection: some View {
        MoneyCard {
            VStack(alignment: .leading, spacing: 12) {
                if accounts.isEmpty {
                    Text("Добавьте счёт для первой операции")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button { showAccountEditor = true } label: {
                        Label("Создать счёт", systemImage: "plus.circle.fill").frame(minHeight: 44)
                    }
                } else {
                    accountPicker(title: "Счёт", selection: $selectedAccountID, choices: accounts)
                    if type == .transfer {
                        Divider()
                        accountPicker(title: "Куда", selection: $selectedToAccountID,
                                      choices: accounts.filter { $0.id != selectedAccountID })
                        if accounts.count < 2 {
                            Button("Создать второй счёт") { showAccountEditor = true }.frame(minHeight: 44)
                        }
                    }
                }
            }
        }
    }

    private func accountPicker(title: String, selection: Binding<UUID?>, choices: [Account]) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(title).font(.body).foregroundStyle(.secondary)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Picker(title, selection: selection) {
                Text("Выберите").tag(Optional<UUID>.none)
                ForEach(choices, id: \.id) { account in
                    Text(account.name).tag(Optional(account.id))
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    private var saveBar: some View {
        VStack(spacing: 8) {
            if !canSave, !amountText.isEmpty {
                Text(saveHint).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            }
            HStack(spacing: 8) {
                Button(action: save) {
                    Text("Сохранить")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 48)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.primary)
                        .background(accentColor.opacity(canSave ? MoneyLayout.accentPillFill : MoneyLayout.accentPillFillDisabled), in: Capsule())
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
                if focusedField != nil {
                    Button { focusedField = nil } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.title3.weight(.semibold))
                            .frame(width: 52, height: 48)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Скрыть клавиатуру")
                }
            }
            .buttonStyle(.plain)
            .padding(6)
            .moneyGlassCapsule()
            .frame(maxWidth: 340)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }

    private var saveHint: String {
        if loadError != nil { return "Повторите загрузку данных" }
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")), amount.isFinite, amount > 0 else {
            return "Введите сумму больше нуля"
        }
        if selectedAccountID == nil { return "Выберите счёт" }
        return "Выберите другой счёт для перевода"
    }

    private var categoryPicker: some View {
        NavigationStack {
            List {
                categoryChoice(nil, title: "Без категории")
                ForEach(filteredRoots, id: \.id) { root in
                    Section {
                        categoryChoice(root, title: root.name)
                        ForEach(root.children.filter { !$0.isDeleted }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }, id: \.id) { child in
                            categoryChoice(child, title: child.name)
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Категория")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { showCategoryPicker = false }
                }
            }
        }
    }

    private func categoryChoice(_ category: Category?, title: String) -> some View {
        Button {
            if let category {
                applyCategoryID(category.id)
            } else {
                selectedRootCategoryID = nil
                selectedSubcategoryID = nil
            }
            showCategoryPicker = false
        } label: {
            HStack(spacing: 12) {
                MoneyCategoryIcon(icon: category?.icon ?? "square.grid.2x2",
                                  color: Color(hex: category?.colorHex ?? AppAccent.defaultHex))
                Text(title).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if resolvedCategory()?.id == category?.id {
                    Image(systemName: "checkmark").font(.body.weight(.semibold))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(resolvedCategory()?.id == category?.id ? .isSelected : [])
    }

    private func reloadAccounts() {
        do {
            accounts = try container.accounts.fetchAll()
            if !accounts.contains(where: { $0.id == selectedAccountID }) {
                selectedAccountID = DefaultAccountResolver.resolvedID(from: accounts)
            }
        } catch {
            errorMessage = error.localizedDescription
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
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }

            TextField("Тег (Enter или запятая)", text: $tagDraft)
                .focused($focusedField, equals: .tag)
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
                ZStack(alignment: .topTrailing) {
                    Button {
                        showReceiptPreview = true
                    } label: {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        removeAttachment()
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                showPhotoPicker = true
            } label: {
                Label(
                    attachmentPreview == nil ? "Прикрепить фото" : "Заменить фото",
                    systemImage: "photo.on.rectangle"
                )
            }
        }
    }

    private var canSave: Bool {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard loadError == nil, amount.isFinite, amount > 0, accounts.contains(where: { $0.id == selectedAccountID }) else { return false }
        if type == .transfer {
            return accounts.contains(where: { $0.id == selectedToAccountID }) && selectedToAccountID != selectedAccountID
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
            loadError = nil
            if let transaction {
                suppressTypeCategoryReset = true
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
                Task { @MainActor in suppressTypeCategoryReset = false }
                let remoteURL = transaction.attachmentURL
                Task {
                    if attachmentPreview == nil,
                       let image = await container.loadAttachmentImage(urlString: remoteURL),
                       attachmentURL == remoteURL, pendingJPEG == nil {
                        attachmentPreview = image
                    }
                }
            } else {
                selectedAccountID = DefaultAccountResolver.resolvedID(from: accounts)
                selectedRootCategoryID = nil
                selectedSubcategoryID = nil
                if let initialJPEG, let image = UIImage(data: initialJPEG) {
                    attachmentPreview = image
                    if let savedURL = try? AttachmentStore.saveLocalJPEG(initialJPEG) {
                        attachmentURL = savedURL
                        pendingJPEG = nil
                    } else {
                        pendingJPEG = initialJPEG
                    }
                    Task { await applyOCR(from: initialJPEG) }
                }
                if let initialNote, note.isEmpty {
                    note = initialNote
                }
            }
            showAdditional = !tags.isEmpty || attachmentURL != nil || pendingJPEG != nil
        } catch {
            loadError = error.localizedDescription
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
                if let savedURL = try? AttachmentStore.saveLocalJPEG(jpeg) {
                    attachmentURL = savedURL
                    pendingJPEG = nil
                } else {
                    pendingJPEG = jpeg
                }
                attachmentPreview = image
                photoItem = nil
                await applyOCR(from: jpeg)
            }
        } catch {
            errorMessage = "Не удалось загрузить фото"
        }
    }

    private func removeAttachment() {
        if fromSharedInbox {
            ReceiptInbox.clear()
        }
        attachmentURL = nil
        attachmentPreview = nil
        pendingJPEG = nil
        photoItem = nil
        showReceiptPreview = false
    }

    private func closeEditor() {
        if fromSharedInbox {
            ReceiptInbox.clear()
        }
        dismiss()
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

    @MainActor
    private func applyVoice(from text: String) async {
        do {
            let result = try container.parseVoiceTranscript(text)
            suppressTypeCategoryReset = true

            type = result.type
            date = result.date

            if let amount = result.amount, amount > 0 {
                if abs(amount.rounded() - amount) < 0.001 {
                    amountText = String(Int(amount.rounded()))
                } else {
                    amountText = String(format: "%.2f", amount)
                }
            }

            if !result.itemName.isEmpty {
                note = result.itemName
                voiceDictionaryItemName = result.itemName
            }

            voiceMatchHint = result.matchHint

            if let accountID = result.accountID {
                selectedAccountID = accountID
            }
            if let toAccountID = result.toAccountID {
                selectedToAccountID = toAccountID
            }

            if let categoryID = result.matchedCategoryID {
                applyCategoryID(categoryID)
            }

            Task { @MainActor in
                suppressTypeCategoryReset = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyCategoryID(_ categoryID: UUID) {
        for root in rootCategories {
            if root.id == categoryID {
                selectedRootCategoryID = root.id
                selectedSubcategoryID = nil
                return
            }
            if let child = root.children.first(where: { $0.id == categoryID }) {
                selectedRootCategoryID = root.id
                selectedSubcategoryID = child.id
                return
            }
        }
    }

    private func save() {
        guard canSave else { return }
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
            } else {
                resolvedAttachmentURL = attachmentURL
            }

            if let transaction = transaction ?? pendingTransaction {
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
                // Reuse this draft after a failed save; a repository may have already inserted it.
                pendingTransaction = item
                try container.transactions.save(item)
            }

            if type != .transfer,
               let category,
               let dictionaryName = voiceDictionaryItemName ?? (note.isEmpty ? nil : note.trimmingCharacters(in: .whitespacesAndNewlines)),
               !dictionaryName.isEmpty {
                try? container.itemDictionary.upsert(name: dictionaryName, category: category)
            }

            container.recalculateBudgets()
            container.notifyChange()
            if fromSharedInbox {
                ReceiptInbox.clear()
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
