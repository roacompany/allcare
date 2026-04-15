import Foundation

// MARK: - Monthly Mood Distribution

struct MonthlyMoodDistribution: Identifiable, Codable, Hashable {
    var id: String { "\(year)-\(month)" }
    var year: Int
    var month: Int
    var totalEntries: Int
    var moodCounts: [String: Int]       // mood rawValue → count
    var writtenDays: Int                // 일기 작성 일수
    var averageContentLength: Double    // 평균 글자 수

    /// 특정 기분의 비율 (0~1)
    func ratio(for mood: String) -> Double {
        guard totalEntries > 0 else { return 0 }
        return Double(moodCounts[mood] ?? 0) / Double(totalEntries)
    }

    /// 가장 많이 기록된 기분
    var dominantMood: String? {
        moodCounts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Throwback Entry

struct ThrowbackEntry: Identifiable, Codable, Hashable {
    var id: String
    var monthsAgo: Int           // 1, 3, 6, 12
    var entry: DiaryEntry
}

// MARK: - Mood Trend

struct MoodTrend: Identifiable, Codable, Hashable {
    var id: String { "\(year)-\(month)-\(mood)" }
    var year: Int
    var month: Int
    var mood: String             // DiaryEntry.Mood rawValue
    var count: Int
    var ratio: Double            // 0~1

    /// 레이블용 월 문자열 (예: "3월")
    var monthLabel: String {
        "\(month)월"
    }
}
