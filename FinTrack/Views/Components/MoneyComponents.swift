import SwiftUI

enum MoneyPalette {
    static let canvas = Color(uiColor: UIColor { traits in
        UIColor(Color(hex: traits.userInterfaceStyle == .dark ? "#101010" : "#F3F4F7"))
    })
    static let income = Color(uiColor: UIColor { traits in
        UIColor(Color(hex: traits.userInterfaceStyle == .dark ? "#65D6AB" : "#147856"))
    })
    static let expense = Color(uiColor: UIColor { traits in
        UIColor(Color(hex: traits.userInterfaceStyle == .dark ? "#FF998D" : "#B74235"))
    })
}

enum MoneyLayout {
    static let pageInset: CGFloat = 20
    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 18
    static let iconRadius: CGFloat = 12
    static let contentWidth: CGFloat = 760
    /// Accent fill on floating CTA pills (readable on glass).
    static let accentPillFill: Double = 0.34
    static let accentPillFillDisabled: Double = 0.12
}

/// Shared surface for cards, onboarding, and legacy dashboard containers.
struct MoneyCardSurface: View {
    var cornerRadius: CGFloat = MoneyLayout.cardRadius
    var tinted = false
    @Environment(\.appAccentColor) private var accentColor
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay {
                if tinted {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient(
                            colors: [accentColor.opacity(colorScheme == .dark ? 0.20 : 0.14), .clear],
                            startPoint: .topTrailing, endPoint: .bottomLeading
                        ))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
            }
    }
}

/// The same card language across all money flows.
struct MoneyCard<Content: View>: View {
    var tinted = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MoneyLayout.pageInset)
            .background { MoneyCardSurface(tinted: tinted) }
    }
}

struct MoneyDashboardSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MoneyCard {
                    VStack(alignment: .leading, spacing: 20) {
                        SkeletonBar(width: 120, height: 16)
                        SkeletonBar(width: 200, height: 40)
                        SkeletonBar(width: 140, height: 16)
                    }
                }
                MoneyCard {
                    VStack(spacing: 20) {
                        SkeletonBar(height: 32)
                        HStack(spacing: 24) { SkeletonBar(height: 40); SkeletonBar(height: 40) }
                    }
                }
                MoneyCard {
                    VStack(spacing: 16) {
                        SkeletonRow()
                        SkeletonRow()
                        SkeletonRow()
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .scrollDisabled(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Загрузка")
    }
}

/// Shared glass capsule chrome for floating action bars (home, lists, editor).
private struct MoneyGlassCapsuleModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var isInteractive = false

    func body(content: Content) -> some View {
        Group {
            if reduceTransparency {
                content.background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
            } else if #available(iOS 26.0, *) {
                content.glassEffect(isInteractive ? .regular.interactive() : .regular, in: .capsule)
            } else {
                content.background(.regularMaterial, in: Capsule())
            }
        }
    }
}

extension View {
    func moneyGlassCapsule(interactive: Bool = false) -> some View {
        modifier(MoneyGlassCapsuleModifier(isInteractive: interactive))
    }
}

struct MoneyActionBar: View {
    @Environment(\.appAccentColor) private var accentColor
    let add: () -> Void
    let voice: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var addLabel: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Text("Расход")
            } else {
                Label("Расход", systemImage: "plus")
            }
        }
        .font(.headline)
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 8 : 20)
        .frame(minHeight: 48)
        .frame(maxWidth: .infinity)
        .foregroundStyle(.primary)
    }

    private var addButton: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: add, label: { addLabel })
                    .buttonStyle(.plain)
                    .glassEffect(
                        .regular.tint(accentColor.opacity(MoneyLayout.accentPillFill)).interactive(),
                        in: .capsule
                    )
            } else {
                Button(action: add) {
                    addLabel
                        .background(accentColor.opacity(MoneyLayout.accentPillFill), in: Capsule())
                }
            }
        }
        .accessibilityLabel("Добавить расход")
    }

    private var voiceButton: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: voice) {
                    Image(systemName: "mic.fill")
                        .font(.title3.weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .frame(width: 52, height: 48)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
            } else {
                Button(action: voice) {
                    Image(systemName: "mic.fill")
                        .font(.title3.weight(.semibold))
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .frame(width: 52, height: 48)
                        .foregroundStyle(.primary)
                }
            }
        }
        .accessibilityLabel("Голосовой ввод")
    }

    private var buttons: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    actionButtons
                }
            } else {
                actionButtons
            }
        }
        .padding(6)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            addButton
            voiceButton
        }
    }

    var body: some View {
        buttons
            .moneyGlassCapsule()
            .frame(maxWidth: 340)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }
}

struct MoneyLoadError: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Не удалось обновить данные", systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                .font(.subheadline.weight(.semibold))
            Text(message).font(.caption).foregroundStyle(.secondary)
            Button("Повторить", action: retry).foregroundStyle(.primary).frame(minHeight: 44)
        }
        .accessibilityElement(children: .contain)
    }
}

/// A segmented picker at normal sizes; a native menu when text needs more room.
struct MoneyPeriodPicker<Value: Hashable>: View {
    let title: String
    let values: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                picker.pickerStyle(.menu).tint(.primary)
            } else {
                picker.pickerStyle(.segmented)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var picker: some View {
        Picker(title, selection: $selection) {
            ForEach(values, id: \.self) { value in
                Text(label(value)).tag(value)
            }
        }
    }
}

struct MoneyCategoryIcon: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.body.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: MoneyLayout.iconRadius))
            .accessibilityHidden(true)
    }
}

struct MoneyTransactionRow: View {
    let transaction: Transaction
    let currencyCode: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var color: Color {
        if transaction.type.isDebt {
            return Color(hex: transaction.debt?.colorHex ?? AppAccent.defaultHex)
        }
        return transaction.type == .transfer ? .secondary : Color(hex: transaction.category?.colorHex ?? AppAccent.defaultHex)
    }

    private var title: String {
        if transaction.type.isDebt {
            let person = transaction.debt?.personName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !person.isEmpty { return person }
            let note = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
            return note.isEmpty ? transaction.type.title : note
        }
        if transaction.type == .transfer { return "Перевод" }
        let note = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? (transaction.category?.displayName ?? transaction.type.title) : note
    }

    private var subtitle: String {
        if transaction.type.isDebt {
            return [transaction.type.title, transaction.account?.name].compactMap { $0 }.joined(separator: " · ")
        }
        if transaction.type == .transfer {
            return [transaction.account?.name, transaction.toAccount?.name].compactMap { $0 }.joined(separator: " → ")
        }
        return [transaction.account?.name, transaction.category?.displayName].compactMap { $0 }.joined(separator: " · ")
    }

    private var amount: some View {
        let prefix: String
        let amountColor: Color
        if transaction.type == .transfer {
            prefix = ""
            amountColor = .primary
        } else if transaction.type.increasesAccountBalance {
            prefix = "+"
            amountColor = MoneyPalette.income
        } else {
            prefix = "−"
            amountColor = MoneyPalette.expense
        }
        return Text(prefix + CurrencyFormatter.string(amount: abs(transaction.amount), currencyCode: currencyCode))
            .foregroundStyle(amountColor)
            .font(.body.weight(.semibold))
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
            if !transaction.tags.isEmpty {
                Text(transaction.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if transaction.attachmentURL != nil {
                Label("Вложение", systemImage: "paperclip").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MoneyCategoryIcon(
                icon: rowIcon,
                color: color
            )
            if dynamicTypeSize.isAccessibilitySize || CurrencyFormatter.string(amount: transaction.amount, currencyCode: currencyCode).count > 12 {
                stackedContent
            } else {
                HStack(alignment: .top, spacing: 12) {
                    details.frame(maxWidth: .infinity, alignment: .leading)
                    amount.fixedSize().layoutPriority(1)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var rowIcon: String {
        if transaction.type.isDebt {
            return transaction.debt?.icon ?? "person.fill"
        }
        if transaction.type == .transfer {
            return "arrow.left.arrow.right"
        }
        return transaction.category?.icon ?? "creditcard.fill"
    }

    private var stackedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            details
            amount
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Wraps filter buttons using their natural width, while constraining long labels.
struct MoneyFlowLayout: Layout {
    var spacing: CGFloat = 8

    private func positions(width: CGFloat, subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (points, CGSize(width: width.isFinite ? width : usedWidth, height: y + rowHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        positions(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = positions(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.points[index].x, y: bounds.minY + result.points[index].y),
                          proposal: ProposedViewSize(width: bounds.width, height: nil))
        }
    }
}


struct MoneyPrimaryButtonStyle: ButtonStyle {
    @Environment(\.appAccentColor) private var accentColor
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(accentColor.opacity(isEnabled ? MoneyLayout.accentPillFill : MoneyLayout.accentPillFillDisabled), in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct MoneyCreateBar<MenuItems: View>: View {
    @Environment(\.appAccentColor) private var accentColor
    let title: String
    private let action: (() -> Void)?
    @ViewBuilder private let menuItems: () -> MenuItems
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(title: String, action: @escaping () -> Void) where MenuItems == EmptyView {
        self.title = title
        self.action = action
        self.menuItems = { EmptyView() }
    }

    init(title: String, @ViewBuilder menu: @escaping () -> MenuItems) {
        self.title = title
        self.action = nil
        self.menuItems = menu
    }

    private var labelContent: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Text(title)
            } else {
                Label(title, systemImage: "plus")
            }
        }
        .font(.headline)
        .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 8 : 20)
        .frame(minHeight: 48)
        .frame(maxWidth: .infinity)
        .foregroundStyle(.primary)
    }

    private var button: some View {
        Group {
            if #available(iOS 26.0, *) {
                Group {
                    if let action {
                        Button(action: action) { labelContent }
                    } else {
                        Menu(content: menuItems, label: { labelContent })
                    }
                }
                .buttonStyle(.plain)
                .glassEffect(
                    .regular.tint(accentColor.opacity(MoneyLayout.accentPillFill)).interactive(),
                    in: .capsule
                )
            } else {
                Group {
                    if let action {
                        Button(action: action) { labelContent }
                    } else {
                        Menu(content: menuItems, label: { labelContent })
                    }
                }
                .buttonStyle(.plain)
                .background(accentColor.opacity(MoneyLayout.accentPillFill), in: Capsule())
            }
        }
        .padding(6)
    }

    var body: some View {
        button
            .moneyGlassCapsule()
            .frame(maxWidth: 340)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }
}

struct MoneyEntityRow: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    let color: Color
    var amount: String? = nil
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            MoneyCategoryIcon(icon: icon, color: color)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                if let amount {
                    Text(amount)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct MoneyProgressSummary: View {
    let title: String
    let icon: String
    let color: Color
    let current: String
    let target: String
    let progress: Double
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MoneyEntityRow(title: title, icon: icon, color: color)
            Text(current)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("из \(target)").font(.subheadline).foregroundStyle(.secondary)
            ProgressView(value: progress.isFinite ? min(max(progress, 0), 1) : 0)
                .tint(color)
                .accessibilityLabel(title)
            Text(status).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }
}
