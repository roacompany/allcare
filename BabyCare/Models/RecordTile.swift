import Foundation

/// 기록 런처 타일 — ActivityType + (병수유) content 프리셋.
/// 2026-07-12 용어정리: 같은 `feedingBottle`을 **분유**(formula)/**유축**(breastMilk) 두 타일로 분리.
/// (유축=짜둔 모유 먹이기[섭취] · 분유=조제분유 · 짜기=`feedingPumping` 생산)
/// 타입만으론 분유/유축을 못 나누므로(둘 다 feedingBottle) content 프리셋을 실은 타일 단위 도입.
struct RecordTile: Identifiable, Hashable {
    let type: Activity.ActivityType
    /// feedingBottle 전용 — 분유(formula)/유축(breastMilk) 구분. 그 외 타입은 nil.
    let contentPreset: Activity.FeedingContent?

    init(_ type: Activity.ActivityType, content: Activity.FeedingContent? = nil) {
        self.type = type
        self.contentPreset = content
    }

    /// 분유/유축 타일이 같은 type이라도 별개로 식별 (sheet(item:)·ForEach 안정).
    var id: String { "\(type.rawValue)#\(contentPreset?.rawValue ?? "")" }

    /// 유축(짜둔 모유 병)은 분유(컵)와 다른 아이콘 — 같은 feedingBottle이라도 한눈에 구분.
    var icon: String {
        if type == .feedingBottle, contentPreset == .breastMilk { return "waterbottle.fill" }
        return type.icon
    }
    /// 유축 = 짜둔 모유 → 짜기와 같은 라일락 계열(분유 핑크와 구분).
    var colorName: String {
        if type == .feedingBottle, contentPreset == .breastMilk { return "pumpingColor" }
        return type.color
    }

    /// 타일 라벨 — feedingBottle은 프리셋별(분유/유축), 그 외는 type.displayName.
    var label: String {
        guard type == .feedingBottle, let contentPreset else { return type.displayName }
        return contentPreset == .breastMilk ? "유축" : "분유"
    }

    /// 기록 런처 섹션 — 카테고리 시각 그룹. 분유/유축은 content 프리셋으로 분리, 짜기(생산)는 별 타일.
    static let launcherSections: [(title: String, tiles: [RecordTile])] = [
        ("수유", [
            RecordTile(.feedingBreast),
            RecordTile(.feedingBottle, content: .formula),
            RecordTile(.feedingBottle, content: .breastMilk),
            RecordTile(.feedingSolid),
            RecordTile(.feedingSnack),
            RecordTile(.feedingPumping)
        ]),
        ("수면", [RecordTile(.sleep)]),
        ("기저귀", [RecordTile(.diaperWet), RecordTile(.diaperDirty), RecordTile(.diaperBoth)]),
        ("건강", [RecordTile(.temperature), RecordTile(.medication), RecordTile(.bath)])
    ]
}
