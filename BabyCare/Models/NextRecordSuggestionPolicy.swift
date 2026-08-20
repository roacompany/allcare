import Foundation

/// 저장 직후 "이어서 기록" 제안 정책 (UX Clean Sweep B4 · 유축 동선 2026-08-20).
/// 육아 루틴은 묶음 행동(수유→기저귀→재움) — 저장 토스트에 다음 기록 1개를 원탭 칩으로 제안한다.
/// 핵심 루프(수유·기저귀·수면)만 순환 제안 — 체온/투약/목욕 등 비주기 기록엔 제안 없음(소음 방지).
/// 유축(생산)은 기저귀가 아니라 '모유(병)'(유축한 모유 먹이기)을 잇는다 — 생산→섭취 문 잇기(B안, PO 승인).
enum NextRecordSuggestionPolicy {
    /// 방금 저장한 타입 → 이어서 제안할 타일(분유/모유(병) 프리셋 구분 포함). 제안 없으면 nil.
    static func suggestion(after saved: Activity.ActivityType) -> RecordTile? {
        switch saved {
        case .feedingBreast, .feedingBottle, .feedingSolid, .feedingSnack:
            return RecordTile(.diaperWet)   // 수유 후 → 기저귀
        case .feedingPumping:
            return RecordTile(.feedingBottle, content: .breastMilk)   // 유축 후 → 모유(병)
        case .diaperWet, .diaperDirty, .diaperBoth:
            return RecordTile(.sleep)       // 기저귀 후 → 재움
        case .sleep:
            return RecordTile(.feedingBreast)   // 기상 후 → 수유
        case .temperature, .medication, .bath, .unknown:
            return nil          // 비주기 기록 — 제안 없음
        }
    }
}
