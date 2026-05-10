import Foundation

/// 후보 candidate를 sort + filter + top N 선택. RC scorer mode 디스패치.
///
/// Phase 1: HeuristicScorer / StatisticalAnomalyScorer / HybridScorer 중 RC 선택.
/// Phase 2: CoreML scorer 추가 시 InsightScorerFactory에 case 추가만으로 swap.
enum InsightScoringService {

    /// 단일 candidate 스코어. 외부 호출용 (테스트/디버깅). 내부는 selectTopN가 묶어 처리.
    static func score(_ c: InsightCandidate, scorer: InsightScorer, history: [Double], weights: InsightWeights) -> Double {
        scorer.score(c, history: history, weights: weights)
    }

    /// 전체 candidate를 합쳐 top N 선택.
    /// - filter: |changePercent| ≥ weights.minChangePct
    /// - sort: scorer.score(c, history) desc
    /// - take: weights.maxCount
    static func selectTopN(
        _ candidates: [InsightCandidate],
        scorer: InsightScorer,
        metricHistory: [String: [Double]],
        weights: InsightWeights
    ) -> [InsightCandidate] {
        return candidates
            .filter { abs($0.changePercent) >= weights.minChangePct }
            .map { ($0, scorer.score($0, history: metricHistory[$0.metricKey] ?? [], weights: weights)) }
            .sorted { $0.1 > $1.1 }
            .prefix(weights.maxCount)
            .map { $0.0 }
    }
}
