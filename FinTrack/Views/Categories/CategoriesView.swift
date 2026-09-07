import SwiftUI

struct CategoriesView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel = CategoriesViewModel()
    @State private var showAddRoot = false
    @State private var editing: Category?
    @State private var parentForNewSubcategory: Category?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ListSkeleton(rows: 8, kind: .category)
            } else if viewModel.categories.isEmpty {
                EmptyStateView(
                    systemImage: "tag",
                    title: "Нет категорий",
                    subtitle: "Добавьте категории доходов и расходов",
                    actionTitle: "Добавить",
                    action: { showAddRoot = true }
                )
            } else {
                List {
                    Section("Доходы") {
                        rootRows(viewModel.incomeRoots)
                    }
                    Section("Расходы") {
                        rootRows(viewModel.expenseRoots)
                    }
                }
                .appGroupedList()
            }
        }
        .background(MoneyPalette.canvas)
        .navigationTitle("Категории")
        .toolbarTitleDisplayMode(.large)
        .glassAddFAB(isVisible: !isLoading, accessibilityLabel: "Новая категория") {
            showAddRoot = true
        }
        .sheet(isPresented: $showAddRoot) {
            NavigationStack {
                CategoryEditorView(category: nil, parent: nil)
            }
        }
        .sheet(item: $editing) { category in
            NavigationStack {
                CategoryEditorView(category: category, parent: category.parent)
            }
        }
        .sheet(item: $parentForNewSubcategory) { parent in
            NavigationStack {
                CategoryEditorView(category: nil, parent: parent)
            }
        }
        .onAppear {
            container.dedupeCategoriesIfNeeded()
            FirstLoad.finish($isLoading) { viewModel.reload(container: container) }
        }
        .onChange(of: container.refreshToken) { _, _ in
            guard !isLoading else { return }
            viewModel.reload(container: container)
        }
        .onChange(of: showAddRoot) { _, isPresented in
            if !isPresented { viewModel.reload(container: container) }
        }
        .onChange(of: editing) { _, value in
            if value == nil { viewModel.reload(container: container) }
        }
        .onChange(of: parentForNewSubcategory) { _, value in
            if value == nil { viewModel.reload(container: container) }
        }
    }

    @ViewBuilder
    private func rootRows(_ items: [Category]) -> some View {
        if items.isEmpty {
            Text("Пусто")
                .foregroundStyle(.secondary)
        } else {
            ForEach(items, id: \.id) { category in
                DisclosureGroup {
                    let children = category.children
                        .filter { !$0.isDeleted }
                        .sorted {
                            $0.name.localizedCompare($1.name) == .orderedAscending
                        }
                    ForEach(children, id: \.id) { child in
                        Button {
                            editing = child
                        } label: {
                            HStack {
                                MoneyCategoryIcon(icon: child.icon, color: Color(hex: child.colorHex))
                                Text(child.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.delete(child, container: container)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        parentForNewSubcategory = category
                    } label: {
                        Label("Добавить подкатегорию", systemImage: "plus.circle")
                    }
                } label: {
                    Button {
                        editing = category
                    } label: {
                        HStack {
                            MoneyCategoryIcon(icon: category.icon, color: Color(hex: category.colorHex))
                            Text(category.name)
                                .foregroundStyle(.primary)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(category.children.filter { !$0.isDeleted }.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.delete(category, container: container)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
    }
}

extension Category: Identifiable {}

struct CategoryEditorView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let category: Category?
    let parent: Category?

    @State private var name = ""
    @State private var type: CategoryType = .expense
    @State private var icon = "cart.fill"
    @State private var colorHex = "#C45C26"
    @State private var errorMessage: String?

    private var isSubcategoryEditor: Bool {
        parent != nil || category?.isSubcategory == true
    }

    private var resolvedParent: Category? {
        parent ?? category?.parent
    }

    var body: some View {
        Form {
            if let resolvedParent {
                Section {
                    LabeledContent("Родитель", value: resolvedParent.name)
                }
            }

            Section {
                TextField("Название", text: $name)
                if !isSubcategoryEditor {
                    Picker("Тип", selection: $type) {
                        ForEach(CategoryType.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            Section {
                IconColorPicker(icon: $icon, colorHex: $colorHex, icons: IconPalette.categoryIcons)
            }
        }
        .appGroupedList()
        .background(MoneyPalette.canvas)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ModalCloseToolbarItem { dismiss() }
            ModalConfirmToolbarItem(isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty) {
                save()
            }
        }
        .onAppear {
            if let category {
                name = category.name
                type = category.type
                icon = category.icon
                colorHex = category.colorHex
            } else if let resolvedParent {
                type = resolvedParent.type
                colorHex = resolvedParent.colorHex
                icon = resolvedParent.icon
            }
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

    private var navigationTitle: String {
        if category != nil {
            return isSubcategoryEditor ? "Подкатегория" : "Категория"
        }
        return isSubcategoryEditor ? "Новая подкатегория" : "Новая категория"
    }

    private func save() {
        do {
            if let category {
                category.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !isSubcategoryEditor {
                    category.type = type
                    for child in category.children {
                        child.type = type
                        child.colorHex = colorHex
                    }
                } else if let resolvedParent {
                    category.type = resolvedParent.type
                }
                category.icon = icon
                category.colorHex = colorHex
                try container.categories.save(category)
            } else {
                let parentCategory = resolvedParent
                let item = Category(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    icon: icon,
                    colorHex: colorHex,
                    type: parentCategory?.type ?? type,
                    parent: parentCategory
                )
                try container.categories.save(item)
            }
            container.notifyChange()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
