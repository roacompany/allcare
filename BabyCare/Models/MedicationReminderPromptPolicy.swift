import Foundation

/// 투약 알림 인라인 제안 정책 (UX Clean Sweep B2).
/// 투약 알림 규칙은 존재하지만 기본 OFF + 설정 깊숙이 있어 발견성이 0에 가깝다 —
/// 투약 기록 저장 직후 생애 1회만 "다음 회차 알림 켤까요?"를 제안한다.
enum MedicationReminderPromptPolicy {
    static let promptedKey = "medicationReminderPromptShown"

    /// 제안 노출 조건: 규칙이 꺼져 있고 + 아직 제안한 적 없음.
    static func shouldOffer(ruleEnabled: Bool, alreadyPrompted: Bool) -> Bool {
        !ruleEnabled && !alreadyPrompted
    }

    static var alreadyPrompted: Bool {
        UserDefaults.standard.bool(forKey: promptedKey)
    }

    /// 제안 소비(켜기/나중에 무관 1회) — 재노출 방지.
    static func markPrompted() {
        UserDefaults.standard.set(true, forKey: promptedKey)
    }
}
