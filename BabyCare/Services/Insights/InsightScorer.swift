import Foundation

// MARK: - InsightScorer

/// 단일 candidate에 대한 score 계산. Phase 2/3에서 CoreML scorer 등으로 swap 가능한 인터페이스.
///
/// 입력:
/// - candidate: Provider가 만들어낸 후보 (currentValue 포함)
/// - history: 같은 metricKey의 과거 주차 값 배열 (최신 → 과거 순서)
/// - weights: RC에서 가져온 medicalWeight + threshold
///
/// 출력: 비음수 점수. 클수록 surface 우선.
protocol InsightScorer {
    func score(_ candidate: InsightCandidate, history: [Double], weights: InsightWeights) -> Double
}

// MARK: - Mode

/// RC `insight_scorer_mode` 값 매핑. 알 수 없는 값은 hybrid fallback.
enum InsightScorerMode: String {
    /// 기존 |Δ%| × medicalWeight × min(sample/7,1.0) 룰만 사용.
    case heuristic
    /// Z-score만 사용 (history 부족 시 candidate 제외).
    case anomaly
    /// history >= minSamples면 anomaly, 아니면 heuristic. 신규 사용자 회귀 0.
    case hybrid

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "heuristic": self = .heuristic
        case "anomaly": self = .anomaly
        case "hybrid", "": self = .hybrid
        default: self = .hybrid
        }
    }
}

// MARK: - Heuristic

/// v2 (Phase 0) 규칙 기반 scorer. 콜드스타트(history 부족) 시 fallback.
struct HeuristicScorer: InsightScorer {
    func score(_ c: InsightCandidate, history: [Double], weights: InsightWeights) -> Double {
        let normalizedSample = min(Double(c.sampleSize) / 7.0, 1.0)
        return abs(c.changePercent) * c.medicalWeight * normalizedSample
    }
}

// MARK: - Statistical Anomaly

/// per-baby Z-score 기반 scorer. "이 아기에겐 평소와 다름"을 surface.
///
/// score = |zScore| × medicalWeight
/// zScore = (currentValue - mean(history)) / std(history)
///
/// 통계적 유의미성:
/// - history.count < minSamples → 0 (호출자에서 fallback 결정)
/// - std == 0 (값이 항상 동일) → 변화율을 fallback 시그널로 사용
struct StatisticalAnomalyScorer: InsightScorer {
    /// 통계적으로 의미 있는 Z-score 계산을 위한 최소 샘플 수.
    let minSamples: Int

    init(minSamples: Int = 4) {
        self.minSamples = minSamples
    }

    func score(_ c: InsightCandidate, history: [Double], weights: InsightWeights) -> Double {
        guard history.count >= minSamples else { return 0 }
        let mean = history.reduce(0, +) / Double(history.count)
        let variance = history.map { pow($0 - mean, 2) }.reduce(0, +) / Double(history.count)
        let std = sqrt(variance)
        guard std > 0 else {
            // 분산 0 = history 전체가 동일값. abnormality는 changePercent 절대값으로 약하게 surface.
            return abs(c.changePercent) * 0.1 * c.medicalWeight
        }
        let zScore = abs(c.currentValue - mean) / std
        return zScore * c.medicalWeight
    }
}

// MARK: - Hybrid

/// history 충분 시 anomaly, 부족 시 heuristic. 신규 사용자 회귀 방지.
struct HybridScorer: InsightScorer {
    let anomaly: StatisticalAnomalyScorer
    let heuristic: HeuristicScorer

    init(minSamples: Int = 4) {
        self.anomaly = StatisticalAnomalyScorer(minSamples: minSamples)
        self.heuristic = HeuristicScorer()
    }

    func score(_ c: InsightCandidate, history: [Double], weights: InsightWeights) -> Double {
        if history.count >= anomaly.minSamples {
            return anomaly.score(c, history: history, weights: weights)
        } else {
            return heuristic.score(c, history: history, weights: weights)
        }
    }
}

// MARK: - Factory

enum InsightScorerFactory {
    static func make(mode: InsightScorerMode, minSamples: Int) -> InsightScorer {
        switch mode {
        case .heuristic: return HeuristicScorer()
        case .anomaly: return StatisticalAnomalyScorer(minSamples: minSamples)
        case .hybrid: return HybridScorer(minSamples: minSamples)
        }
    }
}
