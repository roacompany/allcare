import Foundation
import UserNotifications

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

    static var temperatureTrendEnabled: Bool {
        get { defaults.object(forKey: "temperatureTrendEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "temperatureTrendEnabled") }
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
