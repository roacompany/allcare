import Foundation
import UserNotifications

// MARK: - Notification Settings Keys

enum NotificationSettings {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    static var feedingReminderEnabled: Bool {
        get { defaults.object(forKey: "feedingReminderEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "feedingReminderEnabled") }
    }

    static var feedingIntervalHours: Double {
        get {
            let val = defaults.double(forKey: "feedingIntervalHours")
            return val > 0 ? val : AppConstants.defaultFeedingIntervalHours
        }
        set { defaults.set(newValue, forKey: "feedingIntervalHours") }
    }

    static var vaccinationReminderEnabled: Bool {
        get { defaults.object(forKey: "vaccinationReminderEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "vaccinationReminderEnabled") }
    }

    static var reorderReminderEnabled: Bool {
        get { defaults.object(forKey: "reorderReminderEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "reorderReminderEnabled") }
    }
}

// MARK: - NotificationService

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Feeding Reminder

    func scheduleFeedingReminder(babyName: String, afterMinutes: Int) {
        guard NotificationSettings.feedingReminderEnabled else { return }

        // 이전 수유 알림 취소 후 새로 예약
        cancelFeedingReminders()

        let content = UNMutableNotificationContent()
        content.title = "수유 시간"
        content.body = "\(babyName)의 다음 수유 시간이에요!"
        content.sound = .default
        content.categoryIdentifier = "FEEDING_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(afterMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "feeding-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelFeedingReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["feeding-reminder"])
    }

    // MARK: - Vaccination Reminder

    func scheduleVaccinationReminders(vaccinations: [Vaccination], babyName: String) {
        guard NotificationSettings.vaccinationReminderEnabled else { return }

        // 기존 접종 알림 전부 취소
        cancelVaccinationReminders(vaccinations: vaccinations)

        let center = UNUserNotificationCenter.current()

        for vaccination in vaccinations where !vaccination.isCompleted {
            let scheduledDate = vaccination.scheduledDate

            // D-7 알림
            if let d7 = Calendar.current.date(byAdding: .day, value: -7, to: scheduledDate),
               d7 > Date() {
                let content = UNMutableNotificationContent()
                content.title = "접종 예정 (7일 전)"
                content.body = "\(babyName)의 \(vaccination.vaccine.displayName) \(vaccination.doseNumber)차 접종이 7일 후입니다."
                content.sound = .default
                content.categoryIdentifier = "VACCINATION_REMINDER"

                let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: d7)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "vacc-d7-\(vaccination.id)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }

            // D-1 알림
            if let d1 = Calendar.current.date(byAdding: .day, value: -1, to: scheduledDate),
               d1 > Date() {
                let content = UNMutableNotificationContent()
                content.title = "접종 예정 (내일)"
                content.body = "\(babyName)의 \(vaccination.vaccine.displayName) \(vaccination.doseNumber)차 접종이 내일입니다."
                content.sound = .default
                content.categoryIdentifier = "VACCINATION_REMINDER"

                let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: d1)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "vacc-d1-\(vaccination.id)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }

    func cancelVaccinationReminders(vaccinations: [Vaccination]) {
        let ids = vaccinations.flatMap { ["vacc-d7-\($0.id)", "vacc-d1-\($0.id)"] }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Todo Reminder

    func scheduleTodoReminder(todo: TodoItem) {
        guard let dueDate = todo.dueDate else { return }

        let content = UNMutableNotificationContent()
        content.title = "할 일 알림"
        content.body = todo.title
        content.sound = .default
        content.categoryIdentifier = "TODO_REMINDER"

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "todo-\(todo.id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel

    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
