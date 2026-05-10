import Foundation

/// 주간 패턴 리포트에서 핵심 인사이트를 추출하는 정적 유틸리티 서비스.
/// v2: Provider + Scoring 파이프라인. RC 가중치 외부화. 카테고리당 다중 sub-metric 후보.
enum WeeklyInsightService {

    // MARK: - Types

    /// UI 표시용 단일 인사이트. 기존 외부 시그니처 유지.
    struct Insight: Identifiable {
        let id = UUID()
        let category: InsightCategory
        let title: String
        let detail: String
        let changePercent: Double?
        let trend: Trend
    }

    // MARK: - Public API

    /// 주간 패턴 리포트 + 전주 활동을 받아 top N 인사이트 생성.
    /// - Parameters:
    ///   - report: 현재 주 PatternReport (`PatternAnalysisService.analyze` 결과 + 비교)
    ///   - previousActivities: 전주 raw activities (sub-metric 비교용)
    ///   - previousDays: 전주 데이터 일 수 (보통 7)
    ///   - currentDays: 현재 주 데이터 일 수 (보통 7, 부분 주차면 더 작음)
    static func generateInsights(
        from report: PatternReport,
        previousActivities: [Activity],
        previousDays: Int,
        currentDays: Int
    ) -> [Insight] {
        let weights = InsightWeights.fromRC()
        let ctx = InsightContext(
            current: report,
            previousActivities: previousActivities,
            previousDays: previousDays,
            weights: weights,
            currentDays: currentDays
        )
        let providers: [InsightProvider.Type] = [
            FeedingInsightProvider.self,
            DiaperInsightProvider.self,
            SleepInsightProvider.self,
            HealthInsightProvider.self
        ]
        let candidates = providers.flatMap { $0.candidates(ctx) }
        let topN = InsightScoringService.selectTopN(candidates, weights: weights)
        return topN.map { Self.toInsight($0) }
    }

    // MARK: - Conversion

    private static func toInsight(_ c: InsightCandidate) -> Insight {
        Insight(
            category: c.category,
            title: c.title,
            detail: c.detail,
            changePercent: c.changePercent,
            trend: c.trend
        )
    }
}
