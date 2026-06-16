import Foundation

/// 주간 하이라이트 v2 — Provider / Scoring 파이프라인 + allowlist.
/// 상태(`highlightContext` / `weeklySnapshots`)는 코어가 보유·세팅하고, 여기서는 읽기 + 정적 헬퍼만 둔다.
extension InsightService {

    // MARK: - Weekly Highlights v2 (read)

    /// AppContext 기반 상위 N개 InsightCandidate를 반환합니다.
    ///
    /// - `.empty` / `.pregnancyOnly`: 빈 배열 반환 (임신 전용은 Phase 2 대상)
    /// - `.babyOnly` / `.both`: allowlist 필터 + InsightScoringService.selectTopN
    ///
    /// AppContext switch에 `default:` case 없음 — 4-case 명시 (빌드 58 회귀 방지).
    func topHighlights(for appCtx: AppContext, weights: InsightWeights) -> [InsightCandidate] {
        switch appCtx {
        case .empty:
            return []
        case .pregnancyOnly:
            // Phase 2 대상. 임신 전용 인사이트는 현재 미지원.
            return []
        case .babyOnly, .both:
            break
        }

        guard let ctx = highlightContext else { return [] }

        let allCandidates = InsightService.allCandidates(from: ctx)
        let filtered = InsightService.applyAllowlist(allCandidates)
        let scorer = InsightScorerFactory.make(mode: weights.scorerMode, minSamples: weights.minHistoryWeeks)
        return InsightScoringService.selectTopN(
            filtered,
            scorer: scorer,
            metricHistory: ctx.metricHistory,
            weights: weights
        )
    }

    /// metricKey에 대한 최근 4주 sparkline 데이터를 반환합니다.
    ///
    /// - 빈 데이터 → [] (placeholder 처리는 View 책임)
    /// - 음수 / NaN 제거
    /// - 최대 4주 클램프
    func sparklineData(for metricKey: String) -> [Double] {
        let values = weeklySnapshots
            .prefix(4)
            .compactMap { $0.metrics[metricKey] }
            .filter { $0 >= 0 && !$0.isNaN }
        return Array(values)
    }

    // MARK: - Allowlist (private)

    /// feeding / sleep / diaper / health prefix만 허용하는 allowlist.
    /// InsightProvider metricKey 형식: "{category}.{sub}" (예: "feeding.count").
    /// 임신 관련 metricKey는 개발 빌드에서 assertionFailure, 릴리즈에서 필터 아웃.
    nonisolated private static let allowedMetricKeyPrefixes: Set<String> = [
        "feeding_", "feeding.",
        "sleep_",   "sleep.",
        "diaper_",  "diaper.",
        "health_",  "health."
    ]

    /// candidates를 allowlist로 필터링합니다.
    /// `pregnancy_` prefix 탐지 시 debug assert + filter out.
    private static func applyAllowlist(_ candidates: [InsightCandidate]) -> [InsightCandidate] {
        return candidates.filter { c in
            if c.metricKey.hasPrefix("pregnancy_") {
                assertionFailure("InsightService: pregnancy_ metricKey는 topHighlights에 포함될 수 없습니다. metricKey=\(c.metricKey)")
                return false
            }
            return allowedMetricKeyPrefixes.contains { c.metricKey.hasPrefix($0) }
        }
    }

    /// 4개 카테고리 Provider에서 후보를 모두 수집합니다.
    private static func allCandidates(from ctx: InsightContext) -> [InsightCandidate] {
        let providers: [InsightProvider.Type] = [
            FeedingInsightProvider.self,
            DiaperInsightProvider.self,
            SleepInsightProvider.self,
            HealthInsightProvider.self
        ]
        return providers.flatMap { $0.candidates(ctx) }
    }
}
