import Foundation

/// 예방접종 후 부작용 기록 모델.
/// 정보 보관용이며 의학적 진단이 아닙니다.
struct VaccineSideEffect: Identifiable, Codable, Hashable {

    // MARK: - Properties

    var id: String
    var type: SideEffectType
    var severity: Severity
    var recordedAt: Date
    var note: String?

    // MARK: - SideEffectType

    enum SideEffectType: String, Codable, CaseIterable {
        case fever = "fever"
        case swelling = "swelling"
        case redness = "redness"
        case fussiness = "fussiness"
        case lossOfAppetite = "lossOfAppetite"
        case other = "other"

        var displayName: String {
            switch self {
            case .fever: return NSLocalizedString("vaccination.sideEffect.type.fever", comment: "")
            case .swelling: return NSLocalizedString("vaccination.sideEffect.type.swelling", comment: "")
            case .redness: return NSLocalizedString("vaccination.sideEffect.type.redness", comment: "")
            case .fussiness: return NSLocalizedString("vaccination.sideEffect.type.fussiness", comment: "")
            case .lossOfAppetite: return NSLocalizedString("vaccination.sideEffect.type.lossOfAppetite", comment: "")
            case .other: return NSLocalizedString("vaccination.sideEffect.type.other", comment: "")
            }
        }

        var icon: String {
            switch self {
            case .fever: return "thermometer.medium"
            case .swelling: return "circle.fill"
            case .redness: return "circle.lefthalf.filled"
            case .fussiness: return "face.smiling.inverse"
            case .lossOfAppetite: return "fork.knife"
            case .other: return "exclamationmark.circle"
            }
        }
    }

    // MARK: - Severity

    enum Severity: String, Codable, CaseIterable {
        case mild = "mild"
        case moderate = "moderate"
        case severe = "severe"

        var displayName: String {
            switch self {
            case .mild: return NSLocalizedString("vaccination.sideEffect.severity.mild", comment: "")
            case .moderate: return NSLocalizedString("vaccination.sideEffect.severity.moderate", comment: "")
            case .severe: return NSLocalizedString("vaccination.sideEffect.severity.severe", comment: "")
            }
        }

        var color: String {
            switch self {
            case .mild: return "successColor"
            case .moderate: return "warmOrangeColor"
            case .severe: return "coralColor"
            }
        }
    }

    // MARK: - Init

    init(
        id: String = UUID().uuidString,
        type: SideEffectType,
        severity: Severity,
        recordedAt: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.type = type
        self.severity = severity
        self.recordedAt = recordedAt
        self.note = note
    }
}
