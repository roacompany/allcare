import Foundation

/// 파트너 초대 유도 카드 정책 (UX Clean Sweep C3).
/// 가족 공유는 완성돼 있으나 발견성이 낮다 — 혼자 기록 습관이 자리잡은
/// 사용자(공유 미사용 + 기록 7건+)에게 1회(해제형) 안내한다.
enum PartnerInvitePromoPolicy {
    static let dismissedKey = "partnerInvitePromoDismissed"

    /// 노출: 공유 미사용 + 누적 기록 7건 이상 + 아직 해제 안 함.
    static func isVisible(hasSharedBaby: Bool, recordCount: Int, dismissed: Bool) -> Bool {
        !hasSharedBaby && recordCount >= 7 && !dismissed
    }
}
