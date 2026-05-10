import Foundation

// MARK: - InsightCategory

/// 주간 인사이트 카테고리. WeeklyInsightService.Insight와 호환 (UI 색상/아이콘 매핑 유지).
enum InsightCategory: String {
    case feeding
    case sleep
    case diaper
    case health
}

// MARK: - InsightCandidate

/// Provider가 만들어낸 후보. Scorer가 sort + filter + top N 선택.
struct InsightCandidate {
    let category: InsightCategory
    /// 디버깅/RC 가중치 매칭용 (예: "feeding.count", "feeding.volume", "diaper.wet").
    let metricKey: String
    let title: String
    let detail: String
    /// 변화율 (전주 대비). 양수=증가, 음수=감소, 0=stable.
    let changePercent: Double
    let trend: Trend
    /// RC weights에서 가져온 medicalWeight (기본 1.0).
    let medicalWeight: Double
    /// 통계적 유의미성 보정용 (현재 주 데이터 일 수 — 0~7).
    let sampleSize: Int
}

// MARK: - InsightContext

/// Provider 입력. 현재 주 PatternReport + 비교용 전주 활동 + RC 가중치.
struct InsightContext {
    let current: PatternReport
    let previousActivities: [Activity]
    let previousDays: Int
    let weights: InsightWeights
    /// 현재 주 계산에 사용된 일수 (sampleSize 정규화용).
    let currentDays: Int
}

// MARK: - InsightProvider

/// 카테고리별 후보 generator. enum (정적 메서드)로 구현하면 의존성 주입 단순.
protocol InsightProvider {
    static func candidates(_ ctx: InsightContext) -> [InsightCandidate]
}
