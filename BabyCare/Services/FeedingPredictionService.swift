import Foundation

/// 수유 예측 로직을 담당하는 정적 유틸리티 서비스
/// ActivityViewModel의 복잡도를 낮추고 독립적 테스트를 가능하게 함
enum FeedingPredictionService {

    // MARK: - Day/Night Classification

    /// 주어진 시간(0~23)이 낮 시간대인지 판별합니다.
    /// - Parameters:
    ///   - hour: 확인할 시간 (0~23)
    ///   - dayStart: 낮 시작 시간 (기본값 6)
    ///   - dayEnd: 낮 종료 시간 (기본값 22, exclusive)
    /// - Returns: dayStart <= hour < dayEnd 이면 true
    static func isDayHour(_ hour: Int, dayStart: Int = 6, dayEnd: Int = 22) -> Bool {
        hour >= dayStart && hour < dayEnd
    }

    // MARK: - Average Interval

    /// 최근 수유 기록을 기반으로 평균 수유 간격을 계산합니다.
    /// 낮/밤 시간대를 분리하여 현재 시간대에 맞는 평균을 반환합니다.
    ///
    /// - Parameters:
    ///   - todayActivities: 오늘의 전체 활동 기록
    ///   - recentActivities: 최근 7일 수유 활동 기록 (오늘 제외)
    ///   - babyAgeInMonths: 아기 월령 (데이터 부족 시 기본값 산출에 사용)
    /// - Returns: (interval: 평균 수유 간격(초), isPersonalized: 시간대 개인화 여부)
    static func averageInterval(
        todayActivities: [Activity],
        recentActivities: [Activity],
        babyAgeInMonths: Int
    ) -> (interval: TimeInterval, isPersonalized: Bool) {
        // 최근 7일 + 오늘 데이터 합산 (중복 제거)
        let allFeedings = (recentActivities + todayActivities)
            .filter { $0.type.category == .feeding }
            .sorted { $0.startTime < $1.startTime }
        var seen = Set<String>()
        let unique = allFeedings.filter { seen.insert($0.id).inserted }

        let ageFallback = AppConstants.feedingIntervalHours(ageInMonths: babyAgeInMonths) * 3600

        guard unique.count >= 2 else {
            return (ageFallback, false)
        }

        var dayIntervals: [TimeInterval] = []
        var nightIntervals: [TimeInterval] = []
        var allIntervals: [TimeInterval] = []

        for i in 1..<unique.count {
            let feeding = unique[i]
            let gap = feeding.startTime.timeIntervalSince(unique[i - 1].startTime)
            guard gap > 0 else { continue }

            let hour = Calendar.current.component(.hour, from: feeding.startTime)
            if isDayHour(hour) {
                // 낮: 6시간(21600초) 미만 gap만 반영
                if gap < 21600 {
                    dayIntervals.append(gap)
                    allIntervals.append(gap)
                }
            } else {
                // 야간: 12시간(43200초) 미만 gap까지 허용
                if gap < 43200 {
                    nightIntervals.append(gap)
                    allIntervals.append(gap)
                }
            }
        }

        // 현재 시간대 판별
        let currentHour = Calendar.current.component(.hour, from: Date())
        let isCurrentlyDay = isDayHour(currentHour)

        let timeBasedIntervals = isCurrentlyDay ? dayIntervals : nightIntervals

        if timeBasedIntervals.count >= 2 {
            let avg = timeBasedIntervals.reduce(0, +) / Double(timeBasedIntervals.count)
            return (avg, true)
        }

        // 시간대 데이터 부족 → 전체 intervals로 fallback
        if allIntervals.count >= 2 {
            let avg = allIntervals.reduce(0, +) / Double(allIntervals.count)
            return (avg, false)
        }

        // 전체도 부족 → 월령 기반 기본값
        return (ageFallback, false)
    }

    // MARK: - Next Estimate

    /// 마지막 수유 기록과 평균 간격으로 다음 수유 예상 시각을 계산합니다.
    ///
    /// - Parameters:
    ///   - lastFeeding: 가장 최근 수유 기록
    ///   - averageInterval: 평균 수유 간격 (초)
    /// - Returns: 다음 수유 예상 시각, 기록이 없으면 nil
    static func nextEstimate(lastFeeding: Activity?, averageInterval: TimeInterval) -> Date? {
        guard let latest = lastFeeding else { return nil }
        return latest.startTime.addingTimeInterval(averageInterval)
    }

    // MARK: - Prediction Text

    /// 다음 수유 예상 시각을 사람이 읽기 쉬운 문자열로 반환합니다.
    ///
    /// - Parameters:
    ///   - estimate: 다음 수유 예상 시각
    ///   - isPersonalized: true면 " (지난 7일 기준)" suffix 추가
    /// - Returns: 표시용 문자열, estimate가 nil이면 nil
    static func predictionText(estimate: Date?, isPersonalized: Bool = false) -> String? {
        guard let estimate = estimate else { return nil }
        let now = Date()
        let suffix = isPersonalized ? " (지난 7일 기준)" : ""
        if estimate <= now {
            let overdue = now.timeIntervalSince(estimate)
            let overdueMins = Int(overdue / 60)
            if overdueMins > 30 {
                return "수유 시간이 \(overdueMins)분 지났어요\(suffix)"
            }
            return "곧 수유 시간이에요\(suffix)"
        }
        let remaining = estimate.timeIntervalSince(now)
        let minutes = Int(remaining / 60)
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "약 \(hours)시간 \(mins)분 후\(suffix)"
        }
        return "약 \(mins)분 후\(suffix)"
    }

    // MARK: - Overdue Check

    /// 수유 시간이 30분 이상 지났는지 여부를 반환합니다.
    ///
    /// - Parameter estimate: 다음 수유 예상 시각
    /// - Returns: 30분 이상 지났으면 true, 아니면 false
    static func isOverdue(estimate: Date?) -> Bool {
        guard let estimate = estimate else { return false }
        // 30분 이상 지나야 overdue — 불필요한 빨간 경고 방지
        return Date().timeIntervalSince(estimate) > 1800
    }
}
