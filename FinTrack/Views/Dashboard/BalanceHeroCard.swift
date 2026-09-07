import SwiftUI

struct BalanceHeroCard: View {
    let totalBalance: Double
    let monthIncome: Double
    let monthExpense: Double
    let balancePoints: [BalancePoint]
    let currencyCode: String

    @AppStorage(AppStorageKeys.hideBalance) private var hideBalance = false
    @Environment(\.appAccentColor) private var accentColor
    @State private var animationProgress: Double = 0

    private let incomeColor = MoneyPalette.income
    private let expenseColor = MoneyPalette.expense

    private var monthDelta: Double {
        monthIncome - monthExpense
    }

    private var balanceText: String {
        CurrencyFormatter.string(amount: totalBalance, currencyCode: currencyCode)
    }

    var body: some View {
        cardBody
            .chartAppearAnimation($animationProgress)

    }

    private var cardBody: some View {
        MoneyCard(tinted: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Общий баланс", systemImage: "wallet.bifold")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button { hideBalance.toggle() } label: {
                        Image(systemName: hideBalance ? "eye.slash" : "eye")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(hideBalance ? "Показать баланс" : "Скрыть баланс")
                }

                Text(hideBalance ? "••••" : balanceText)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
                    .accessibilityLabel(hideBalance ? "Общий баланс скрыт" : "Общий баланс \(balanceText)")

                if !hideBalance {
                    Text(deltaText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(monthDelta == 0 ? Color.secondary : (monthDelta > 0 ? incomeColor : expenseColor))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .bottom) {
                    NavigationLink { AccountsView() } label: {
                        HStack(spacing: 6) {
                            Text("Счета")
                            Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 12)
                    if !hideBalance {
                        BalanceSparkline(points: balancePoints, color: accentColor, progress: animationProgress)
                            .frame(width: 104, height: 44)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private var deltaText: String {
        if monthDelta == 0 { return "Без изменений за месяц" }
        let prefix = monthDelta > 0 ? "+" : ""
        return "\(prefix)\(CurrencyFormatter.string(amount: monthDelta, currencyCode: currencyCode)) за месяц"
    }


}

private struct BalanceSparkline: View {
    let points: [BalancePoint]
    let color: Color
    var progress: Double = 1

    @Environment(\.colorScheme) private var colorScheme

    private let inset: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            if points.count < 2 {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04))
            } else {
                let values = points.map(\.balance)
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 0
                let span = Swift.max(maxValue - minValue, 1)
                let bottomPad = span * 0.3
                let topPad = span * 0.12
                let lower = minValue - bottomPad
                let upper = maxValue + topPad
                let range = Swift.max(upper - lower, 1)

                let width = geometry.size.width - inset * 2
                let height = geometry.size.height - inset * 2
                let stepX = width / CGFloat(points.count - 1)
                let bottomY = inset + height

                let linePoints: [CGPoint] = points.indices.map { index in
                    let x = inset + stepX * CGFloat(index)
                    let normalized = (points[index].balance - lower) / range
                    let y = inset + height * (1 - normalized)
                    return CGPoint(x: x, y: y)
                }

                ZStack {
                    if let first = linePoints.first, let last = linePoints.last {
                        Path { path in
                            path.move(to: first)
                            for point in linePoints.dropFirst() {
                                path.addLine(to: point)
                            }
                            path.addLine(to: CGPoint(x: last.x, y: bottomY))
                            path.addLine(to: CGPoint(x: first.x, y: bottomY))
                            path.closeSubpath()
                        }
                        .fill(areaFill)
                        .opacity(progress)
                    }

                    Path { path in
                        for (index, point) in linePoints.enumerated() {
                            if index == 0 {
                                path.move(to: point)
                            } else {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
    }

    private var areaFill: LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(colorScheme == .dark ? 0.24 : 0.18),
                color.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
