import Foundation

// MARK: - ProductRecommendation Model

struct ProductRecommendation: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var category: BabyProduct.ProductCategory
    var ageRangeStart: Int?    // 시작 월령 (포함)
    var ageRangeEnd: Int?      // 종료 월령 (포함)
    var reason: String?        // 추천 이유 (정보성, "이 시기 흔히 사용해요" 스타일)
    var icon: String?          // SF Symbol 이름 (optional)
    var coupangKeyword: String? // 쿠팡 검색 키워드 (optional)
}
