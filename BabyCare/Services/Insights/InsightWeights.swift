import Foundation
import FirebaseRemoteConfig

// MARK: - InsightWeights

/// 인사이트 후보 스코어링 가중치. RC 외부화 + 인라인 기본값 fallback.
/// fetch 실패해도 default 값으로 정상 동작 (A-18 invariant 동일 패턴).
struct InsightWeights {
    let feedingCount: Double
    let feedingVolume: Double
    let feedingInterval: Double
    let diaperWet: Double
    let diaperDirty: Double
    let sleepHours: Double
    let sleepQuality: Double
    let healthFever: Double
    let healthMedication: Double
    /// 최소 변화율 (% 절대값). 미만이면 candidate 제외.
    let minChangePct: Double
    /// 최종 노출 카드 수.
    let maxCount: Int
    /// 인사이트 스코어 모드 (heuristic / anomaly / hybrid).
    let scorerMode: InsightScorerMode
    /// anomaly scorer 활성 최소 history 주차.
    let minHistoryWeeks: Int
    /// fetch 윈도우 (최근 N주 history 로드).
    let historyWeeks: Int

    static let `default` = InsightWeights(
        feedingCount: 1.0,
        feedingVolume: 1.2,
        feedingInterval: 0.7,
        diaperWet: 0.8,
        diaperDirty: 1.5,
        sleepHours: 1.0,
        sleepQuality: 1.0,
        healthFever: 2.0,
        healthMedication: 1.5,
        minChangePct: 5,
        maxCount: 3,
        scorerMode: .hybrid,
        minHistoryWeeks: 4,
        historyWeeks: 8
    )

    /// RemoteConfig에서 가중치 로드. 호출자가 fetchAndActivate 후 동기 호출.
    /// 키가 없거나 값이 0 이하면 default 사용 (보호적).
    static func fromRC() -> InsightWeights {
        let rc = RemoteConfig.remoteConfig()
        func d(_ key: String, _ fallback: Double) -> Double {
            let v = rc.configValue(forKey: key).numberValue.doubleValue
            return v > 0 ? v : fallback
        }
        func i(_ key: String, _ fallback: Int) -> Int {
            let v = rc.configValue(forKey: key).numberValue.intValue
            return v > 0 ? v : fallback
        }
        let modeRaw = rc.configValue(forKey: "insight_scorer_mode").stringValue
        return InsightWeights(
            feedingCount: d("weight_feeding_count", Self.default.feedingCount),
            feedingVolume: d("weight_feeding_volume", Self.default.feedingVolume),
            feedingInterval: d("weight_feeding_interval", Self.default.feedingInterval),
            diaperWet: d("weight_diaper_wet", Self.default.diaperWet),
            diaperDirty: d("weight_diaper_dirty", Self.default.diaperDirty),
            sleepHours: d("weight_sleep_hours", Self.default.sleepHours),
            sleepQuality: d("weight_sleep_quality", Self.default.sleepQuality),
            healthFever: d("weight_health_fever", Self.default.healthFever),
            healthMedication: d("weight_health_medication", Self.default.healthMedication),
            minChangePct: d("insight_min_change_pct", Self.default.minChangePct),
            maxCount: i("insight_max_count", Self.default.maxCount),
            scorerMode: InsightScorerMode(rawValue: modeRaw),
            minHistoryWeeks: i("insight_min_history_weeks", Self.default.minHistoryWeeks),
            historyWeeks: i("insight_history_weeks", Self.default.historyWeeks)
        )
    }
}
