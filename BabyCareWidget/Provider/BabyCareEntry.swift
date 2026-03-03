import WidgetKit
import Foundation

struct BabyCareEntry: TimelineEntry {
    let date: Date
    let babyName: String
    let babyAge: String

    // 기본 데이터
    let lastFeedingTime: Date?
    let lastFeedingType: String?
    let nextFeedingTime: Date?
    let lastSleepTime: Date?
    let lastDiaperTime: Date?

    // 확장 데이터 (Large 위젯 + 잠금화면용)
    let todayFeedingCount: Int
    let todaySleepMinutes: Int
    let todayDiaperCount: Int
    let todayTotalMl: Double
    let recentActivities: [WidgetActivity]
    let lastSleepDuration: String?
    let feedingIntervalMinutes: Int

    // MARK: - Computed

    var isFeedingOverdue: Bool {
        guard let next = nextFeedingTime else { return false }
        return next < date
    }

    var feedingElapsedMinutes: Int {
        guard let last = lastFeedingTime else { return 0 }
        return max(0, Int(date.timeIntervalSince(last) / 60))
    }

    var feedingProgress: Double {
        guard feedingIntervalMinutes > 0 else { return 0 }
        return min(Double(feedingElapsedMinutes) / Double(feedingIntervalMinutes), 1.5)
    }

    var nextFeedingText: String {
        guard let next = nextFeedingTime else { return "데이터 없음" }
        if next < date { return "수유 시간이 지났어요!" }
        let remaining = Int(next.timeIntervalSince(date) / 60)
        let hours = remaining / 60
        let mins = remaining % 60
        if hours > 0 { return "\(hours)시간 \(mins)분 후" }
        return "\(mins)분 후"
    }

    var feedingElapsedText: String {
        let hours = feedingElapsedMinutes / 60
        let mins = feedingElapsedMinutes % 60
        if hours > 0 { return "\(hours)h\(mins > 0 ? "\(mins)m" : "")" }
        return "\(mins)m"
    }

    var sleepDurationFormatted: String {
        let hours = todaySleepMinutes / 60
        let mins = todaySleepMinutes % 60
        if hours > 0 && mins > 0 { return "\(hours)h\(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }

    // MARK: - Placeholder

    static let placeholder = BabyCareEntry(
        date: Date(),
        babyName: "아기",
        babyAge: "D+100",
        lastFeedingTime: Date().addingTimeInterval(-7200),
        lastFeedingType: "모유수유",
        nextFeedingTime: Date().addingTimeInterval(3600),
        lastSleepTime: Date().addingTimeInterval(-14400),
        lastDiaperTime: Date().addingTimeInterval(-3600),
        todayFeedingCount: 5,
        todaySleepMinutes: 150,
        todayDiaperCount: 8,
        todayTotalMl: 420,
        recentActivities: [],
        lastSleepDuration: "45분",
        feedingIntervalMinutes: 180
    )
}
