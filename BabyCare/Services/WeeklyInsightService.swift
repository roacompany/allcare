import Foundation

/// 주간 패턴 리포트에서 핵심 인사이트를 추출하는 정적 유틸리티 서비스
enum WeeklyInsightService {

    // MARK: - Types

    enum InsightCategory: String {
        case feeding = "feeding"
        case sleep = "sleep"
        case diaper = "diaper"
    }

    struct Insight: Identifiable {
        let id = UUID()
        let category: InsightCategory
        let title: String
        let detail: String
        let changePercent: Double?
        let trend: Trend
    }

    // MARK: - Public API

    /// PatternReport에서 주간 인사이트 최대 3개를 추출합니다.
    /// previous 값이 없는 카테고리는 제외되며, 변화율 절대값 기준 내림차순으로 반환합니다.
    static func generateInsights(from report: PatternReport) -> [Insight] {
        var candidates: [(insight: Insight, absChange: Double)] = []

        // 1. Feeding
        if let prev = report.feeding.previousDailyAverage, prev > 0 {
            let current = report.feeding.dailyAverage
            let changePercent = (current - prev) / prev * 100
            let insight = makeInsight(
                category: .feeding,
                current: current,
                previous: prev,
                changePercent: changePercent,
                unit: "회"
            )
            candidates.append((insight, abs(changePercent)))
        }

        // 2. Sleep
        if let prev = report.sleep.previousDailyAverageHours, prev > 0 {
            let current = report.sleep.dailyAverageHours
            let changePercent = (current - prev) / prev * 100
            let insight = makeInsight(
                category: .sleep,
                current: current,
                previous: prev,
                changePercent: changePercent,
                unit: "시간"
            )
            candidates.append((insight, abs(changePercent)))
        }

        // 3. Diaper
        if let prev = report.diaper.previousDailyAverage, prev > 0 {
            let current = report.diaper.dailyAverage
            let changePercent = (current - prev) / prev * 100
            let insight = makeInsight(
                category: .diaper,
                current: current,
                previous: prev,
                changePercent: changePercent,
                unit: "회"
            )
            candidates.append((insight, abs(changePercent)))
        }

        // 변화율 절대값 기준 내림차순 정렬 후 상위 3개 반환
        return candidates
            .sorted { $0.absChange > $1.absChange }
            .prefix(3)
            .map(\.insight)
    }

    // MARK: - Private Helpers

    private static func makeInsight(
        category: InsightCategory,
        current: Double,
        previous: Double,
        changePercent: Double,
        unit: String
    ) -> Insight {
        let isStable = abs(changePercent) < 5
        let trend: Trend = isStable ? .stable : (changePercent > 0 ? .increasing : .decreasing)

        let categoryName: String
        switch category {
        case .feeding: categoryName = "수유 횟수"
        case .sleep:   categoryName = "수면 시간"
        case .diaper:  categoryName = "배변 횟수"
        }

        let title: String
        if isStable {
            title = "\(categoryName) 안정화"
        } else {
            let absPercent = Int(abs(changePercent).rounded())
            let directionWord = changePercent > 0 ? "증가" : "감소"
            title = "\(categoryName) \(absPercent)% \(directionWord)"
        }

        let detail = "일 평균 \(String(format: "%.1f", previous))\(unit) → \(String(format: "%.1f", current))\(unit) (전주 대비)"

        return Insight(
            category: category,
            title: title,
            detail: detail,
            changePercent: changePercent,
            trend: trend
        )
    }
}
