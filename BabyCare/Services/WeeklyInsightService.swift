import Foundation

/// 주간 패턴 리포트에서 핵심 인사이트를 추출하는 정적 유틸리티 서비스.
/// v3 (Phase 1 ML): Provider + Scoring 파이프라인 + per-baby Z-score scorer.
/// RC 가중치 + scorer mode 외부화. cold-start 시 Heuristic fallback.
enum WeeklyInsightService {

    // MARK: - Types

    /// UI 표시용 단일 인사이트. 외부 시그니처 유지.
    struct Insight: Identifiable {
        let id = UUID()
        let category: InsightCategory
        /// 디버깅/Analytics용 (예: "feeding.volume").
        let metricKey: String
        let title: String
        let detail: String
        let changePercent: Double?
        let trend: Trend
        /// 이번 주 metric 값. WeeklyMetricSnapshot 저장 시 사용.
        let currentValue: Double
    }

    // MARK: - Public API

    /// 주간 패턴 리포트 + 전주 활동 + history를 받아 top N 인사이트 생성.
    /// - Parameters:
    ///   - report: 현재 주 PatternReport
    ///   - previousActivities: 전주 raw activities
    ///   - previousDays: 전주 데이터 일 수
    ///   - currentDays: 현재 주 데이터 일 수
    ///   - metricHistory: 같은 babyId의 metric별 과거 주차 값 (최신→과거).
    ///     비어있어도 hybrid scorer가 heuristic으로 fallback.
    static func generateInsights(
        from report: PatternReport,
        previousActivities: [Activity],
        previousDays: Int,
        currentDays: Int,
        metricHistory: [String: [Double]] = [:]
    ) -> [Insight] {
        let weights = InsightWeights.fromRC()
        let ctx = InsightContext(
            current: report,
            previousActivities: previousActivities,
            previousDays: previousDays,
            weights: weights,
            currentDays: currentDays,
            metricHistory: metricHistory
        )
        let providers: [InsightProvider.Type] = [
            FeedingInsightProvider.self,
            DiaperInsightProvider.self,
            SleepInsightProvider.self,
            HealthInsightProvider.self
        ]
        let candidates = providers.flatMap { $0.candidates(ctx) }
        let scorer = InsightScorerFactory.make(mode: weights.scorerMode, minSamples: weights.minHistoryWeeks)
        let topN = InsightScoringService.selectTopN(candidates, scorer: scorer, metricHistory: metricHistory, weights: weights)
        return topN.map { Self.toInsight($0) }
    }

    /// 이번 주 metric 값을 metric_key 사전으로 직접 추출.
    /// `WeeklyMetricSnapshot.metrics` 구성 + Phase 2 ML 학습 입력.
    /// Provider는 비교용 (prev > 0 가드)이라 첫 주처럼 prev=0인 경우 candidate를 안 만들기 때문에
    /// 별도 추출. metric key는 Provider와 동일하게 유지 (history 매칭).
    static func snapshotMetrics(
        from report: PatternReport,
        previousActivities: [Activity],
        previousDays: Int,
        currentDays: Int
    ) -> [String: Double] {
        var out: [String: Double] = [:]
        // Feeding
        out["feeding.count"] = report.feeding.dailyAverage
        out["feeding.volume"] = report.feeding.dailyMlAverage
        if let interval = report.feeding.averageInterval, interval > 0 {
            out["feeding.interval"] = interval / 3600  // hours
        }
        // Diaper
        let curDays = max(1, currentDays)
        let curWet = report.diaper.wetVsDirtyRatio.wet + report.diaper.wetVsDirtyRatio.both
        let curDirty = report.diaper.wetVsDirtyRatio.dirty + report.diaper.wetVsDirtyRatio.both
        out["diaper.wet"] = Double(curWet) / Double(curDays)
        out["diaper.dirty"] = Double(curDirty) / Double(curDays)
        // Sleep
        out["sleep.hours"] = report.sleep.dailyAverageHours
        let totalQuality = report.sleep.qualityDistribution.values.reduce(0, +)
        if totalQuality > 0 {
            let good = report.sleep.qualityDistribution[.good] ?? 0
            out["sleep.quality"] = Double(good) / Double(totalQuality) * 100
        }
        // Health
        out["health.fever"] = Double(report.health.highTempDays)
        out["health.medication"] = Double(report.health.medicationCount)
        return out
    }

    /// 주차별 스냅샷 배열을 metric_key별 시계열로 변환 (최신→과거 보존).
    static func metricHistory(from snapshots: [WeeklyMetricSnapshot]) -> [String: [Double]] {
        var out: [String: [Double]] = [:]
        for snap in snapshots {
            for (key, value) in snap.metrics {
                out[key, default: []].append(value)
            }
        }
        return out
    }

    // MARK: - Conversion

    private static func toInsight(_ c: InsightCandidate) -> Insight {
        Insight(
            category: c.category,
            metricKey: c.metricKey,
            title: c.title,
            detail: c.detail,
            changePercent: c.changePercent,
            trend: c.trend,
            currentValue: c.currentValue
        )
    }
}
