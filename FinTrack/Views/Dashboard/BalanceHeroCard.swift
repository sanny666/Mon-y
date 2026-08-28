import SwiftUI

struct BalanceHeroCard: View {
    let totalBalance: Double
    let monthIncome: Double
    let monthExpense: Double
    let balancePoints: [BalancePoint]
    let currencyCode: String

    @AppStorage(AppStorageKeys.hideBalance) private var hideBalance = false
    @AppStorage(AppStorageKeys.appAccentHex) private var appAccentHex = AppAccent.defaultHex
    @Environment(\.colorScheme) private var colorScheme

    private let incomeColor = Color(hex: "#268F6B")
    private let expenseColor = Color(hex: "#FF453A")

    private var monthDelta: Double {
        monthIncome - monthExpense
    }

    private var accentColor: Color {
        Color(hex: appAccentHex)
    }

    private var balanceText: String {
        CurrencyFormatter.string(amount: totalBalance, currencyCode: currencyCode)
    }

    var body: some View {
        cardBody
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilitySummary)
    }

    private var cardBody: some View {
        DashboardCard(verticalPadding: 22) {
            ZStack(alignment: .topTrailing) {
                accentWash
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 10) {
                    headerRow
                    balanceLink
                }
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Общий баланс")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button {
                hideBalance.toggle()
            } label: {
                Image(systemName: hideBalance ? "eye.slash" : "eye")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hideBalance ? "Показать баланс" : "Скрыть баланс")
        }
    }

    private var balanceLink: some View {
        NavigationLink {
            AccountsView()
        } label: {
            mainRow
        }
        .buttonStyle(.plain)
        .accessibilityHint("Открыть счета")
    }

    private var mainRow: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if hideBalance {
                        Text("••••")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                    } else {
                        Text(balanceText)
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                deltaChip
            }

            if !hideBalance {
                BalanceSparkline(points: balancePoints, color: accentColor)
                    .frame(width: 104, height: 52)
                    .accessibilityHidden(true)
            }
        }
    }

    private var deltaChip: some View {
        Group {
            if monthDelta > 0 {
                Text("+\(CurrencyFormatter.string(amount: monthDelta, currencyCode: currencyCode)) за месяц")
                    .foregroundStyle(incomeColor)
            } else if monthDelta < 0 {
                Text("\(CurrencyFormatter.string(amount: monthDelta, currencyCode: currencyCode)) за месяц")
                    .foregroundStyle(expenseColor)
            } else {
                Text("Без изменений за месяц")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    private var accentWash: some View {
        RadialGradient(
            colors: [
                accentColor.opacity(colorScheme == .dark ? 0.14 : 0.12),
                accentColor.opacity(0.04),
                Color.clear
            ],
            center: .topTrailing,
            startRadius: 0,
            endRadius: 180
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private var accessibilitySummary: String {
        if hideBalance {
            return "Общий баланс скрыт"
        }
        return "Общий баланс \(balanceText)"
    }
}

private struct BalanceSparkline: View {
    let points: [BalancePoint]
    let color: Color

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

                Path { path in
                    for index in points.indices {
                        let x = inset + stepX * CGFloat(index)
                        let normalized = (points[index].balance - lower) / range
                        let y = inset + height * (1 - normalized)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}
