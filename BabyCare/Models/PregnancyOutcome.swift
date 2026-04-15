import Foundation

/// 임신 종료 상태.
/// ⚠️ rawValue는 Firestore에 persist되는 영구 계약 — 변경 불가.
/// 추가는 항상 Optional로 확장하고, 기존 case의 rawValue는 수정 금지.
enum PregnancyOutcome: String, Codable, CaseIterable, Hashable {
    case ongoing = "ongoing"
    case born = "born"
    case miscarriage = "miscarriage"
    case stillbirth = "stillbirth"
    case terminated = "terminated"

    var displayName: String {
        switch self {
        case .ongoing: "임신 중"
        case .born: "출산"
        case .miscarriage: "유산"
        case .stillbirth: "사산"
        case .terminated: "임신 중지"
        }
    }
}
