import Foundation

/// 수유 예측 로직을 담당하는 정적 유틸리티 서비스
/// ActivityViewModel의 복잡도를 낮추고 독립적 테스트를 가능하게 함
enum FeedingPredictionService {

    // MARK: - Average Interval

    /// 최근 수유 기록을 기반으로 평균 수유 간격을 계산합니다.
    ///
    /// - Parameters:
    ///   - todayActivities: 오늘의 전체 활동 기록
    ///   - recentActivities: 최근 7일 수유 활동 기록 (오늘 제외)
    ///   - babyAgeInMonths: 아기 월령 (데이터 부족 시 기본값 산출에 사용)
    /// - Returns: 평균 수유 간격 (초)
    static func averageInterval(
        todayActivities: [Activity],
        recentActivities: [Activity],
        babyAgeInMonths: Int
    ) -> TimeInterval {
        // 최근 7일 + 오늘 데이터 합산 (중복 제거)
        let allFeedings = (recentActivities + todayActivities)
            .filter { $0.type.category == .feeding }
            .sorted { $0.startTime < $1.startTime }
        var seen = Set<String>()
        let unique = allFeedings.filter { seen.insert($0.id).inserted }

        guard unique.count >= 2 else {
            // 데이터 부족 시 월령별 기본값 사용
            return AppConstants.feedingIntervalHours(ageInMonths: babyAgeInMonths) * 3600
        }

        var intervals: [TimeInterval] = []
        for i in 1..<unique.count {
            let gap = unique[i].startTime.timeIntervalSince(unique[i-1].startTime)
            // 야간 gap (6시간 이상) 제외 — 낮 수유 패턴만 반영
            if gap > 0 && gap < 21600 {
                intervals.append(gap)
            }
        }

        guard !intervals.isEmpty else {
            return AppConstants.feedingIntervalHours(ageInMonths: babyAgeInMonths) * 3600
        }
        return intervals.reduce(0, +) / Double(intervals.count)
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
    /// - Parameter estimate: 다음 수유 예상 시각
    /// - Returns: 표시용 문자열, estimate가 nil이면 nil
    static func predictionText(estimate: Date?) -> String? {
        guard let estimate = estimate else { return nil }
        let now = Date()
        if estimate <= now {
            let overdue = now.timeIntervalSince(estimate)
            let overdueMins = Int(overdue / 60)
            if overdueMins > 30 {
                return "수유 시간이 \(overdueMins)분 지났어요"
            }
            return "곧 수유 시간이에요"
        }
        let remaining = estimate.timeIntervalSince(now)
        let minutes = Int(remaining / 60)
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "약 \(hours)시간 \(mins)분 후"
        }
        return "약 \(mins)분 후"
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
