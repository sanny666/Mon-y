import SwiftUI

struct TransactionsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.appAccentColor) private var accentColor
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = TransactionsViewModel()
    @State private var showAdd = false
    @State private var showVoiceCapture = false
    @State private var voiceDraft: VoiceTransactionDraft?
    @State private var voiceErrorMessage: String?
    @State private var editingTransaction: Transaction?
    @State private var isLoading = true
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Транзакции")
                    .font(.largeTitle.bold())
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
                configuredContent
            }
            .background(MoneyPalette.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var configuredContent: some View {
        content
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        dismissSearch()
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isLoading, !isSearchFocused {
                    MoneyActionBar(add: { showAdd = true }, voice: { showVoiceCapture = true })
                }
            }
            .sheet(isPresented: $showAdd) {
                TransactionEditorView(transaction: nil)
            }
            .sheet(isPresented: $showVoiceCapture) {
                VoiceCaptureView { text in
                    handleVoiceTranscript(text)
                }
            }
            .sheet(item: $voiceDraft) { draft in
                VoiceBatchConfirmView(draft: draft)
            }
            .alert("Голосовой ввод", isPresented: Binding(
                get: { voiceErrorMessage != nil },
                set: { if !$0 { voiceErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(voiceErrorMessage ?? "")
            }
            .sheet(item: $editingTransaction) { tx in
                TransactionEditorView(transaction: tx)
            }
            .onAppear { FirstLoad.finish($isLoading, reload) }
            .onChange(of: container.refreshToken) { _, _ in
                guard !isLoading else { return }
                reload()
            }
            .onChange(of: viewModel.searchText) { _, _ in reload() }
            .onChange(of: viewModel.selectedAccountID) { _, _ in
                dismissSearch()
                reload()
            }
            .onChange(of: viewModel.categoryFilter) { _, _ in
                dismissSearch()
                reload()
            }
            .onChange(of: viewModel.period) { _, _ in
                dismissSearch()
                reload()
            }
            .onChange(of: showAdd) { _, isPresented in
                if !isPresented { reload() }
            }
            .onChange(of: editingTransaction) { _, value in
                if value == nil { reload() }
            }
    }

    private var content: some View {
        List {
            searchField
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            filters
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if let error = viewModel.errorMessage {
                MoneyLoadError(message: error, retry: reload)
                    .listRowSeparator(.hidden)
            }

            if isLoading {
                ForEach(0..<7, id: \.self) { _ in
                    SkeletonRow()
                }
            } else if viewModel.errorMessage != nil {
                EmptyView()
            } else if viewModel.transactions.isEmpty {
                EmptyStateView(
                    systemImage: "list.bullet.rectangle",
                    title: hasFilters ? "Ничего не найдено" : "Операций пока нет",
                    subtitle: hasFilters ? "Попробуйте изменить поиск или фильтры" : "Добавьте первый расход, доход или перевод",
                    actionTitle: hasFilters ? "Сбросить фильтры" : "Добавить расход",
                    action: {
                        if hasFilters { resetFilters() } else { showAdd = true }
                    }
                )
                .frame(minHeight: 220)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 24, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.groupedByDate, id: \.0) { date, items in
                    Section(dateTitle(date)) {
                        ForEach(items, id: \.id) { tx in
                            Button {
                                dismissSearch()
                                editingTransaction = tx
                            } label: {
                                MoneyTransactionRow(
                                    transaction: tx,
                                    currencyCode: tx.account?.currency ?? defaultCurrency
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.delete(items[index], container: container)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(MoneyPalette.canvas)
        .contentMargins(.top, 8, for: .scrollContent)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .scrollDismissesKeyboard(.immediately)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Заметка или сумма", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($isSearchFocused)
                .onSubmit { dismissSearch() }
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистить")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
    }

    private var hasFilters: Bool {
        viewModel.period != .all || viewModel.selectedAccountID != nil || viewModel.categoryFilter != .all || !viewModel.searchText.isEmpty
    }

    private func resetFilters() {
        dismissSearch()
        viewModel.searchText = ""
        viewModel.period = .all
        viewModel.selectedAccountID = nil
        viewModel.categoryFilter = .all
    }

    private func dateTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Сегодня" }
        if Calendar.current.isDateInYesterday(date) { return "Вчера" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            MoneyPeriodPicker(title: "Период", values: TransactionsViewModel.PeriodFilter.allCases,
                              selection: $viewModel.period, label: { $0.title })

            MoneyFlowLayout {
                Menu {
                    Button("Все счета") { viewModel.selectedAccountID = nil }
                    ForEach(viewModel.accounts, id: \.id) { account in
                        Button(account.name) { viewModel.selectedAccountID = account.id }
                    }
                } label: {
                    filterChip(title: viewModel.accounts.first(where: { $0.id == viewModel.selectedAccountID })?.name ?? "Счёт",
                               icon: "creditcard", active: viewModel.selectedAccountID != nil)
                }
                .accessibilityLabel("Фильтр по счёту")
                .accessibilityValue(viewModel.accounts.first(where: { $0.id == viewModel.selectedAccountID })?.name ?? "Все счета")

                Menu {
                    Button("Все категории") { viewModel.categoryFilter = .all }
                    Button("Без категории") { viewModel.categoryFilter = .uncategorized }
                    ForEach(viewModel.categories, id: \.id) { category in
                        Button(category.name) { viewModel.categoryFilter = .category(category.id) }
                    }
                } label: {
                    filterChip(title: viewModel.categoryChipTitle, icon: "square.grid.2x2", active: viewModel.categoryFilter != .all)
                }
                .accessibilityLabel("Фильтр по категории")
                .accessibilityValue(viewModel.categoryFilter == .all ? "Все категории" : viewModel.categoryChipTitle)

                if hasFilters {
                    Button("Сбросить", action: resetFilters)
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 44)
                        .padding(.horizontal, 8)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func filterChip(title: String, icon: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
        }
        .font(.subheadline.weight(active ? .semibold : .regular))
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(active ? accentColor.opacity(0.16) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(active ? accentColor.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private func dismissSearch() {
        isSearchFocused = false
    }

    private func handleVoiceTranscript(_ text: String) {
        do {
            let results = try container.parseVoiceTranscripts(text)
            voiceDraft = VoiceTransactionDraft(
                transcript: text,
                items: results.map { VoiceDraftItem(parseResult: $0) }
            )
        } catch {
            voiceErrorMessage = error.localizedDescription
        }
    }

    private func reload() {
        viewModel.reload(container: container)
    }
}

extension Transaction: Identifiable {}
