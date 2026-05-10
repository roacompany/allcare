import Foundation

/// 후보 candidate를 sort + filter + top N 선택. 무상태(stateless) 정적 유틸.
enum InsightScoringService {

    /// 단일 candidate 스코어. 변화율 절대값 × medicalWeight × sampleSize 정규화 (0~1).
    static func score(_ c: InsightCandidate) -> Double {
        let normalizedSample = min(Double(c.sampleSize) / 7.0, 1.0)
        return abs(c.changePercent) * c.medicalWeight * normalizedSample
    }

    /// 전체 candidate를 합쳐 top N 선택.
    /// - filter: |changePercent| ≥ weights.minChangePct
    /// - sort: score desc
    /// - take: weights.maxCount
    static func selectTopN(_ candidates: [InsightCandidate], weights: InsightWeights) -> [InsightCandidate] {
        return candidates
            .filter { abs($0.changePercent) >= weights.minChangePct }
            .sorted { score($0) > score($1) }
            .prefix(weights.maxCount)
            .map { $0 }
    }
}
