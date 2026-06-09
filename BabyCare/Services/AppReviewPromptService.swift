import Foundation

/// 앱 평가(App Store 리뷰) 팝업 one-shot 게이트.
///
/// 순수 상태/결정 단위 — StoreKit/SwiftUI/Firestore 무의존(동기 단위 테스트 가능).
/// 트리거 사이트가 `noteTrigger`로 대기만 세우고, 초크포인트 View(`ContentView`)가
/// scene 활성 + 배지 스낵바 없음일 때 `@Environment(\.requestReview)`를 호출하고
/// `consumePending()`으로 원자적으로 소진한다.
///
/// `autoReviewPromptConsumed`(UserDefaults)의 의미 = "자동 1회 호출을 이미 소진(=다시
/// 자동호출 안 함)". '사용자가 리뷰했음'이 아님 — requestReview는 콜백/결과가 없다.
/// per-device(가족 다기기는 기기마다 1회 — Apple 연 3회 상한이라 수용).
@MainActor
@Observable
final class AppReviewPromptService {
    static let shared = AppReviewPromptService()

    /// 자동 팝업 후보 트리거. 먼저 도달한 1개가 이긴다. (v1.1: badge, highlights)
    enum Trigger: String { case recordsMilestone, hospitalReport }

    /// 누적 핵심 활동(수유+수면+기저귀+성장) 기록 마일스톤 임계값.
    static let recordsMilestoneThreshold = 20

    private let defaults: UserDefaults
    private let isEnabled: Bool
    private static let consumedKey = "autoReviewPromptConsumed"

    /// 트리거가 자격 충족 시 세우는 대기 신호. 초크포인트 View가 관찰. (아직 소진 아님)
    private(set) var pendingTrigger: Trigger?

    init(defaults: UserDefaults = .standard,
         isEnabled: Bool = FeatureFlags.appReviewPromptEnabled) {
        self.defaults = defaults
        self.isEnabled = isEnabled
    }

    var isConsumed: Bool { defaults.bool(forKey: Self.consumedKey) }

    /// 트리거 사이트가 "깨끗한 순간"에 호출. 자격(플래그 on + 미소진 + 미대기) 시 대기만 세움.
    func noteTrigger(_ trigger: Trigger) {
        guard isEnabled else { return }
        guard !isConsumed, pendingTrigger == nil else { return }
        pendingTrigger = trigger
    }

    /// 초크포인트 View가 requestReview() 직전에 호출. 원자적으로 소진 + 대기 해제.
    /// read→write 사이 await 없음 → MainActor에서 분리 불가(레이스 방지).
    @discardableResult
    func consumePending() -> Trigger? {
        guard let trigger = pendingTrigger else { return nil }
        defaults.set(true, forKey: Self.consumedKey)
        pendingTrigger = nil
        return trigger
    }

    /// 누적 핵심 활동 기록 수(수유+수면+기저귀+성장). nil은 0.
    nonisolated static func coreActivityTotal(_ stats: UserStats?) -> Int {
        (stats?.feedingCount ?? 0) + (stats?.sleepCount ?? 0)
            + (stats?.diaperCount ?? 0) + (stats?.growthRecordCount ?? 0)
    }
}
