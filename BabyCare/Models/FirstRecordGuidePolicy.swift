import Foundation

/// 첫 기록 가이드 카드 노출 정책 (이탈 방지 P0-1).
/// 아기 등록 후 첫 기록 전환(퍼널 최대 낙폭 구간)과 1주+ 기록 공백 사용자의 재시작을 유도한다.
enum FirstRecordGuidePolicy {
    /// 가이드가 제안하는 핵심 3종 — 대시보드 quickSave 경로 재사용.
    static let guideTypes: [Activity.ActivityType] = [.feedingBreast, .diaperWet, .sleep]

    /// 노출 조건: 아기 선택됨 + 오늘 기록 0 + 최근 1주 기록 0 + 로딩 아님.
    /// 최근 1주 조건이 활성 사용자에 대한 매일 아침 오노출을 막는다.
    static func isVisible(hasSelectedBaby: Bool, todayCount: Int, recentWeekCount: Int, isLoading: Bool) -> Bool {
        hasSelectedBaby && todayCount == 0 && recentWeekCount == 0 && !isLoading
    }
}
