import Charts
import SwiftUI

struct AnalyticsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = AnalyticsViewModel()
    @State private var isLoading = true
    @State private var animationProgress: Double = 0

    private let incomeColor = Color(hex: "#268F6B")
    private let expenseColor = Color(hex: "#FF453A")

    var body: some View {
        Group {
            if isLoading {
                AnalyticsSkeleton()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Период", selection: $viewModel.period) {
                            ForEach(AnalyticsPeriod.allCases) { period in
                                Text(period.title).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)

                        categorySection
                            .id("category-\(viewModel.period.rawValue)")
                        monthComparisonSection
                            .id("compare-\(viewModel.period.rawValue)")
                        balanceSection
                            .id("balance-\(viewModel.period.rawValue)")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .chartAppearAnimation($animationProgress)
                .simultaneousGesture(periodSwipeGesture)
            }
        }
        .navigationTitle("Аналитика")
        .toolbar(.visible, for: .navigationBar)
        .onAppear { FirstLoad.finish($isLoading, reload) }
        .onChange(of: container.refreshToken) { _, _ in
            guard !isLoading else { return }
            reload()
        }
        .onChange(of: viewModel.period) { _, _ in
            guard !isLoading else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                reload()
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.period)
    }

    private var periodSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                // Horizontal swipe wins over vertical scroll.
                guard abs(dx) > abs(dy) * 1.4, abs(dx) > 56 else { return }
                shiftPeriod(by: dx < 0 ? 1 : -1)
            }
    }

    private func shiftPeriod(by delta: Int) {
        let periods = AnalyticsPeriod.allCases
        guard let index = periods.firstIndex(of: viewModel.period) else { return }
        let next = index + delta
        guard periods.indices.contains(next) else { return }
        viewModel.period = periods[next]
    }

    private var categoryTotal: Double {
        viewModel.categorySlices.reduce(0) { $0 + $1.amount }
    }

    private var categorySection: some View {
        DashboardCard {
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

                        VStack(spacing: 2) {
                            Text("Всего")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(CurrencyFormatter.string(amount: categoryTotal, currencyCode: viewModel.currencyCode))
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 20)
                        .opacity(0.35 + 0.65 * animationProgress)
                    }
                    .frame(height: 200)
                    .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
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
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var monthComparisonSection: some View {
        DashboardCard {
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
        DashboardCard {
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
                            .shadow(color: Color.accentColor.opacity(0.25), radius: 4, y: 2)
                        }

                        if let last = viewModel.balancePoints.last {
                            PointMark(
                                x: .value("Дата", last.date),
                                y: .value("Баланс", last.balance * animationProgress)
                            )
                            .symbolSize(48)
                            .foregroundStyle(Color.accentColor)
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
                Color.accentColor.opacity(colorScheme == .dark ? 0.28 : 0.22),
                Color.accentColor.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var lineGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.75),
                Color.accentColor
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
