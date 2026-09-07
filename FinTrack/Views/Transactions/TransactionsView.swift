import SwiftUI

struct TransactionsView: View {
    @Environment(AppContainer.self) private var container
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
            configuredContent
        }
    }

    private var configuredContent: some View {
        content
            .largeScreenTitle("Транзакции")
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        dismissSearch()
                    }
                }
            }
            .glassAddFAB(isVisible: !isLoading, accessibilityLabel: "Новая транзакция", micAction: {
                showVoiceCapture = true
            }) {
                showAdd = true
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
                VoiceTransactionConfirmView(
                    transcript: draft.transcript,
                    parseResult: draft.parseResult
                )
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

            if isLoading {
                ForEach(0..<7, id: \.self) { _ in
                    SkeletonRow()
                }
            } else if viewModel.transactions.isEmpty {
                EmptyStateView(
                    systemImage: "list.bullet.rectangle",
                    title: "Нет транзакций",
                    subtitle: "Добавьте доход, расход или перевод",
                    actionTitle: "Добавить",
                    action: { showAdd = true }
                )
                .frame(minHeight: 220)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 24, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.groupedByDate, id: \.0) { date, items in
                    Section(date.formatted(date: .abbreviated, time: .omitted)) {
                        ForEach(items, id: \.id) { tx in
                            Button {
                                dismissSearch()
                                editingTransaction = tx
                            } label: {
                                TransactionRowView(
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
        .appGroupedList()
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(
            TapGesture().onEnded { dismissSearch() }
        )
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

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Picker("Период", selection: $viewModel.period) {
                    ForEach(TransactionsViewModel.PeriodFilter.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                Menu {
                    Button("Все счета") { viewModel.selectedAccountID = nil }
                    ForEach(viewModel.accounts, id: \.id) { account in
                        Button(account.name) { viewModel.selectedAccountID = account.id }
                    }
                } label: {
                    filterChip(
                        title: viewModel.accounts.first(where: { $0.id == viewModel.selectedAccountID })?.name ?? "Счёт"
                    )
                }

                Menu {
                    Button("Все категории") { viewModel.categoryFilter = .all }
                    Button("Без категории") { viewModel.categoryFilter = .uncategorized }
                    ForEach(viewModel.categories, id: \.id) { category in
                        Button(category.name) { viewModel.categoryFilter = .category(category.id) }
                    }
                } label: {
                    filterChip(title: viewModel.categoryChipTitle)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(
            TapGesture().onEnded { dismissSearch() }
        )
    }

    private func filterChip(title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }

    private func dismissSearch() {
        isSearchFocused = false
    }

    private func handleVoiceTranscript(_ text: String) {
        do {
            let result = try container.parseVoiceTranscript(text)
            voiceDraft = VoiceTransactionDraft(transcript: text, parseResult: result)
        } catch {
            voiceErrorMessage = error.localizedDescription
        }
    }

    private func reload() {
        viewModel.reload(container: container)
    }
}

extension Transaction: Identifiable {}
