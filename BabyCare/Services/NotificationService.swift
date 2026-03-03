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

    static var vaccinationDaysBefore: [Int] {
        get {
            guard let data = defaults.data(forKey: "vaccinationDaysBefore"),
                  let days = try? JSONDecoder().decode([Int].self, from: data) else {
                return [7, 1]
            }
            return days
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "vaccinationDaysBefore")
            }
        }
    }

    static var reorderReminderEnabled: Bool {
        get { defaults.object(forKey: "reorderReminderEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "reorderReminderEnabled") }
    }
}

// MARK: - Activity Reminder Rules (활동별 알림 규칙)

struct ActivityReminderRule: Codable, Identifiable {
    var id: String { activityType }
    var activityType: String  // Activity.ActivityType.rawValue
    var enabled: Bool
    var intervalMinutes: Int  // 기록 후 N분 뒤 알림

    var type: Activity.ActivityType? {
        Activity.ActivityType(rawValue: activityType)
    }

    var displayName: String { type?.displayName ?? activityType }
    var icon: String { type?.icon ?? "bell.fill" }
    var color: String { type?.color ?? "feedingColor" }
}

enum ActivityReminderSettings {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard
    private static let key = "activityReminderRules"

    static let defaultRules: [ActivityReminderRule] = [
        ActivityReminderRule(activityType: "feeding_breast", enabled: true, intervalMinutes: 180),
        ActivityReminderRule(activityType: "feeding_bottle", enabled: true, intervalMinutes: 180),
        ActivityReminderRule(activityType: "feeding_solid", enabled: false, intervalMinutes: 240),
        ActivityReminderRule(activityType: "feeding_snack", enabled: false, intervalMinutes: 180),
        ActivityReminderRule(activityType: "sleep", enabled: false, intervalMinutes: 120),
        ActivityReminderRule(activityType: "diaper_wet", enabled: false, intervalMinutes: 120),
        ActivityReminderRule(activityType: "diaper_dirty", enabled: false, intervalMinutes: 120),
        ActivityReminderRule(activityType: "diaper_both", enabled: false, intervalMinutes: 120),
        ActivityReminderRule(activityType: "bath", enabled: false, intervalMinutes: 1440),
        ActivityReminderRule(activityType: "medication", enabled: false, intervalMinutes: 480),
    ]

    static var rules: [ActivityReminderRule] {
        get {
            guard let data = defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode([ActivityReminderRule].self, from: data) else {
                return defaultRules
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            }
        }
    }

    static func rule(for type: Activity.ActivityType) -> ActivityReminderRule? {
        rules.first { $0.activityType == type.rawValue }
    }

    static func updateRule(_ updated: ActivityReminderRule) {
        var current = rules
        if let idx = current.firstIndex(where: { $0.activityType == updated.activityType }) {
            current[idx] = updated
        }
        rules = current
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

    // MARK: - Activity Reminder (범용)

    func scheduleActivityReminder(type: Activity.ActivityType, babyName: String, afterMinutes: Int) {
        guard let rule = ActivityReminderSettings.rule(for: type), rule.enabled else { return }

        let identifier = "activity-\(type.rawValue)"

        // 이전 같은 타입 알림 취소 후 새로 예약
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "\(type.displayName) 알림"
        content.body = "\(babyName)의 \(type.displayName) 시간이에요!"
        content.sound = .default
        content.categoryIdentifier = "ACTIVITY_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(afterMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelActivityReminder(type: Activity.ActivityType) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["activity-\(type.rawValue)"])
    }

    // 하위 호환: 기존 feeding-reminder 정리
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
        let daysBefore = NotificationSettings.vaccinationDaysBefore

        for vaccination in vaccinations where !vaccination.isCompleted {
            let scheduledDate = vaccination.scheduledDate

            for days in daysBefore {
                guard let alertDate = Calendar.current.date(byAdding: .day, value: -days, to: scheduledDate),
                      alertDate > Date() else { continue }

                let content = UNMutableNotificationContent()
                let dayText = days == 0 ? "오늘" : days == 1 ? "내일" : "\(days)일 전"
                content.title = "접종 예정 (\(dayText))"
                content.body = "\(babyName)의 \(vaccination.vaccine.displayName) \(vaccination.doseNumber)차 접종이 \(days == 0 ? "오늘" : "\(days)일 후")입니다."
                content.sound = .default
                content.categoryIdentifier = "VACCINATION_REMINDER"

                let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: alertDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "vacc-d\(days)-\(vaccination.id)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }

    func cancelVaccinationReminders(vaccinations: [Vaccination]) {
        let daysBefore = NotificationSettings.vaccinationDaysBefore
        let ids = vaccinations.flatMap { vacc in
            daysBefore.map { "vacc-d\($0)-\(vacc.id)" }
        }
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
