import Foundation

/// 임신 중 증상 일지.
/// ⚠️ 의학적 판단 텍스트("정상/위험") 금지 — 사용자 자유 메모만 저장.
/// pregnancies/{pid}/pregnancySymptoms/{id}.
struct PregnancySymptom: Identifiable, Codable, Hashable {
    var id: String
    var pregnancyId: String
    var memo: String
    /// 강도 (선택). nil이면 미지정.
    var severity: Severity?
    var occurredAt: Date
    var createdAt: Date

    enum Severity: String, Codable, CaseIterable, Identifiable {
        case mild
        case moderate
        case severe

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .mild: return "약함"
            case .moderate: return "중간"
            case .severe: return "심함"
            }
        }
    }

    init(
        id: String = UUID().uuidString,
        pregnancyId: String,
        memo: String,
        severity: Severity? = nil,
        occurredAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pregnancyId = pregnancyId
        self.memo = memo
        self.severity = severity
        self.occurredAt = occurredAt
        self.createdAt = createdAt
    }
}
