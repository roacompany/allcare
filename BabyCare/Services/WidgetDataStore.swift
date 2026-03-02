import Foundation

/// 메인 앱과 위젯 간 데이터 공유용 UserDefaults wrapper.
/// App Group 설정 후 suiteName을 변경해야 함.
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
    }

    // MARK: - Write (from main app)

    static func update(
        babyName: String,
        babyAge: String,
        lastFeeding: Date?,
        lastFeedingType: String?,
        lastSleep: Date?,
        lastDiaper: Date?,
        feedingIntervalMinutes: Int
    ) {
        defaults.set(babyName, forKey: Keys.babyName)
        defaults.set(babyAge, forKey: Keys.babyAge)
        defaults.set(lastFeeding, forKey: Keys.lastFeedingTime)
        defaults.set(lastFeedingType, forKey: Keys.lastFeedingType)
        defaults.set(lastSleep, forKey: Keys.lastSleepTime)
        defaults.set(lastDiaper, forKey: Keys.lastDiaperTime)
        defaults.set(feedingIntervalMinutes, forKey: Keys.feedingIntervalMinutes)
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
}
