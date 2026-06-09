import Foundation

/// 보호자–아기 관계 라벨. rawValue 는 영구 계약(저장값) — 절대 변경/재사용 금지.
/// `unknown` 은 미래 버전이 추가한 미지의 rawValue 를 관용 디코드하기 위한 read-only 센티넬
/// (ActivityType.unknown 선례). 새 쓰기 경로는 `selectable` 만 사용.
enum CaregiverRelationship: String, Codable, Hashable, CaseIterable {
    case mother
    case father
    case grandmother
    case grandfather
    case other
    case unknown   // read-only 폴백 — UI 선택지/저장 대상 아님

    /// UI 선택지 (unknown 제외).
    static let selectable: [CaregiverRelationship] = [.mother, .father, .grandmother, .grandfather, .other]

    /// 미지 rawValue 는 unknown 으로 폴백 (init?(rawValue:) 의 nil 회피).
    static func known(rawValue: String) -> CaregiverRelationship {
        CaregiverRelationship(rawValue: rawValue) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .mother: return "엄마"
        case .father: return "아빠"
        case .grandmother: return "할머니"
        case .grandfather: return "할아버지"
        case .other: return "기타"
        case .unknown: return "미지정"
        }
    }
}
