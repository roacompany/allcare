import Foundation

/// 산전 체크리스트 항목.
/// source=bundle: 번들 JSON 로드 (prenatal-checklist.json). source=user: 사용자 추가.
struct PregnancyChecklistItem: Identifiable, Codable, Hashable {
    var id: String
    var pregnancyId: String
    var title: String
    var itemDescription: String?
    /// 카테고리 (trimester1|trimester2|trimester3|postpartum_prep|custom).
    /// 문자열로 저장 — rawValue 영구 계약 회피.
    var category: String
    var isCompleted: Bool
    var completedAt: Date?
    var targetWeek: Int?
    /// "bundle" | "user" — 기본 템플릿 vs 사용자 추가 구분.
    var source: String
    var order: Int?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        pregnancyId: String,
        title: String,
        itemDescription: String? = nil,
        category: String,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        targetWeek: Int? = nil,
        source: String = "user",
        order: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pregnancyId = pregnancyId
        self.title = title
        self.itemDescription = itemDescription
        self.category = category
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.targetWeek = targetWeek
        self.source = source
        self.order = order
        self.createdAt = createdAt
    }
}
