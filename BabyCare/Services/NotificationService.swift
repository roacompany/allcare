import Foundation
import UserNotifications

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

    // MARK: - Hospital Visit Reminder (D-1)

    func scheduleHospitalVisitReminder(visit: HospitalVisit, babyName: String) {
        let targetDate = visit.scheduledDate ?? visit.visitDate
        guard targetDate > Date(),
              let alertDate = Calendar.current.date(byAdding: .day, value: -1, to: targetDate),
              alertDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "내일 병원 방문 예정"
        content.body = "\(babyName) · \(visit.hospitalName) 방문이 내일입니다."
        content.sound = .default
        content.categoryIdentifier = "HOSPITAL_REMINDER"

        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: alertDate
        )
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "hospital-d1-\(visit.id)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelHospitalVisitReminder(visitId: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["hospital-d1-\(visitId)"])
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
