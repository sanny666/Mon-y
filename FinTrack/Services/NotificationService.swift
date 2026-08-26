import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        default:
            break
        }
    }

    func notifyBudgetThreshold(categoryName: String, percent: Int, budgetID: UUID) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        if percent >= 100 {
            content.title = "Лимит превышен"
            content.body = "Лимит по категории \(categoryName) превышен"
        } else {
            content.title = "Бюджет почти исчерпан"
            content.body = "Бюджет по категории \(categoryName) почти исчерпан (\(percent)%)"
        }

        let request = UNNotificationRequest(
            identifier: "budget-\(budgetID.uuidString)-\(percent)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func scheduleRecurringReminder(
        id: UUID,
        title: String,
        amountText: String,
        nextDate: Date
    ) {
        cancelRecurringReminder(id: id)
        guard let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: nextDate) else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: dayBefore)
        components.hour = 9
        components.minute = 0

        // Skip if reminder time already passed
        if let fireDate = Calendar.current.date(from: components), fireDate <= Date.now {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Напоминание"
        content.body = "Завтра спишется \(title) на \(amountText)"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: recurringReminderID(id),
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelRecurringReminder(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [recurringReminderID(id)])
    }

    private func recurringReminderID(_ id: UUID) -> String {
        "recurring-\(id.uuidString)-reminder"
    }
}
