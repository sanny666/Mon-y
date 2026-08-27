import Charts
import SwiftUI

struct AnalyticsView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage(AppStorageKeys.defaultCurrency) private var defaultCurrency = AppCurrency.kzt.rawValue
    @State private var viewModel = AnalyticsViewModel()
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                AnalyticsSkeleton()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Picker("Период", selection: $viewModel.period) {
                            ForEach(AnalyticsPeriod.allCases) { period in
                                Text(period.title).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: viewModel.period) { _, _ in reload() }

                        categorySection
                        monthComparisonSection
                        balanceSection
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Аналитика")
        .onAppear { FirstLoad.finish($isLoading, reload) }
        .onChange(of: container.refreshToken) { _, _ in
            guard !isLoading else { return }
            reload()
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Расходы по категориям")
                .font(.headline)

            if viewModel.categorySlices.isEmpty {
                chartEmpty(
                    systemImage: "chart.pie",
                    title: "Нет расходов",
                    subtitle: "За выбранный период расходов нет"
                )
            } else {
                Chart(viewModel.categorySlices) { slice in
                    SectorMark(
                        angle: .value("Сумма", slice.amount),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(Color(hex: slice.colorHex))
                    .accessibilityLabel(slice.name)
                }
                .frame(height: 220)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.categorySlices.prefix(6)) { slice in
                        HStack {
                            Circle()
                                .fill(Color(hex: slice.colorHex))
                                .frame(width: 8, height: 8)
                            Text(slice.name)
                                .font(.caption)
                            Spacer()
                            Text(CurrencyFormatter.string(amount: slice.amount, currencyCode: viewModel.currencyCode))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var monthComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Доходы и расходы по месяцам")
                .font(.headline)

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
                            y: .value("Сумма", item.income)
                        )
                        .foregroundStyle(by: .value("Тип", "Доход"))

                        BarMark(
                            x: .value("Месяц", item.monthStart, unit: .month),
                            y: .value("Сумма", item.expense)
                        )
                        .foregroundStyle(by: .value("Тип", "Расход"))
                    }
                }
                .chartForegroundStyleScale([
                    "Доход": Color.green.opacity(0.85),
                    "Расход": Color.red.opacity(0.85)
                ])
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 220)
            }
        }
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Динамика баланса")
                .font(.headline)

            if viewModel.balancePoints.isEmpty {
                chartEmpty(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: "Нет данных",
                    subtitle: "Баланс появится после счетов и операций"
                )
            } else {
                Chart(viewModel.balancePoints) { point in
                    LineMark(
                        x: .value("Дата", point.date),
                        y: .value("Баланс", point.balance)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor)

                    AreaMark(
                        x: .value("Дата", point.date),
                        y: .value("Баланс", point.balance)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.accentColor.opacity(0.12))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .frame(height: 200)
            }
        }
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
        .frame(height: 160)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func reload() {
        viewModel.reload(container: container, defaultCurrency: defaultCurrency)
    }
}
