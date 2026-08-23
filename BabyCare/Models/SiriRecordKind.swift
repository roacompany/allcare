import Foundation

/// 시리가 받는 기록 종류 — 기록 런처 타일(`RecordTile`)과 1:1 로 맞춘다.
///
/// 수면은 여기 없다: 「잠들었어」/「깼어」 두 동작이라 별도 인텐트가 맡는다(`SleepIntents`).
/// 소변+대변(`diaperBoth`)도 없다 — 런처에서 이미 뺀 타일이고 옛 기록 표시용 enum 만 남아 있다.
///
/// ⚠️ `rawValue` 는 **손님이 단축어 앱에 만들어 둔 것에 저장된다.** 바꾸면 그 단축어가 깨진다.
enum SiriRecordKind: String, CaseIterable, Sendable {
    case breast = "breast"                        // 모유
    case bottleFormula = "bottle_formula"         // 분유
    case bottleBreastMilk = "bottle_breast_milk"  // 모유(병) — 유축한 모유를 병으로 먹인 기록
    case pumping = "pumping"                      // 유축 (생산)
    case solid = "solid"                          // 이유식
    case snack = "snack"                          // 간식
    case diaperWet = "diaper_wet"                 // 소변
    case diaperDirty = "diaper_dirty"             // 대변
    case bath = "bath"                            // 목욕
    case temperature = "temperature"              // 체온
    case medication = "medication"                // 투약

    /// 런처 타일과 같은 것을 가리킨다 — 라벨·색·아이콘·저장 타입의 단일 소스.
    /// default: 없이 exhaustive 유지 — 새 종류가 조용히 빠지지 않도록.
    var tile: RecordTile {
        switch self {
        case .breast: RecordTile(.feedingBreast)
        case .bottleFormula: RecordTile(.feedingBottle, content: .formula)
        case .bottleBreastMilk: RecordTile(.feedingBottle, content: .breastMilk)
        case .pumping: RecordTile(.feedingPumping)
        case .solid: RecordTile(.feedingSolid)
        case .snack: RecordTile(.feedingSnack)
        case .diaperWet: RecordTile(.diaperWet)
        case .diaperDirty: RecordTile(.diaperDirty)
        case .bath: RecordTile(.bath)
        case .temperature: RecordTile(.temperature)
        case .medication: RecordTile(.medication)
        }
    }

    /// 시리가 말할 때 쓰는 이름 — 런처 라벨과 같은 것을 쓴다(화면과 말이 갈라지지 않게).
    var displayName: String { tile.label }
}
