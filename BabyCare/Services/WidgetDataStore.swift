import Foundation
import WidgetKit

/// 위젯 전용 경량 활동 모델 (Firebase 의존 없음, JSON 직렬화).
struct WidgetActivity: Codable {
    let typeRaw: String       // "feeding_breast" 등
    let displayName: String   // "모유수유"
    let icon: String          // SF Symbol
    let colorHex: String      // "#FF9FB5"
    let startTime: Date
    let detail: String?       // "15분", "120ml" 등
}

/// 메인 앱과 위젯 간 데이터 공유용 UserDefaults wrapper.
enum WidgetDataStore {
    private static let suiteName: String? = "group.com.roacompany.allcare"

    private static var defaults: UserDefaults {
        if let suiteName, let shared = UserDefaults(suiteName: suiteName) {
            return shared
        }
        return .standard
    }

    // MARK: - Keys

    private enum Keys {
        static let babyName = "widget_babyName"
        static let babyAge = "widget_babyAge"
        static let lastFeedingTime = "widget_lastFeedingTime"
        static let lastFeedingType = "widget_lastFeedingType"
        static let lastSleepTime = "widget_lastSleepTime"
        static let lastDiaperTime = "widget_lastDiaperTime"
        static let feedingIntervalMinutes = "widget_feedingIntervalMinutes"
        // Phase 1 확장
        static let todayFeedingCount = "widget_todayFeedingCount"
        static let todaySleepMinutes = "widget_todaySleepMinutes"
        static let todayDiaperCount = "widget_todayDiaperCount"
        static let todayTotalMl = "widget_todayTotalMl"
        static let recentActivities = "widget_recentActivities"
        static let lastSleepDuration = "widget_lastSleepDuration"
    }

    // MARK: - Write (from main app)

    static func update(
        babyName: String,
        babyAge: String,
        lastFeeding: Date?,
        lastFeedingType: String?,
        lastSleep: Date?,
        lastDiaper: Date?,
        feedingIntervalMinutes: Int,
        todayFeedingCount: Int = 0,
        todaySleepMinutes: Int = 0,
        todayDiaperCount: Int = 0,
        todayTotalMl: Double = 0,
        recentActivities: [WidgetActivity] = [],
        lastSleepDuration: String? = nil
    ) {
        defaults.set(babyName, forKey: Keys.babyName)
        defaults.set(babyAge, forKey: Keys.babyAge)
        defaults.set(lastFeeding, forKey: Keys.lastFeedingTime)
        defaults.set(lastFeedingType, forKey: Keys.lastFeedingType)
        defaults.set(lastSleep, forKey: Keys.lastSleepTime)
        defaults.set(lastDiaper, forKey: Keys.lastDiaperTime)
        defaults.set(feedingIntervalMinutes, forKey: Keys.feedingIntervalMinutes)
        // 확장 데이터
        defaults.set(todayFeedingCount, forKey: Keys.todayFeedingCount)
        defaults.set(todaySleepMinutes, forKey: Keys.todaySleepMinutes)
        defaults.set(todayDiaperCount, forKey: Keys.todayDiaperCount)
        defaults.set(todayTotalMl, forKey: Keys.todayTotalMl)
        defaults.set(lastSleepDuration, forKey: Keys.lastSleepDuration)

        if let data = try? JSONEncoder().encode(recentActivities) {
            defaults.set(data, forKey: Keys.recentActivities)
        }

        // 위젯 즉시 갱신
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Read (from widget)

    static var babyName: String {
        defaults.string(forKey: Keys.babyName) ?? "아기"
    }

    static var babyAge: String {
        defaults.string(forKey: Keys.babyAge) ?? ""
    }

    static var lastFeedingTime: Date? {
        defaults.object(forKey: Keys.lastFeedingTime) as? Date
    }

    static var lastFeedingType: String? {
        defaults.string(forKey: Keys.lastFeedingType)
    }

    static var lastSleepTime: Date? {
        defaults.object(forKey: Keys.lastSleepTime) as? Date
    }

    static var lastDiaperTime: Date? {
        defaults.object(forKey: Keys.lastDiaperTime) as? Date
    }

    static var feedingIntervalMinutes: Int {
        let val = defaults.integer(forKey: Keys.feedingIntervalMinutes)
        return val > 0 ? val : 180
    }

    static var nextFeedingTime: Date? {
        guard let last = lastFeedingTime else { return nil }
        return last.addingTimeInterval(Double(feedingIntervalMinutes) * 60)
    }

    // 확장 읽기 프로퍼티

    static var todayFeedingCount: Int {
        defaults.integer(forKey: Keys.todayFeedingCount)
    }

    static var todaySleepMinutes: Int {
        defaults.integer(forKey: Keys.todaySleepMinutes)
    }

    static var todayDiaperCount: Int {
        defaults.integer(forKey: Keys.todayDiaperCount)
    }

    static var todayTotalMl: Double {
        defaults.double(forKey: Keys.todayTotalMl)
    }

    static var lastSleepDuration: String? {
        defaults.string(forKey: Keys.lastSleepDuration)
    }

    static var recentActivities: [WidgetActivity] {
        guard let data = defaults.data(forKey: Keys.recentActivities),
              let activities = try? JSONDecoder().decode([WidgetActivity].self, from: data) else {
            return []
        }
        return activities
    }
}
