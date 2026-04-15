import Foundation

// MARK: - 소아과 체크리스트 항목 모델

struct HospitalChecklistItem: Identifiable, Codable, Hashable {

    // MARK: - Type

    enum ItemType: String, Codable, Hashable {
        case vaccination       // 예방접종 관련
        case growthAnomaly     // 성장 이상
        case symptomKeyword    // 증상 키워드
    }

    // MARK: - Severity

    enum Severity: String, Codable, Hashable, Comparable {
        case low    = "low"
        case medium = "medium"
        case high   = "high"

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            let order: [Severity] = [.low, .medium, .high]
            return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
        }

        var displayName: String {
            switch self {
            case .low:    return NSLocalizedString("hospital.checklist.severity.low", comment: "")
            case .medium: return NSLocalizedString("hospital.checklist.severity.medium", comment: "")
            case .high:   return NSLocalizedString("hospital.checklist.severity.high", comment: "")
            }
        }
    }

    // MARK: - Properties

    var id: String
    var type: ItemType
    var title: String
    var detail: String?
    var severity: Severity

    // MARK: - Init

    init(
        id: String = UUID().uuidString,
        type: ItemType,
        title: String,
        detail: String? = nil,
        severity: Severity
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.detail = detail
        self.severity = severity
    }
}
