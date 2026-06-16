import Foundation

// MARK: - Insight Model

struct DashboardInsight: Identifiable {
    let id = UUID()
    let kind: Kind
    let icon: String
    let colorName: String
    let primaryText: String
    let secondaryText: String?

    enum Kind {
        case feeding
        case sleep
        case health
        case milestone
        case vaccination
    }
}

// MARK: - InsightService

/// 대시보드 컨텍스트 인사이트 카드 4종을 생성하는 단일 책임 서비스.
/// Views → Services 직접 참조 금지 원칙에 따라 ViewModel을 통해서만 노출됨.
///
/// 구현은 관심사별 extension 으로 분리한다 (상태와 setter 는 본 코어가 보유):
/// - `InsightService+Cards.swift`: 대시보드 카드 빌더(재구매/수유/수면/건강/마일스톤/접종/수면퇴행) + helper
/// - `InsightService+Highlights.swift`: 주간 하이라이트 v2(topHighlights/sparklineData/allowlist)
@MainActor @Observable
final class InsightService {

    // MARK: - Published State

    private(set) var insights: [DashboardInsight] = []

    // MARK: - Highlight Context (Weekly Highlights v2)

    /// 최근 업데이트된 InsightContext. topHighlights / sparklineData 계산에 사용.
    /// refreshHighlightContext(_:) 호출 후 유효. nil이면 topHighlights 빈 배열 반환.
    private(set) var highlightContext: InsightContext?

    /// Sparkline 원본 스냅샷. sparklineData 계산에 사용.
    /// refreshHighlightContext(_:) 시 함께 설정.
    private(set) var weeklySnapshots: [WeeklyMetricSnapshot] = []

    // MARK: - Public API

    /// 인사이트를 갱신합니다.
    /// - Parameters:
    ///   - todayActivities: 오늘의 전체 활동 기록
    ///   - recentActivities: 최근 7일 활동 기록 (오늘 제외)
    ///   - recentTemperatureActivities: 최근 48시간 체온 활동 기록
    ///   - baby: 선택된 아기 정보
    ///   - pendingMilestones: 아직 달성하지 못한 마일스톤 목록
    ///   - upcomingVaccinations: 미완료 접종 목록 (D-day 카드용)
    func refresh(
        todayActivities: [Activity],
        recentActivities: [Activity],
        recentTemperatureActivities: [Activity],
        baby: Baby?,
        pendingMilestones: [Milestone],
        upcomingVaccinations: [Vaccination] = []
    ) {
        var result: [DashboardInsight] = []

        if let feeding = makeFeedingInsight(
            todayActivities: todayActivities,
            recentActivities: recentActivities
        ) {
            result.append(feeding)
        }

        if let sleep = makeSleepInsight(
            todayActivities: todayActivities,
            recentActivities: recentActivities,
            baby: baby
        ) {
            result.append(sleep)
        }

        if let health = makeHealthInsight(
            recentTemperatureActivities: recentTemperatureActivities
        ) {
            result.append(health)
        }

        if let milestone = makeMilestoneInsight(
            baby: baby,
            pendingMilestones: pendingMilestones
        ) {
            result.append(milestone)
        }

        if let vaccination = makeVaccinationInsight(upcomingVaccinations: upcomingVaccinations) {
            result.append(vaccination)
        }

        insights = result
    }

    /// 주간 하이라이트 컨텍스트를 업데이트합니다.
    /// - Parameters:
    ///   - ctx: 현재 주 InsightContext (Provider 입력 일체 포함)
    ///   - snapshots: 최근 K주 WeeklyMetricSnapshot (sparkline용, 최신→과거 순서)
    func refreshHighlightContext(_ ctx: InsightContext, snapshots: [WeeklyMetricSnapshot] = []) {
        highlightContext = ctx
        weeklySnapshots = snapshots
    }
}
