import Foundation

/// 주간 metric 스냅샷. 통계적 이상치 탐지(Phase 1) + 미래 ML 학습(Phase 2/3)의 history input.
///
/// Firestore 경로: `users/{uid}/babies/{bid}/weeklyMetrics/{weekKey}`
/// `weekKey` = ISO week (예: "2026W19"). 같은 주 재생성 시 idempotent overwrite.
///
/// metrics 사전 키는 InsightCandidate.metricKey와 1:1 (예: "feeding.count", "diaper.dirty").
struct WeeklyMetricSnapshot: Identifiable, Codable, Hashable {
    /// `weekKey` 와 동일 (Firestore 문서 ID).
    var id: String { weekKey }
    let weekKey: String
    let weekStartDate: Date
    let metrics: [String: Double]
    let createdAt: Date

    init(weekKey: String, weekStartDate: Date, metrics: [String: Double], createdAt: Date = Date()) {
        self.weekKey = weekKey
        self.weekStartDate = weekStartDate
        self.metrics = metrics
        self.createdAt = createdAt
    }

    // MARK: - Week Key

    /// `Date`를 ISO 주차 키로 변환. 예: 2026-05-10 (월요일 시작 주) → "2026W19".
    static func weekKey(for date: Date, calendar: Calendar = .iso8601Calendar) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = components.yearForWeekOfYear ?? 1970
        let week = components.weekOfYear ?? 1
        return String(format: "%04dW%02d", year, week)
    }
}

extension Calendar {
    /// ISO 주차 계산용 캘린더 (월요일 시작, 첫 주 = 1월 4일 포함).
    static let iso8601Calendar: Calendar = {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        cal.firstWeekday = 2  // Monday
        cal.minimumDaysInFirstWeek = 4
        return cal
    }()
}
