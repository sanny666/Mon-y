import Foundation

struct RecurringService {
    private let calendar = Calendar.current

    /// Creates at most one transaction per due template, then advances `nextDate`
    /// past any missed periods (no catch-up duplicates).
    ///
    /// Materialization is foreground-only (call sites: app launch / scene active /
    /// periodic maintenance while the process is alive). Day-before reminders still fire
    /// via `UNNotificationRequest` without the app open; the real transaction appears on
    /// the next open. There is no server push path.
    func processDue(
        items: [RecurringTransaction],
        now: Date = .now,
        createTransaction: (RecurringTransaction, Date) throws -> Void,
        saveItem: (RecurringTransaction) throws -> Void
    ) throws -> Int {
        var created = 0
        for item in items where item.nextDate <= now {
            try createTransaction(item, now)

            // Catch-up policy: materialize once, then skip missed periods.
            // TODO: optional setting to materialize all missed periods as separate transactions.
            while item.nextDate <= now {
                item.nextDate = advance(item.nextDate, frequency: item.frequency)
            }
            try saveItem(item)
            created += 1
        }
        return created
    }

    func advance(_ date: Date, frequency: RecurringFrequency) -> Date {
        let component: Calendar.Component
        switch frequency {
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        case .yearly: component = .year
        }
        return calendar.date(byAdding: component, value: 1, to: date) ?? date.addingTimeInterval(86400)
    }
}
