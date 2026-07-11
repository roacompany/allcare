import Foundation

/// 활동 리마인더 2발 체인 정책 (UX Clean Sweep B1).
/// 기존 원샷은 한 번 놓치면 다음 기록까지 영구 침묵 — interval·2×interval 2발 후 침묵하고,
/// 24h 시점은 복귀 넛지(ReturnNudgePolicy)가 이어받는다 (스팸 없는 단계 설계).
enum ActivityReminderChainPolicy {
    /// 마지막 기록 기준 발화 오프셋(분). [1발 = interval, 2발 = 2×interval].
    static func offsetsMinutes(intervalMinutes: Int) -> [Int] {
        [intervalMinutes, intervalMinutes * 2]
    }

    /// 체인 알림 식별자 (타입별·발수별). 저장 시 전체 취소 → 재예약에 사용.
    static func identifiers(typeRaw: String) -> [String] {
        ["activity-\(typeRaw)-1", "activity-\(typeRaw)-2"]
    }

    /// 취소 대상 = 체인 ids + 레거시 원샷 id("activity-{type}") — 구버전 예약 잔존 방지.
    static func cancellationIdentifiers(typeRaw: String) -> [String] {
        identifiers(typeRaw: typeRaw) + ["activity-\(typeRaw)"]
    }
}
