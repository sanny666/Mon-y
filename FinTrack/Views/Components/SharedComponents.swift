import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(subtitle)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
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
                    .tint(.red)
            } else {
                Button(action: action) {
                    Image(systemName: "xmark")
                }
                .tint(.red)
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
            if #available(iOS 26.0, *) {
                Button(role: .confirm, action: action)
                    .disabled(isDisabled)
                    .accessibilityLabel(accessibilityLabel)
            } else {
                Button(action: action) {
                    Image(systemName: "checkmark")
                }
                .disabled(isDisabled)
                .accessibilityLabel(accessibilityLabel)
            }
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
        return isExpense ? .red : .green
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
                            .frame(width: 36, height: 36)
                            .background(icon == item ? Color(hex: colorHex).opacity(0.25) : Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(Color(hex: transaction.category?.colorHex ?? "#268F6B"))
                .frame(width: 36, height: 36)
                .background(Color(hex: transaction.category?.colorHex ?? "#268F6B").opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !transaction.tags.isEmpty {
                    Text(transaction.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                AmountText(
                    amount: transaction.amount,
                    currencyCode: currencyCode,
                    isExpense: transaction.type == .expense || transaction.type == .transfer
                )
                if transaction.attachmentURL != nil {
                    Image(systemName: "paperclip")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        if transaction.type == .transfer {
            return "Перевод"
        }
        return transaction.category?.displayName ?? transaction.type.title
    }

    private var subtitle: String {
        var parts: [String] = []
        if let account = transaction.account {
            parts.append(account.name)
        }
        if !transaction.note.isEmpty {
            parts.append(transaction.note)
        }
        return parts.isEmpty ? transaction.date.formatted(date: .abbreviated, time: .omitted) : parts.joined(separator: " · ")
    }

    private var iconName: String {
        switch transaction.type {
        case .income: return transaction.category?.icon ?? "arrow.down.circle.fill"
        case .expense: return transaction.category?.icon ?? "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right"
        }
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

private struct GlassAddFABModifier: ViewModifier {
    var isVisible: Bool = true
    let accessibilityLabel: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottomTrailing) {
            if isVisible {
                GlassAddButton(accessibilityLabel: accessibilityLabel, action: action)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
            }
        }
    }
}

extension View {
    func glassAddFAB(
        isVisible: Bool = true,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        modifier(GlassAddFABModifier(
            isVisible: isVisible,
            accessibilityLabel: accessibilityLabel,
            action: action
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
