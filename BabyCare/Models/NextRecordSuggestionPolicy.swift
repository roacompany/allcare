import Foundation

/// 저장 직후 "이어서 기록" 제안 정책 (UX Clean Sweep B4).
/// 육아 루틴은 묶음 행동(수유→기저귀→재움) — 저장 토스트에 다음 기록 1개를 원탭 칩으로 제안한다.
/// 핵심 루프(수유·기저귀·수면)만 순환 제안 — 체온/투약/목욕 등 비주기 기록엔 제안 없음(소음 방지).
enum NextRecordSuggestionPolicy {
    /// 방금 저장한 타입 → 이어서 제안할 타입. 제안 없으면 nil.
    static func suggestion(after saved: Activity.ActivityType) -> Activity.ActivityType? {
        switch saved {
        case .feedingBreast, .feedingBottle, .feedingSolid, .feedingSnack, .feedingPumping:
            return .diaperWet   // 수유 후 → 기저귀
        case .diaperWet, .diaperDirty, .diaperBoth:
            return .sleep       // 기저귀 후 → 재움
        case .sleep:
            return .feedingBreast   // 기상 후 → 수유
        case .temperature, .medication, .bath, .unknown:
            return nil          // 비주기 기록 — 제안 없음
        }
    }
}
