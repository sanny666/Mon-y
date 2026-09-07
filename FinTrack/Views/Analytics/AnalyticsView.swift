import Charts
import SwiftUI

struct AnalyticsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appAccentColor) private var accent
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = AnalyticsViewModel()
    @State private var isLoading = true
    @State private var animationProgress: Double = 0
    @State private var expenseDayOffset = 0

    private let incomeColor = MoneyPalette.income
    private let expenseColor = MoneyPalette.expense
    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        Group {
            if isLoading {
                AnalyticsSkeleton()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        MoneyPeriodPicker(title: "Период", values: AnalyticsPeriod.allCases,
                                          selection: $viewModel.period, label: { $0.title })

                        weeklyExpenseSection
                        categorySection
                            .id("category-\(viewModel.period.rawValue)")
                        monthComparisonSection
                            .id("compare-\(viewModel.period.rawValue)")
                        balanceSection
                            .id("balance-\(viewModel.period.rawValue)")
                    }
                    .padding(.horizontal, MoneyLayout.pageInset)
                    .padding(.bottom, 24)
                    .frame(maxWidth: MoneyLayout.contentWidth)
                    .frame(maxWidth: .infinity)
                }
                .background(MoneyPalette.canvas)
                .chartAppearAnimation($animationProgress)
            }
        }
        .largeScreenTitle("Аналитика")
        .onAppear { FirstLoad.finish($isLoading, reload) }
        .onChange(of: container.refreshToken) { _, _ in
            guard !isLoading else { return }
            reload()
        }
        .onChange(of: viewModel.period) { _, _ in
            guard !isLoading else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                reload()
            }
        }
        .onChange(of: viewModel.availableExpenseDays) { _, maximum in
            expenseDayOffset = min(expenseDayOffset, maximum)
        }
        .sensoryFeedback(.selection, trigger: viewModel.period)
    }

    private var weeklyExpenseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HealthExpenseChart(
                points: viewModel.expenseHistory,
                currencyCode: viewModel.currencyCode,
                endDate: expenseChartEndDate,
                periodDescription: expenseChartPeriodDescription,
                dayOffset: expenseDayOffset,
                maxDayOffset: viewModel.availableExpenseDays,
                onDayOffsetChange: { next in
                    guard next != expenseDayOffset else { return }
                    expenseDayOffset = next
                }
            )
        }
    }

    private var expenseChartEndDate: Date {
        calendar.date(byAdding: .day, value: -expenseDayOffset, to: .now) ?? .now
    }

    private var expenseChartPeriodDescription: String {
        expenseDayOffset == 0 ? "на этой неделе" : "за период \(expenseChartDateRange)"
    }

    private var expenseChartDateRange: String {
        let endDate = expenseChartEndDate
        let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) ?? endDate
        let formatter = DateIntervalFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate, to: endDate)
    }

    private var categoryTotal: Double {
        viewModel.categorySlices.reduce(0) { $0 + $1.amount }
    }

    private var categorySection: some View {
        MoneyCard {
            VStack(alignment: .leading, spacing: 16) {
                DashboardSectionHeader(
                    title: "Расходы по категориям",
                    systemImage: "chart.pie.fill",
                    tint: SemanticIcon.chart
                )

                if viewModel.categorySlices.isEmpty {
                    chartEmpty(
                        systemImage: "chart.pie",
                        title: "Нет расходов",
                        subtitle: "За выбранный период расходов нет"
                    )
                } else {
                    Text(CurrencyFormatter.string(amount: categoryTotal, currencyCode: viewModel.currencyCode))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    ZStack {
                        Chart(viewModel.categorySlices) { slice in
                            SectorMark(
                                angle: .value("Сумма", slice.amount * animationProgress),
                                innerRadius: .ratio(0.58),
                                angularInset: 2
                            )
                            .foregroundStyle(sliceGradient(for: Color(hex: slice.colorHex)))
                            .cornerRadius(4)
                            .accessibilityLabel(slice.name)
                        }
                        .chartLegend(.hidden)

                        Text("За период")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 200)
                    .allowsHitTesting(false)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.categorySlices.prefix(6)) { slice in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: slice.colorHex).opacity(0.75),
                                                Color(hex: slice.colorHex)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 8, height: 8)
                                Text(slice.name)
                                    .font(.subheadline)
                                Spacer()
                                Text(CurrencyFormatter.string(amount: slice.amount, currencyCode: viewModel.currencyCode))
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var monthComparisonSection: some View {
        MoneyCard {
            VStack(alignment: .leading, spacing: 16) {
                DashboardSectionHeader(
                    title: "Доходы и расходы",
                    systemImage: "chart.bar.fill",
                    tint: SemanticIcon.list
                )

                if viewModel.monthComparisons.isEmpty {
                    chartEmpty(
                        systemImage: "chart.bar",
                        title: "Нет данных",
                        subtitle: "Добавьте доходы или расходы"
                    )
                } else {
                    Chart {
                        ForEach(viewModel.monthComparisons) { item in
                            BarMark(
                                x: .value("Месяц", item.monthStart, unit: .month),
                                y: .value("Сумма", item.income * animationProgress),
                                width: .ratio(0.32)
                            )
                            .foregroundStyle(barGradient(for: incomeColor))
                            .position(by: .value("Тип", "Доход"))
                            .cornerRadius(5)

                            BarMark(
                                x: .value("Месяц", item.monthStart, unit: .month),
                                y: .value("Сумма", item.expense * animationProgress),
                                width: .ratio(0.32)
                            )
                            .foregroundStyle(barGradient(for: expenseColor))
                            .position(by: .value("Тип", "Расход"))
                            .cornerRadius(5)
                        }
                    }
                    .chartLegend(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                .foregroundStyle(Color.secondary.opacity(0.25))
                            AxisValueLabel {
                                if let number = value.as(Double.self) {
                                    Text(compactAxis(number))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 220)

                    HStack(spacing: 16) {
                        legendChip(title: "Доход", color: incomeColor)
                        legendChip(title: "Расход", color: expenseColor)
                    }
                }
            }
        }
    }

    private var balanceSection: some View {
        MoneyCard {
            VStack(alignment: .leading, spacing: 16) {
                DashboardSectionHeader(
                    title: "Динамика баланса",
                    systemImage: "chart.line.uptrend.xyaxis",
                    tint: SemanticIcon.flame,
                    tintTitle: true
                )

                if viewModel.balancePoints.isEmpty {
                    chartEmpty(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "Нет данных",
                        subtitle: "Баланс появится после счетов и операций"
                    )
                } else {
                    Chart {
                        ForEach(viewModel.balancePoints) { point in
                            AreaMark(
                                x: .value("Дата", point.date),
                                y: .value("Баланс", point.balance * animationProgress)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(areaFill)

                            LineMark(
                                x: .value("Дата", point.date),
                                y: .value("Баланс", point.balance * animationProgress)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(lineGradient)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .shadow(color: accent.opacity(0.25), radius: 4, y: 2)
                        }

                        if let last = viewModel.balancePoints.last {
                            PointMark(
                                x: .value("Дата", last.date),
                                y: .value("Баланс", last.balance * animationProgress)
                            )
                            .symbolSize(48)
                            .foregroundStyle(accent)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                .foregroundStyle(Color.secondary.opacity(0.25))
                            AxisValueLabel {
                                if let number = value.as(Double.self) {
                                    Text(compactAxis(number))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    private var areaFill: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(colorScheme == .dark ? 0.28 : 0.22),
                accent.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var lineGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(0.75),
                accent
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
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

    private func barGradient(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(0.72),
                color
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func legendChip(title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(barGradient(for: color))
                .frame(width: 10, height: 10)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func compactAxis(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if absValue >= 1_000 {
            return String(format: "%.0fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }

    private func chartEmpty(systemImage: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
    }

    private func reload() {
        viewModel.reload(container: container, defaultCurrency: defaultCurrency)
    }
}
