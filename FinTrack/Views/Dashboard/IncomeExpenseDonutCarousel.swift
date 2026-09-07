import SwiftUI

struct MoneyPeriodSummary: View {
    let todayIncome: Double
    let todayExpense: Double
    let weekIncome: Double
    let weekExpense: Double
    let monthIncome: Double
    let monthExpense: Double
    let currencyCode: String

    @State private var period: Period = .month
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Period: String, CaseIterable {
        case today = "Сегодня", week = "Неделя", month = "Месяц"
    }

    private var income: Double {
        switch period {
        case .today: todayIncome
        case .week: weekIncome
        case .month: monthIncome
        }
    }

    private var expense: Double {
        switch period {
        case .today: todayExpense
        case .week: weekExpense
        case .month: monthExpense
        }
    }

    var body: some View {
        MoneyCard {
            VStack(alignment: .leading, spacing: 20) {
                MoneyPeriodPicker(title: "Период сводки", values: Period.allCases, selection: $period, label: { $0.rawValue })
                if dynamicTypeSize.isAccessibilitySize {
                    amountsStack
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 24) {
                            metric(title: "Доходы", value: income, icon: "arrow.down.left", color: MoneyPalette.income).fixedSize()
                            Spacer(minLength: 0)
                            metric(title: "Расходы", value: expense, icon: "arrow.up.right", color: MoneyPalette.expense).fixedSize()
                        }
                        amountsStack
                    }
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: period)
        }
    }

    private var amountsStack: some View {
        VStack(alignment: .leading, spacing: 16) {
            metric(title: "Доходы", value: income, icon: "arrow.down.left", color: MoneyPalette.income)
            metric(title: "Расходы", value: expense, icon: "arrow.up.right", color: MoneyPalette.expense)
        }
    }

    private func metric(title: String, value: Double, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
            Text(CurrencyFormatter.string(amount: value, currencyCode: currencyCode))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }
}

struct IncomeExpenseDonutCarousel: View {
    let todayIncome: Double
    let todayExpense: Double
    let weekIncome: Double
    let weekExpense: Double
    let monthIncome: Double
    let monthExpense: Double
    let currencyCode: String

    private let interCardSpacing: CGFloat = 12
    private let carouselHeight: CGFloat = 230

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: interCardSpacing) {
                IncomeExpenseDonutCard(
                    title: "Сегодня",
                    systemImage: "sun.max.fill",
                    tint: SemanticIcon.today,
                    income: todayIncome,
                    expense: todayExpense,
                    currencyCode: currencyCode,
                    compact: true
                )
                .containerRelativeFrame(.horizontal, count: 2, spacing: interCardSpacing)

                IncomeExpenseDonutCard(
                    title: "Неделя",
                    systemImage: "calendar",
                    tint: SemanticIcon.week,
                    income: weekIncome,
                    expense: weekExpense,
                    currencyCode: currencyCode,
                    compact: true
                )
                .containerRelativeFrame(.horizontal, count: 2, spacing: interCardSpacing)

                IncomeExpenseDonutCard(
                    title: "Этот месяц",
                    systemImage: "chart.pie.fill",
                    tint: SemanticIcon.chart,
                    income: monthIncome,
                    expense: monthExpense,
                    currencyCode: currencyCode,
                    compact: true
                )
                .containerRelativeFrame(.horizontal, count: 2, spacing: interCardSpacing)
            }
            .scrollTargetLayout()
        }
        .frame(height: carouselHeight)
        .scrollTargetBehavior(.viewAligned)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }
}
