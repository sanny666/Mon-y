import SwiftUI

struct HealthExpenseChart: View {
    let points: [DailyAmountPoint]
    let currencyCode: String
    var onOpenDetails: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var animationProgress: Double = 0
    @State private var selectedIndex: Int?

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

    private var todayIndex: Int {
        chartPoints.firstIndex { calendar.isDateInToday($0.date) } ?? max(chartPoints.count - 1, 0)
    }

    private var highlightedIndex: Int {
        selectedIndex ?? todayIndex
    }

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
                    systemImage: "arrow.up.circle.fill",
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
                        ForEach(Array(chartPoints.enumerated()), id: \.element.id) { index, point in
                            dayBar(
                                point: point,
                                isHighlighted: index == highlightedIndex,
                                cellWidth: cellWidth,
                                barWidth: barWidth,
                                chartHeight: chartHeight
                            )
                        }
                    }

                    if let selectedIndex, chartPoints.indices.contains(selectedIndex) {
                        chartDayTooltip(for: chartPoints[selectedIndex])
                            .position(
                                x: clampedTooltipCenterX(
                                    index: selectedIndex,
                                    cellWidth: cellWidth,
                                    chartWidth: geo.size.width
                                ),
                                y: 22
                            )
                            .transition(.scale(scale: 0.88, anchor: .bottom).combined(with: .opacity))
                    }
                }
                .frame(height: chartHeight)
                .contentShape(Rectangle())
                .gesture(hasExpenses ? scrubGesture(cellWidth: cellWidth) : nil)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selectedIndex != nil)
                .sensoryFeedback(.selection, trigger: selectedIndex) { _, new in
                    new != nil
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Расходы за неделю")
                .accessibilityValue(accessibilityChartValue)
                .accessibilityAdjustableAction { direction in
                    guard hasExpenses else { return }
                    let delta = direction == .increment ? 1 : -1
                    let base = selectedIndex ?? todayIndex
                    let next = min(max(base + delta, 0), chartPoints.count - 1)
                    withAnimation(.snappy(duration: 0.18, extraBounce: 0.05)) {
                        selectedIndex = next
                    }
                }

                HStack(spacing: 0) {
                    ForEach(Array(chartPoints.enumerated()), id: \.element.id) { index, point in
                        Text(weekdayLabel(for: point.date))
                            .font(.caption)
                            .foregroundStyle(index == highlightedIndex ? chartColor : .secondary)
                            .animation(.snappy(duration: 0.18, extraBounce: 0.05), value: highlightedIndex)
                            .frame(width: cellWidth)
                    }
                }
            }
        }
    }

    private var accessibilityChartValue: String {
        if let selectedIndex, chartPoints.indices.contains(selectedIndex) {
            let point = chartPoints[selectedIndex]
            let amount = CurrencyFormatter.string(amount: point.amount, currencyCode: currencyCode)
            return "\(weekdayLabel(for: point.date)): \(amount)"
        }
        let averageText = CurrencyFormatter.string(amount: average, currencyCode: currencyCode)
        return "Среднее \(averageText) в день"
    }

    private func scrubGesture(cellWidth: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                switch value {
                case .second(true, let drag?):
                    updateSelection(at: drag.location.x, cellWidth: cellWidth)
                default:
                    break
                }
            }
            .onEnded { _ in
                withAnimation(.snappy(duration: 0.18, extraBounce: 0.05)) {
                    selectedIndex = nil
                }
            }
    }

    private func updateSelection(at x: CGFloat, cellWidth: CGFloat) {
        let index = dayIndex(at: x, cellWidth: cellWidth)
        guard index != selectedIndex else { return }

        if selectedIndex == nil {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedIndex = index
            }
        } else {
            withAnimation(.snappy(duration: 0.18, extraBounce: 0.05)) {
                selectedIndex = index
            }
        }
    }

    private func dayIndex(at x: CGFloat, cellWidth: CGFloat) -> Int {
        let index = Int(x / cellWidth)
        return min(max(index, 0), chartPoints.count - 1)
    }

    private func barCenterX(index: Int, cellWidth: CGFloat) -> CGFloat {
        (CGFloat(index) + 0.5) * cellWidth
    }

    private func clampedTooltipCenterX(index: Int, cellWidth: CGFloat, chartWidth: CGFloat) -> CGFloat {
        let center = barCenterX(index: index, cellWidth: cellWidth)
        let halfWidth: CGFloat = 44
        return min(max(center, halfWidth + 4), chartWidth - halfWidth - 4)
    }

    private func chartDayTooltip(for point: DailyAmountPoint) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(weekdayLabel(for: point.date))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.string(amount: point.amount, currencyCode: currencyCode))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(colorScheme == .dark ? 0.14 : 0.45),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 8, y: 4)
            }

            TooltipCaret()
                .offset(y: -1)
        }
        .animation(.snappy(duration: 0.18, extraBounce: 0.05), value: point.id)
    }

    private func dayBar(
        point: DailyAmountPoint,
        isHighlighted: Bool,
        cellWidth: CGFloat,
        barWidth: CGFloat,
        chartHeight: CGFloat
    ) -> some View {
        let fillHeight = chartHeight * CGFloat(visualAmount(for: point.amount) / yUpperBound) * animationProgress
        let cornerRadius = min(5, barWidth / 2, fillHeight / 2)

        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isHighlighted ? chartColor : barColor)
                .animation(.snappy(duration: 0.18, extraBounce: 0.05), value: isHighlighted)
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

private struct TooltipCaret: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TooltipCaretShape()
            .fill(.ultraThinMaterial)
            .frame(width: 14, height: 7)
            .overlay {
                TooltipCaretShape()
                    .stroke(
                        Color.white.opacity(colorScheme == .dark ? 0.14 : 0.45),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 2, y: 1)
    }
}

private struct TooltipCaretShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
