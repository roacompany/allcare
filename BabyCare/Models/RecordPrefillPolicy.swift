import Foundation

/// 기록 입력 프리필 정책 (UX Clean Sweep B3).
/// 수유량 등 반복 입력값을 직전 동일 타입 기록에서 가져와 기본값으로 제안 —
/// 실측(2026-07-11): 기존 폼은 항상 빈 값 시작(프리필 부재).
enum RecordPrefillPolicy {
    /// 직전 동일 타입 기록의 양(ml) — 오늘 → 최근 7일 순으로 최신 기록 우선. 없으면 nil.
    static func lastAmount(
        type: Activity.ActivityType,
        todayActivities: [Activity],
        recentActivities: [Activity]
    ) -> String? {
        let match = (todayActivities + recentActivities)
            .filter { $0.type == type && $0.amount != nil }
            .max(by: { $0.startTime < $1.startTime })
        guard let amount = match?.amount else { return nil }
        return String(Int(amount))
    }

    /// 직전 병수유의 내용물(분유/모유) — 없으면 nil (호출부 기본값 유지).
    static func lastFeedingContent(
        todayActivities: [Activity],
        recentActivities: [Activity]
    ) -> Activity.FeedingContent? {
        (todayActivities + recentActivities)
            .filter { $0.type == .feedingBottle }
            .max(by: { $0.startTime < $1.startTime })?
            .feedingContent
    }
}
