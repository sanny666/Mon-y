import SwiftUI
import UniformTypeIdentifiers

struct BankImportView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue

    @State private var accounts: [Account] = []
    @State private var categories: [Category] = []
    @State private var selectedAccountID: UUID?
    @State private var showFilePicker = false
    @State private var isParsing = false
    @State private var isImporting = false
    @State private var parseError: String?
    @State private var sourceName: String?
    @State private var drafts: [ImportDraft] = []
    @State private var resultMessage: String?

    private var selectedAccount: Account? {
        accounts.first(where: { $0.id == selectedAccountID })
    }

    private var selectedCount: Int {
        drafts.filter(\.isSelected).count
    }

    private var otherAccounts: [Account] {
        accounts.filter { $0.id != selectedAccountID }
    }

    var body: some View {
        Group {
            if accounts.isEmpty {
                EmptyStateView(
                    systemImage: "creditcard",
                    title: "Сначала нужен счёт",
                    subtitle: "Импорт записывает операции на выбранный счёт"
                )
            } else {
                List {
                    Section {
                        Picker("Счёт", selection: $selectedAccountID) {
                            ForEach(accounts, id: \.id) { account in
                                Text(account.name).tag(Optional(account.id))
                            }
                        }
                        Button {
                            showFilePicker = true
                        } label: {
                            Label("Выбрать выписку", systemImage: "doc.badge.arrow.up")
                        }
                    } footer: {
                        Text("CSV, Excel (XLSX), PDF с текстом или HTML-таблица (.xls от банка). Kaspi, Halyk, Forte, Jusan и другие. Бинарный старый .xls — сохраните как CSV/XLSX.")
                    }

                    if isParsing {
                        Section {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Читаю выписку…")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if !drafts.isEmpty {
                        Section {
                            HStack {
                                Text(sourceName ?? "Банк")
                                Spacer()
                                Text("\(drafts.count)")
                                    .foregroundStyle(.secondary)
                            }
                            let duplicates = drafts.filter(\.isDuplicate).count
                            if duplicates > 0 {
                                Text("\(duplicates) уже есть в monёy — сниму галочки")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Button(selectedCount == drafts.filter { !$0.isDuplicate }.count && selectedCount > 0 ? "Снять все" : "Выбрать все") {
                                let select = selectedCount != drafts.filter { !$0.isDuplicate }.count
                                for index in drafts.indices {
                                    drafts[index].isSelected = select && !drafts[index].isDuplicate
                                }
                            }
                        } header: {
                            Text("Операции")
                        }

                        Section {
                            ForEach($drafts) { $draft in
                                draftRow($draft)
                            }
                        }
                    }
                }
                .appGroupedList()
            }
        }
        .navigationTitle("Импорт из банка")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Импорт") {
                    importSelected()
                }
                .disabled(selectedCount == 0 || isImporting || selectedAccount == nil || hasInvalidTransfers)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: Self.allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            handlePickedFile(result)
        }
        .alert(
            "Не получилось",
            isPresented: Binding(
                get: { parseError != nil },
                set: { if !$0 { parseError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(parseError ?? "")
        }
        .alert(
            "Готово",
            isPresented: Binding(
                get: { resultMessage != nil },
                set: { if !$0 { resultMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
        .onAppear(perform: reload)
        .onChange(of: container.refreshToken) { _, _ in reload() }
        .onChange(of: selectedAccountID) { _, _ in
            clearInvalidTransferTargets()
            refreshDuplicates()
        }
    }

    private var hasInvalidTransfers: Bool {
        drafts.contains {
            $0.isSelected && !$0.isDuplicate && $0.type == .transfer && $0.toAccountID == nil
        }
    }

    private func draftRow(_ draft: Binding<ImportDraft>) -> some View {
        let item = draft.wrappedValue
        let currency = selectedAccount?.currency ?? defaultCurrency
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Toggle(isOn: draft.isSelected) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.note.isEmpty ? item.type.title : item.note)
                            .font(.body.weight(.medium))
                            .lineLimit(2)
                        Text(item.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(item.isDuplicate)
                AmountText(
                    amount: item.amount,
                    currencyCode: currency,
                    isExpense: item.type != .income
                )
            }
            HStack {
                Menu {
                    Button("Расход") { setType(draft, .expense) }
                    Button("Доход") { setType(draft, .income) }
                    Button("Перевод") { setType(draft, .transfer) }
                } label: {
                    Text(item.type.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(typeColor(item.type))
                }

                if item.type == .transfer {
                    Menu {
                        ForEach(otherAccounts, id: \.id) { account in
                            Button(account.name) {
                                draft.toAccountID.wrappedValue = account.id
                            }
                        }
                    } label: {
                        Label(
                            toAccountTitle(item),
                            systemImage: "arrow.left.arrow.right"
                        )
                        .font(.caption)
                    }
                } else {
                    Menu {
                        Button("Без категории") { draft.categoryID.wrappedValue = nil }
                        ForEach(categories(for: item.type), id: \.id) { category in
                            Button(category.displayName) {
                                draft.categoryID.wrappedValue = category.id
                            }
                        }
                    } label: {
                        Label(
                            categoryTitle(item),
                            systemImage: "tag"
                        )
                        .font(.caption)
                    }
                }

                if item.isDuplicate {
                    Text("уже есть")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func typeColor(_ type: TransactionType) -> Color {
        switch type {
        case .income: return .green
        case .expense: return Color.red.opacity(0.85)
        case .transfer: return .blue.opacity(0.9)
        }
    }

    private func categories(for type: TransactionType) -> [Category] {
        let needed: CategoryType = type == .income ? .income : .expense
        return categories
            .filter { $0.type == needed }
            .sorted {
                $0.displayName.localizedCompare($1.displayName) == .orderedAscending
            }
    }

    private func categoryTitle(_ item: ImportDraft) -> String {
        if let id = item.categoryID,
           let category = categories.first(where: { $0.id == id }) {
            return category.displayName
        }
        return "Категория"
    }

    private func toAccountTitle(_ item: ImportDraft) -> String {
        if let id = item.toAccountID,
           let account = accounts.first(where: { $0.id == id }) {
            return account.name
        }
        return "Куда"
    }

    private func setType(_ draft: Binding<ImportDraft>, _ type: TransactionType) {
        draft.type.wrappedValue = type
        if type == .transfer {
            draft.categoryID.wrappedValue = nil
            if draft.toAccountID.wrappedValue == nil {
                draft.toAccountID.wrappedValue = otherAccounts.first?.id
            }
            return
        }
        draft.toAccountID.wrappedValue = nil
        if let id = draft.categoryID.wrappedValue,
           let category = categories.first(where: { $0.id == id }) {
            let needed: CategoryType = type == .income ? .income : .expense
            if category.type != needed {
                draft.categoryID.wrappedValue = nil
            }
        }
        if draft.categoryID.wrappedValue == nil {
            draft.categoryID.wrappedValue = BankStatementParser.matchCategory(
                note: draft.wrappedValue.note,
                hint: "",
                type: type,
                categories: categories
            )?.id
        }
    }

    private func clearInvalidTransferTargets() {
        for index in drafts.indices where drafts[index].type == .transfer {
            if drafts[index].toAccountID == selectedAccountID {
                drafts[index].toAccountID = otherAccounts.first?.id
            }
            if drafts[index].toAccountID == nil {
                drafts[index].toAccountID = otherAccounts.first?.id
            }
        }
    }

    private func reload() {
        accounts = (try? container.accounts.fetchAll()) ?? []
        categories = (try? container.categories.fetchAll()) ?? []
        if selectedAccountID == nil {
            selectedAccountID = accounts.first?.id
        }
        clearInvalidTransferTargets()
        refreshDuplicates()
    }

    private func refreshDuplicates() {
        guard let accountID = selectedAccountID else { return }
        let existing = ((try? container.transactions.fetch(accountID: accountID)) ?? [])
            .filter { !$0.isDeleted }
        let fingerprints = Set(existing.map {
            BankStatementParser.fingerprint(date: $0.date, amount: $0.amount, note: $0.note)
        })
        for index in drafts.indices {
            let key = BankStatementParser.fingerprint(
                date: drafts[index].date,
                amount: drafts[index].amount,
                note: drafts[index].note
            )
            let duplicate = fingerprints.contains(key)
            drafts[index].isDuplicate = duplicate
            if duplicate {
                drafts[index].isSelected = false
            }
        }
    }

    private func handlePickedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            parseError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            parseFile(url)
        }
    }

    private func parseFile(_ url: URL) {
        isParsing = true
        parseError = nil
        Task {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent
                let parsed = try BankStatementParser.parse(data: data, filename: filename)
                let cats = categories
                let defaultTo = otherAccounts.first?.id
                let mapped = parsed.rows.map { row in
                    let category = BankStatementParser.matchCategory(
                        note: row.note,
                        hint: row.categoryHint,
                        type: row.type,
                        categories: cats
                    )
                    return ImportDraft(
                        date: row.date,
                        amount: row.amount,
                        type: row.type,
                        note: row.note,
                        categoryID: row.type == .transfer ? nil : category?.id,
                        toAccountID: row.type == .transfer ? defaultTo : nil,
                        tags: row.tags,
                        isSelected: true,
                        isDuplicate: false
                    )
                }
                drafts = mapped.sorted { $0.date > $1.date }
                sourceName = parsed.sourceName
                refreshDuplicates()
            } catch {
                parseError = error.localizedDescription
            }
            isParsing = false
        }
    }

    private func importSelected() {
        guard let account = selectedAccount else { return }
        if hasInvalidTransfers {
            parseError = "Для переводов выберите счёт назначения. Нужен хотя бы ещё один счёт."
            return
        }
        isImporting = true
        var imported = 0
        var skipped = 0
        for draft in drafts where draft.isSelected {
            if draft.isDuplicate {
                skipped += 1
                continue
            }
            let category = draft.type == .transfer
                ? nil
                : draft.categoryID.flatMap { id in categories.first(where: { $0.id == id }) }
            let toAccount = draft.type == .transfer
                ? draft.toAccountID.flatMap { id in accounts.first(where: { $0.id == id }) }
                : nil
            var tags = draft.tags
            if let sourceName, !tags.contains(where: { $0.caseInsensitiveCompare(sourceName) == .orderedSame }) {
                tags.append(sourceName)
            }
            let tx = Transaction(
                amount: draft.amount,
                type: draft.type,
                date: draft.date,
                note: draft.note,
                tagsCSV: tags.joined(separator: ","),
                account: account,
                toAccount: toAccount,
                category: category
            )
            do {
                try container.transactions.save(tx)
                imported += 1
            } catch {
                parseError = error.localizedDescription
                isImporting = false
                return
            }
        }
        container.recalculateBudgets()
        container.notifyChange()
        isImporting = false
        drafts = []
        sourceName = nil
        let skippedText = skipped == 0 ? "" : ", пропущено дублей: \(skipped)"
        resultMessage = "Импортировано \(imported)\(skippedText)."
    }

    private static var allowedTypes: [UTType] {
        var types: [UTType] = [.commaSeparatedText, .tabSeparatedText, .plainText, .pdf, .html]
        if let xlsx = UTType(filenameExtension: "xlsx") { types.append(xlsx) }
        if let csv = UTType(filenameExtension: "csv") { types.append(csv) }
        if let xls = UTType(filenameExtension: "xls") { types.append(xls) }
        if let tsv = UTType(filenameExtension: "tsv") { types.append(tsv) }
        types.append(.data)
        return types
    }
}

private struct ImportDraft: Identifiable {
    let id = UUID()
    var date: Date
    var amount: Double
    var type: TransactionType
    var note: String
    var categoryID: UUID?
    var toAccountID: UUID?
    var tags: [String]
    var isSelected: Bool
    var isDuplicate: Bool
}
