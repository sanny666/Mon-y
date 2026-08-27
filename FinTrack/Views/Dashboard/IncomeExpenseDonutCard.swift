import Charts
import SwiftUI

struct IncomeExpenseDonutCard: View {
    let title: String
    let systemImage: String
    var tint: Color = SemanticIcon.chart
    let income: Double
    let expense: Double
    let currencyCode: String

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

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                DashboardSectionHeader(
                    title: title,
                    systemImage: systemImage,
                    tint: tint
                )

                HStack(alignment: .center, spacing: 20) {
                    donut
                    legend
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var donut: some View {
        ZStack {
            if slices.isEmpty {
                Chart {
                    SectorMark(
                        angle: .value("Пусто", 1),
                        innerRadius: .ratio(0.62)
                    )
                    .foregroundStyle(Color.secondary.opacity(0.18))
                }
                .chartLegend(.hidden)
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Сумма", slice.amount),
                        innerRadius: .ratio(0.62),
                        angularInset: 2
                    )
                    .foregroundStyle(slice.color)
                    .cornerRadius(4)
                }
                .chartLegend(.hidden)
            }

            VStack(spacing: 2) {
                Text("Всего")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.string(amount: periodTotal, currencyCode: currencyCode))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 148, height: 148)
        .allowsHitTesting(false)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 14) {
            legendRow(title: "Доходы", amount: income, color: incomeColor)
            legendRow(title: "Расходы", amount: expense, color: expenseColor)
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
