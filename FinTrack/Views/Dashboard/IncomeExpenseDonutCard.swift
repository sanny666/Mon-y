import Charts
import SwiftUI

struct IncomeExpenseDonutCard: View {
    let title: String
    let systemImage: String
    var tint: Color = SemanticIcon.chart
    let income: Double
    let expense: Double
    let currencyCode: String
    var compact: Bool = false

    @State private var animationProgress: Double = 0

    private let incomeColor = Color(hex: "#268F6B")
    private let expenseColor = Color(hex: "#FF453A")

    private var slices: [Slice] {
        var items: [Slice] = []
        if income > 0 {
            items.append(Slice(name: "Доходы", amount: income, color: incomeColor))
        }
        if expense > 0 {
            items.append(Slice(name: "Расходы", amount: expense, color: expenseColor))
        }
        return items
    }

    private var periodTotal: Double { income + expense }

    private var donutSize: CGFloat { compact ? 108 : 148 }
    private var innerRatio: CGFloat { 0.58 }

    var body: some View {
        DashboardCard(verticalPadding: compact ? 14 : 16) {
            VStack(alignment: .leading, spacing: compact ? 12 : 16) {
                DashboardSectionHeader(
                    title: title,
                    systemImage: systemImage,
                    tint: tint,
                    compact: compact
                )

                if compact {
                    VStack(spacing: 12) {
                        donut
                            .frame(maxWidth: .infinity)
                        compactLegend
                    }
                } else {
                    HStack(alignment: .center, spacing: 20) {
                        donut
                        legend
                    }
                }
            }
        }
        .chartAppearAnimation($animationProgress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var donut: some View {
        ZStack {
            if slices.isEmpty {
                Chart {
                    SectorMark(
                        angle: .value("Пусто", 1),
                        innerRadius: .ratio(innerRatio)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.secondary.opacity(0.12),
                                Color.secondary.opacity(0.28)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartLegend(.hidden)
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Сумма", slice.amount * animationProgress),
                        innerRadius: .ratio(innerRatio),
                        angularInset: compact ? 1.5 : 2
                    )
                    .foregroundStyle(sliceGradient(for: slice.color))
                    .cornerRadius(compact ? 3 : 4)
                }
                .chartLegend(.hidden)
            }

            VStack(spacing: 1) {
                Text("Всего")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.string(amount: periodTotal, currencyCode: currencyCode))
                    .font(.system(compact ? .callout : .title3, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
            }
            .padding(.horizontal, compact ? 10 : 16)
            .opacity(0.35 + 0.65 * animationProgress)
        }
        .frame(width: donutSize, height: donutSize)
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 3,
            y: 1
        )
        .allowsHitTesting(false)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 14) {
            legendRow(title: "Доходы", amount: income, color: incomeColor)
            legendRow(title: "Расходы", amount: expense, color: expenseColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            compactLegendRow(title: "Доходы", amount: income, color: incomeColor)
            compactLegendRow(title: "Расходы", amount: expense, color: expenseColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendRow(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(CurrencyFormatter.string(amount: amount, currencyCode: currencyCode))
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private func compactLegendRow(title: String, amount: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.75), color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(CurrencyFormatter.string(amount: amount, currencyCode: currencyCode))
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func sliceGradient(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(0.72),
                color,
                color.opacity(0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var accessibilityText: String {
        "\(title). Доходы \(CurrencyFormatter.string(amount: income, currencyCode: currencyCode)), расходы \(CurrencyFormatter.string(amount: expense, currencyCode: currencyCode))"
    }
}

private struct Slice: Identifiable {
    var id: String { name }
    let name: String
    let amount: Double
    let color: Color
}
