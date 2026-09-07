import SwiftUI

struct EmptyStateView<MenuItems: View>: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    private let showsMenu: Bool
    @ViewBuilder var menuItems: () -> MenuItems

    init(
        systemImage: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) where MenuItems == EmptyView {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
        self.showsMenu = false
        self.menuItems = { EmptyView() }
    }

    init(
        systemImage: String,
        title: String,
        subtitle: String,
        actionTitle: String,
        @ViewBuilder menu: @escaping () -> MenuItems
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = nil
        self.showsMenu = true
        self.menuItems = menu
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(subtitle)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(MoneyPrimaryButtonStyle())
                    .frame(maxWidth: 320)
            } else if showsMenu, let actionTitle {
                Menu(content: menuItems) {
                    Text(actionTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MoneyPrimaryButtonStyle())
                .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Close control for sheets: X on iOS 26+, `xmark` on earlier.
struct ModalCloseToolbarItem: ToolbarContent {
    var action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if #available(iOS 26.0, *) {
                Button(role: .close, action: action)
                    .tint(.primary)
            } else {
                Button(action: action) {
                    Image(systemName: "xmark")
                }
                .tint(.primary)
                .accessibilityLabel("Закрыть")
            }
        }
    }
}

/// Confirm control for sheets: checkmark on iOS 26+, `checkmark` on earlier.
struct ModalConfirmToolbarItem: ToolbarContent {
    var isDisabled: Bool = false
    var accessibilityLabel: String = "Сохранить"
    var action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(accessibilityLabel, action: action)
                .fontWeight(.semibold)
                .disabled(isDisabled)
        }
    }
}

struct AmountText: View {
    let amount: Double
    let currencyCode: String
    var isExpense: Bool? = nil

    var body: some View {
        Text(formatted)
            .foregroundStyle(color)
            .fontWeight(.semibold)
            .monospacedDigit()
    }

    private var formatted: String {
        let prefix: String
        if let isExpense {
            prefix = isExpense ? "−" : "+"
        } else {
            prefix = ""
        }
        return prefix + CurrencyFormatter.string(amount: abs(amount), currencyCode: currencyCode)
    }

    private var color: Color {
        guard let isExpense else { return .primary }
        return isExpense ? MoneyPalette.expense : MoneyPalette.income
    }
}

struct IconColorPicker: View {
    @Binding var icon: String
    @Binding var colorHex: String
    let icons: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Иконка")
                .font(.subheadline.weight(.medium))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(icons, id: \.self) { item in
                    Button {
                        icon = item
                    } label: {
                        Image(systemName: item)
                            .frame(width: 44, height: 44)
                            .background(icon == item ? Color(hex: colorHex).opacity(0.25) : Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: MoneyLayout.iconRadius))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Цвет")
                .font(.subheadline.weight(.medium))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                ForEach(IconPalette.colors, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if colorHex == hex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    let currencyCode: String

    var body: some View {
        MoneyTransactionRow(transaction: transaction, currencyCode: currencyCode)
    }
}

struct GlassAddButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .controlSize(.regular)
                .tint(.accentColor)
            } else {
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor, in: Circle())
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

struct GlassMicButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: action) {
                    Image(systemName: "mic.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.regular)
            } else {
                Button(action: action) {
                    Image(systemName: "mic.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct GlassAddFABModifier: ViewModifier {
    var isVisible: Bool = true
    let accessibilityLabel: String
    var micAccessibilityLabel: String = "Голосовой ввод"
    var micAction: (() -> Void)? = nil
    let action: () -> Void

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if isVisible {
                if let micAction {
                    MoneyActionBar(add: action, voice: micAction)
                } else {
                    MoneyCreateBar(title: accessibilityLabel, action: action)
                }
            }
        }
    }
}

private struct GlassAddMenuFABModifier<MenuItems: View>: ViewModifier {
    var isVisible: Bool = true
    let accessibilityLabel: String
    @ViewBuilder let menuItems: () -> MenuItems

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if isVisible {
                MoneyCreateBar(title: accessibilityLabel, menu: menuItems)
            }
        }
    }
}

extension View {
    func glassAddFAB(
        isVisible: Bool = true,
        accessibilityLabel: String,
        micAccessibilityLabel: String = "Голосовой ввод",
        micAction: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) -> some View {
        modifier(GlassAddFABModifier(
            isVisible: isVisible,
            accessibilityLabel: accessibilityLabel,
            micAccessibilityLabel: micAccessibilityLabel,
            micAction: micAction,
            action: action
        ))
    }

    func glassAddFAB<MenuItems: View>(
        isVisible: Bool = true,
        accessibilityLabel: String,
        @ViewBuilder menu: @escaping () -> MenuItems
    ) -> some View {
        modifier(GlassAddMenuFABModifier(
            isVisible: isVisible,
            accessibilityLabel: accessibilityLabel,
            menuItems: menu
        ))
    }

    /// Animates chart values only on app launch / return from background — not on in-app navigation.
    func chartAppearAnimation(_ progress: Binding<Double>) -> some View {
        modifier(ChartAppearAnimationModifier(progress: progress))
    }
}

/// Bumped when the app becomes active from a cold start or background.
@Observable
@MainActor
final class ChartEntranceController {
    private(set) var generation = 0
    private(set) var activeAt = Date.distantPast

    /// Charts that mount shortly after entrance (e.g. after skeleton) may still grow in.
    var isWithinEntranceWindow: Bool {
        Date().timeIntervalSince(activeAt) < 1.75
    }

    func markAppBecameActive() {
        generation += 1
        activeAt = .now
    }
}

private struct ChartAppearAnimationModifier: ViewModifier {
    @Binding var progress: Double
    @Environment(ChartEntranceController.self) private var entrance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastPlayedGeneration = -1

    func body(content: Content) -> some View {
        content
            .onAppear { syncToCurrentGeneration() }
            .onChange(of: entrance.generation) { _, _ in
                playEntrance()
            }
    }

    private func syncToCurrentGeneration() {
        guard lastPlayedGeneration != entrance.generation else { return }
        if entrance.isWithinEntranceWindow {
            playEntrance()
        } else {
            lastPlayedGeneration = entrance.generation
            progress = 1
        }
    }

    private func playEntrance() {
        lastPlayedGeneration = entrance.generation
        if reduceMotion {
            progress = 1
            return
        }
        progress = 0
        withAnimation(.easeOut(duration: 0.9)) {
            progress = 1
        }
    }
}
