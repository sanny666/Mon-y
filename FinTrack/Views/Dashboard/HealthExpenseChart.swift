import SwiftUI

struct HealthExpenseChart: View {
    let points: [DailyAmountPoint]
    let currencyCode: String
    var onOpenDetails: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var animationProgress: Double = 0

    private let chartColor = SemanticIcon.flame
    private let weekdayLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        calendar.firstWeekday = 2
        return calendar
    }

    /// Последние 7 дней, сегодня — всегда последний столбец.
    private var chartPoints: [DailyAmountPoint] {
        let today = calendar.startOfDay(for: Date.now)
        guard let startDay = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }
        let byDay = Dictionary(uniqueKeysWithValues: points.map {
            (calendar.startOfDay(for: $0.date), $0.amount)
        })
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { return nil }
            let key = calendar.startOfDay(for: day)
            return DailyAmountPoint(date: key, amount: byDay[key] ?? 0)
        }
    }

    private var total: Double {
        chartPoints.reduce(0) { $0 + $1.amount }
    }

    private var average: Double {
        guard !chartPoints.isEmpty else { return 0 }
        return total / Double(chartPoints.count)
    }

    private var hasExpenses: Bool { total > 0 }

    private var yUpperBound: Double {
        let peak = chartPoints.map(\.amount).max() ?? 0
        return max(peak, average, 1) * 1.2
    }

    private var barColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.22)
    }

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                DashboardSectionHeader(
                    title: "Расходы",
                    systemImage: "flame.fill",
                    tint: chartColor,
                    tintTitle: true,
                    action: onOpenDetails
                )

                summaryText
                    .accessibilityElement(children: .combine)

                chartRow
            }
        }
        .chartAppearAnimation($animationProgress)
    }

    private var summaryText: some View {
        Group {
            if hasExpenses {
                Text(summaryAttributed)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("На этой неделе расходов не было.")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var summaryAttributed: AttributedString {
        let amount = CurrencyFormatter.string(amount: average, currencyCode: currencyCode)
        var text = AttributedString("В среднем вы тратили \(amount) в день на этой неделе.")
        if let range = text.range(of: amount) {
            text[range].font = .body.weight(.semibold)
        }
        return text
    }

    private var chartRow: some View {
        HStack(alignment: .center, spacing: 10) {
            if hasExpenses {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Средние расходы")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.string(amount: average, currencyCode: currencyCode))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 96, alignment: .leading)
                .accessibilityElement(children: .combine)
            }

            expenseBarChart
        }
        .frame(height: 156)
    }

    private var expenseBarChart: some View {
        GeometryReader { geo in
            let labelHeight: CGFloat = 18
            let chartHeight = max(geo.size.height - labelHeight - 6, 1)
            let count = max(CGFloat(chartPoints.count), 1)
            let cellWidth = geo.size.width / count
            let barWidth = cellWidth * 0.55
            let averageOffset = chartHeight * CGFloat(average / yUpperBound) * animationProgress

            VStack(spacing: 6) {
                ZStack(alignment: .bottom) {
                    if hasExpenses {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.45))
                            .frame(height: 1.5)
                            .padding(.bottom, averageOffset)
                            .opacity(animationProgress)
                    }

                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(chartPoints) { point in
                            dayBar(
                                point: point,
                                cellWidth: cellWidth,
                                barWidth: barWidth,
                                chartHeight: chartHeight
                            )
                        }
                    }
                }
                .frame(height: chartHeight)

                HStack(spacing: 0) {
                    ForEach(chartPoints) { point in
                        let isToday = calendar.isDateInToday(point.date)
                        Text(weekdayLabel(for: point.date))
                            .font(.caption)
                            .foregroundStyle(isToday ? chartColor : .secondary)
                            .frame(width: cellWidth)
                    }
                }
            }
        }
    }

    private func dayBar(
        point: DailyAmountPoint,
        cellWidth: CGFloat,
        barWidth: CGFloat,
        chartHeight: CGFloat
    ) -> some View {
        let isToday = calendar.isDateInToday(point.date)
        let fillHeight = chartHeight * CGFloat(visualAmount(for: point.amount) / yUpperBound) * animationProgress
        let cornerRadius = min(5, barWidth / 2, fillHeight / 2)

        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isToday ? chartColor : barColor)
                .frame(width: barWidth, height: fillHeight)
        }
        .frame(width: cellWidth, height: chartHeight)
    }

    private func visualAmount(for amount: Double) -> Double {
        max(amount, yUpperBound * 0.07)
    }

    private func weekdayLabel(for date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let index = (weekday + 5) % 7
        return weekdayLabels[index]
    }
}
