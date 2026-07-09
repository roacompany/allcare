import Foundation

/// D1 복귀 넛지 정책 (이탈 방지 P0-2).
/// 마지막 기록 후 24시간 무기록이면 1회 로컬 알림 — 저장할 때마다 동일 identifier로
/// 교체 예약되므로 기록이 이어지는 동안에는 절대 울리지 않는다.
/// 24h 오프셋은 마지막 기록과 같은 시간대에 발화 → 새벽 발송을 구조적으로 회피.
enum ReturnNudgePolicy {
    static let notificationIdentifier = "return-nudge-d1"
    static let silenceInterval: TimeInterval = 24 * 60 * 60

    /// 발화 시각 = 마지막 기록 + 24h. 이미 지났으면 nil (과거 예약 금지).
    static func fireDate(lastRecordAt: Date, now: Date) -> Date? {
        let candidate = lastRecordAt.addingTimeInterval(silenceInterval)
        return candidate > now ? candidate : nil
    }
}
