import Foundation

/// 기록 진입 모드 — 타입 하나가 '즉시 저장'인지 '상세 시트'인지.
enum RecordEntryMode: Equatable {
    case instant   // 그 자리서 즉시 저장 + 되돌리기 (입력할 게 없는 이벤트)
    case detail    // 통합 기록 시트 (수치/타이머/텍스트가 필요한 기록)
}

/// 기록 진입 단일 정책 — 홈 그리드·＋런처·첫기록 가이드가 모두 공유.
/// "같은 걸 어디서 누르냐에 따라 다름"을 제거하는 단일 소스.
enum RecordEntryRule {
    /// default: 없이 exhaustive 유지 — 신규 ActivityType이 조용히 누락되지 않도록(swift-conventions).
    static func mode(for type: Activity.ActivityType) -> RecordEntryMode {
        switch type {
        case .feedingBreast, .feedingSolid, .feedingSnack,
             .diaperWet, .diaperDirty, .diaperBoth, .bath:
            // 입력이 꼭 필요 없는 것 = 원탭 즉시(예전 그리드 속도 복원 — 시트+저장 강요 안 함).
            // 상세(모유 방향·음식명·대변 색/발진)는 저장 후 타임라인 항목 탭→편집.
            return .instant
        case .feedingBottle, .feedingPumping, .sleep, .temperature, .medication:
            // 양(mL)·타이머·값이 없으면 저장이 무의미한 것만 시트.
            return .detail
        case .unknown:
            return .detail   // 방어적(그리드/피커에서 필터돼 실제 도달 불가)
        }
    }
}
