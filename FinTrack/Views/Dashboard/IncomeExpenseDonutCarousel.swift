import SwiftUI

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
