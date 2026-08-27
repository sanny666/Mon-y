import SwiftUI
import WidgetKit

struct FinTrackWidget: Widget {
    let kind = "FinTrackWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinTrackTimelineProvider()) { entry in
            FinTrackWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetPalette.background
                }
        }
        .configurationDisplayName("Баланс monёy")
        .description("Общий баланс и последние траты.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FinTrackTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FinTrackWidgetEntry {
        FinTrackWidgetEntry(
            date: .now,
            snapshot: WidgetSnapshot(
                balanceText: "125 000 ₸",
                currencyCode: "KZT",
                recentExpenses: [
                    WidgetExpenseItem(id: "1", title: "Кофе", amountText: "1 500 ₸", dateText: "Сегодня"),
                    WidgetExpenseItem(id: "2", title: "Продукты", amountText: "8 200 ₸", dateText: "Вчера")
                ],
                updatedAt: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FinTrackWidgetEntry) -> Void) {
        completion(FinTrackWidgetEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FinTrackWidgetEntry>) -> Void) {
        let entry = FinTrackWidgetEntry(date: .now, snapshot: WidgetSnapshotStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct FinTrackWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

enum WidgetPalette {
    static let background = Color(red: 5 / 255, green: 5 / 255, blue: 5 / 255)
    static let wordmark = Color(red: 242 / 255, green: 242 / 255, blue: 240 / 255)
    static let muted = Color.white.opacity(0.55)
    static let accent = Color(red: 43 / 255, green: 182 / 255, blue: 115 / 255)
    static let surface = Color(red: 18 / 255, green: 20 / 255, blue: 18 / 255)
}

struct FinTrackWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FinTrackWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumLayout
        default:
            smallLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("monёy")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WidgetPalette.accent)

            Spacer(minLength: 0)

            Text("Баланс")
                .font(.caption2)
                .foregroundStyle(WidgetPalette.muted)

            Text(entry.snapshot.balanceText)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(WidgetPalette.wordmark)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumLayout: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("monёy")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetPalette.accent)

                Spacer(minLength: 0)

                Text("Баланс")
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.muted)

                Text(entry.snapshot.balanceText)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(WidgetPalette.wordmark)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Последние траты")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(WidgetPalette.muted)

                if entry.snapshot.recentExpenses.isEmpty {
                    Text("Пока нет трат")
                        .font(.caption)
                        .foregroundStyle(WidgetPalette.muted)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ForEach(entry.snapshot.recentExpenses) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(WidgetPalette.wordmark)
                                    .lineLimit(1)
                                Text(item.dateText)
                                    .font(.caption2)
                                    .foregroundStyle(WidgetPalette.muted)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            Text(item.amountText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(WidgetPalette.accent)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
#Preview(as: .systemSmall) {
    FinTrackWidget()
} timeline: {
    FinTrackWidgetEntry(
        date: .now,
        snapshot: WidgetSnapshot(
            balanceText: "125 000 ₸",
            currencyCode: "KZT",
            recentExpenses: [],
            updatedAt: .now
        )
    )
}

#Preview(as: .systemMedium) {
    FinTrackWidget()
} timeline: {
    FinTrackWidgetEntry(
        date: .now,
        snapshot: WidgetSnapshot(
            balanceText: "125 000 ₸",
            currencyCode: "KZT",
            recentExpenses: [
                WidgetExpenseItem(id: "1", title: "Кофе", amountText: "1 500 ₸", dateText: "26 авг."),
                WidgetExpenseItem(id: "2", title: "Продукты", amountText: "8 200 ₸", dateText: "25 авг."),
                WidgetExpenseItem(id: "3", title: "Такси", amountText: "2 100 ₸", dateText: "24 авг.")
            ],
            updatedAt: .now
        )
    )
}
#endif
