import Charts
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

    private var weekPoints: [DailyAmountPoint] {
        let today = calendar.startOfDay(for: Date.now)
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return points
        }
        let startDay = calendar.startOfDay(for: interval.start)
        let byDay = Dictionary(uniqueKeysWithValues: points.map {
            (calendar.startOfDay(for: $0.date), $0.amount)
        })
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { return nil }
            let key = calendar.startOfDay(for: day)
            return DailyAmountPoint(date: key, amount: byDay[key] ?? 0)
        }
    }

    private var elapsedWeekPoints: [DailyAmountPoint] {
        let today = calendar.startOfDay(for: Date.now)
        return weekPoints.filter { $0.date <= today }
    }

    private var total: Double {
        elapsedWeekPoints.reduce(0) { $0 + $1.amount }
    }

    private var average: Double {
        guard !elapsedWeekPoints.isEmpty else { return 0 }
        return total / Double(elapsedWeekPoints.count)
    }

    private var hasExpenses: Bool { total > 0 }

    private var yUpperBound: Double {
        let peak = weekPoints.map(\.amount).max() ?? 0
        return max(peak, average, 1) * 1.2
    }

    private var barFill: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.52), Color.white.opacity(0.22)]
                : [Color.black.opacity(0.08), Color.black.opacity(0.26)],
            startPoint: .top,
            endPoint: .bottom
        )
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

            Chart {
                ForEach(weekPoints) { point in
                    BarMark(
                        x: .value("День", point.date, unit: .day),
                        y: .value("Расход", visualAmount(for: point.amount) * animationProgress),
                        width: .ratio(0.55)
                    )
                    .foregroundStyle(barFill)
                    .cornerRadius(5)
                }

                if hasExpenses {
                    RuleMark(y: .value("Среднее", average * animationProgress))
                        .foregroundStyle(chartColor)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .opacity(animationProgress)
                }
            }
            .chartYScale(domain: 0...yUpperBound)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: weekPoints.map(\.date)) { value in
                    AxisValueLabel(centered: true) {
                        if let date = value.as(Date.self) {
                            Text(weekdayLabel(for: date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(height: 156)
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
