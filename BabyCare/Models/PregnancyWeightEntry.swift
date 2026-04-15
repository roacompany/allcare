import Foundation

/// 임신 중 체중 기록.
/// ⚠️ 의학적 판단 텍스트("정상/위험") 금지 — 숫자/추이만 표시.
struct PregnancyWeightEntry: Identifiable, Codable, Hashable {
    var id: String
    var pregnancyId: String
    var weight: Double
    /// 단위: "kg" | "lb".
    var unit: String
    var measuredAt: Date
    var notes: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        pregnancyId: String,
        weight: Double,
        unit: String = "kg",
        measuredAt: Date = Date(),
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pregnancyId = pregnancyId
        self.weight = weight
        self.unit = unit
        self.measuredAt = measuredAt
        self.notes = notes
        self.createdAt = createdAt
    }
}
