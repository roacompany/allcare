import Foundation
import UserNotifications

/// 폰 안 알림 하나 — 무엇을 언제(설계서 §9).
struct TripReminder: Hashable, Sendable {
    let identifier: String
    let fireAt: Date
    let title: String
    let body: String
}

/// 여행 마감 알림을 거는 쪽 — 뷰모델이 이 면에만 의존한다(테스트는 목으로).
@MainActor
protocol TripReminderScheduling: AnyObject {
    /// 그 여행의 대기 중인 알림(trip-<id>- 로 시작)을 전부 지우고 새로 건다.
    func replaceTripReminders(tripId: String, with reminders: [TripReminder]) async
    func cancelTripReminders(tripId: String) async
    /// 모든 여행에서 한 종류(d3 · d1)를 지운다 — 알림 끄기는 이 폰의 모든 여행에 적용된다.
    func cancelTripReminders(kindSuffix: String) async
}

/// 알림 두 가지를 각각 켜고 끄기(준비 칸 · 이 폰에만).
struct TripReminderOptions: Hashable, Sendable {
    var threeDaysBefore = true
    var dayBefore = true

    static let all = TripReminderOptions()
}

/// 이 폰의 여행 알림 켜고 끄기 — 기기 설정이라 사용자 기록과 따로 둔다(뷰모델이 이 면에만 의존).
@MainActor
protocol TripReminderPreferencesStoring: AnyObject {
    var options: TripReminderOptions { get set }
}

@MainActor
final class TripReminderPreferences: TripReminderPreferencesStoring {
    static let shared = TripReminderPreferences()

    nonisolated static let threeDaysBeforeKey = "travel.reminder.threeDaysBefore"
    nonisolated static let dayBeforeKey = "travel.reminder.dayBefore"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 저장한 적이 없으면 켜짐.
    var options: TripReminderOptions {
        get {
            TripReminderOptions(threeDaysBefore: defaults.object(forKey: Self.threeDaysBeforeKey) as? Bool ?? true,
                                dayBefore: defaults.object(forKey: Self.dayBeforeKey) as? Bool ?? true)
        }
        set {
            defaults.set(newValue.threeDaysBefore, forKey: Self.threeDaysBeforeKey)
            defaults.set(newValue.dayBefore, forKey: Self.dayBeforeKey)
        }
    }
}

/// 안 끝난 할 일의 마감마다 3일 전 · 전날 09:00 — 순수 함수.
enum TripReminderPlanner {
    nonisolated static let fireHour = 9
    nonisolated static let categoryIdentifier = "TRIP_DEADLINE"
    nonisolated static let threeDaysBeforeSuffix = "d3"
    nonisolated static let dayBeforeSuffix = "d1"

    static func identifierPrefix(tripId: String) -> String { "trip-\(tripId)-" }

    static func reminders(trip: Trip, tasks: [TripTask], states: [TripTaskState], now: Date, calendar: Calendar,
                          options: TripReminderOptions = .all) -> [TripReminder] {
        let done = Set(states.filter(\.isDone).map(\.taskId))
        let prefix = identifierPrefix(tripId: trip.id)
        var steps: [(suffix: String, daysBefore: Int, title: String)] = []
        if options.threeDaysBefore { steps.append((threeDaysBeforeSuffix, 3, "여행 마감 3일 전")) }
        if options.dayBefore { steps.append((dayBeforeSuffix, 1, "여행 마감 내일")) }
        var result: [TripReminder] = []
        for task in tasks where !done.contains(task.id) {
            for (index, deadline) in task.deadlines.enumerated() {
                let body = "\(task.title) · \(deadline.label) \(deadline.text(calendar: calendar))까지"
                for step in steps {
                    guard let day = calendar.date(byAdding: .day, value: -step.daysBefore, to: calendar.startOfDay(for: deadline.at)),
                          let fire = calendar.date(bySettingHour: fireHour, minute: 0, second: 0, of: day),
                          fire > now else { continue }
                    result.append(TripReminder(identifier: "\(prefix)\(task.id)-\(index)-\(step.suffix)",
                                               fireAt: fire, title: step.title, body: body))
                }
            }
        }
        return result.sorted { $0.fireAt < $1.fireAt }
    }
}

extension NotificationService: TripReminderScheduling {
    func replaceTripReminders(tripId: String, with reminders: [TripReminder]) async {
        await cancelTripReminders(tripId: tripId)
        let center = UNUserNotificationCenter.current()
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.categoryIdentifier = TripReminderPlanner.categoryIdentifier
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireAt)
            let request = UNNotificationRequest(identifier: reminder.identifier, content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            do {
                try await center.add(request)
            } catch {
                logSilent("여행 마감 알림 등록 실패", error: error, logger: AppLogger.travel)
            }
        }
    }

    func cancelTripReminders(tripId: String) async {
        let center = UNUserNotificationCenter.current()
        let prefix = TripReminderPlanner.identifierPrefix(tripId: tripId)
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelTripReminders(kindSuffix: String) async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix("trip-") && $0.hasSuffix("-\(kindSuffix)") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
