import Foundation

struct RecommendedProduct: Identifiable, Hashable {
    let id = UUID().uuidString
    let name: String
    let brand: String
    let category: BabyProduct.ProductCategory
    let priceText: String
    let searchKeyword: String
    let tags: [String] // 사이즈, 특징 등 매칭용

    var affiliateURL: URL? {
        CoupangConfig.searchURL(keyword: searchKeyword)
    }
}

enum RecommendedProductCatalog {
    static func recommendations(for product: BabyProduct) -> [RecommendedProduct] {
        let items = catalog[product.category] ?? []
        let brand = product.brand?.lowercased() ?? ""
        let size = product.size?.lowercased() ?? ""
        let name = product.name.lowercased()

        // 같은 브랜드 → 같은 사이즈 키워드 매칭 → 나머지 순으로 정렬
        return items.sorted { a, b in
            let aScore = matchScore(a, brand: brand, size: size, name: name)
            let bScore = matchScore(b, brand: brand, size: size, name: name)
            return aScore > bScore
        }
    }

    private static func matchScore(_ item: RecommendedProduct, brand: String, size: String, name: String) -> Int {
        var score = 0
        if !brand.isEmpty && item.brand.lowercased().contains(brand) { score += 10 }
        if !size.isEmpty && item.tags.contains(where: { $0.lowercased().contains(size) }) { score += 5 }
        if item.name.lowercased().contains(name) || name.contains(item.name.lowercased()) { score += 3 }
        return score
    }

    // MARK: - 카테고리별 인기 육아용품 카탈로그

    static let catalog: [BabyProduct.ProductCategory: [RecommendedProduct]] = [
        .diaper: [
            .init(name: "팬티형 기저귀", brand: "하기스", category: .diaper, priceText: "32,900원~", searchKeyword: "하기스 매직팬티 기저귀", tags: ["3단계", "4단계", "5단계", "팬티형"]),
            .init(name: "밴드형 기저귀", brand: "하기스", category: .diaper, priceText: "28,900원~", searchKeyword: "하기스 네이처메이드 밴드 기저귀", tags: ["1단계", "2단계", "3단계", "밴드형", "신생아"]),
            .init(name: "팬티형 기저귀", brand: "마미포코", category: .diaper, priceText: "25,900원~", searchKeyword: "마미포코 팬티형 기저귀", tags: ["3단계", "4단계", "5단계", "팬티형"]),
            .init(name: "순수 기저귀", brand: "보솜이", category: .diaper, priceText: "24,900원~", searchKeyword: "보솜이 천연코튼 기저귀", tags: ["1단계", "2단계", "3단계", "순한"]),
            .init(name: "물놀이 팬티", brand: "하기스", category: .diaper, priceText: "12,900원~", searchKeyword: "하기스 수영장 물놀이 팬티", tags: ["수영", "물놀이"]),
        ],
        .formula: [
            .init(name: "임페리얼 XO", brand: "남양", category: .formula, priceText: "28,000원~", searchKeyword: "남양 임페리얼XO 분유", tags: ["1단계", "2단계", "3단계"]),
            .init(name: "앱솔루트 명작", brand: "매일", category: .formula, priceText: "27,000원~", searchKeyword: "매일 앱솔루트 명작 분유", tags: ["1단계", "2단계", "3단계"]),
            .init(name: "산양분유", brand: "일동후디스", category: .formula, priceText: "32,000원~", searchKeyword: "일동후디스 산양분유", tags: ["1단계", "2단계", "3단계", "산양"]),
            .init(name: "호호 분유", brand: "남양", category: .formula, priceText: "19,900원~", searchKeyword: "남양 호호 분유", tags: ["1단계", "2단계"]),
        ],
        .babyFood: [
            .init(name: "이유식 파우치", brand: "베베쿡", category: .babyFood, priceText: "15,900원~", searchKeyword: "베베쿡 이유식", tags: ["초기", "중기", "후기"]),
            .init(name: "유기농 이유식", brand: "짱죽", category: .babyFood, priceText: "18,900원~", searchKeyword: "짱죽 유기농 이유식", tags: ["초기", "중기", "후기"]),
            .init(name: "아기 과자", brand: "매일", category: .babyFood, priceText: "8,900원~", searchKeyword: "매일 아기 과자 간식", tags: ["간식", "과자", "떡뻥"]),
            .init(name: "퓨레 파우치", brand: "루솔", category: .babyFood, priceText: "12,900원~", searchKeyword: "루솔 아기 퓨레", tags: ["퓨레", "간식"]),
        ],
        .skincare: [
            .init(name: "베이비 로션", brand: "아토팜", category: .skincare, priceText: "18,900원~", searchKeyword: "아토팜 베이비 로션", tags: ["로션", "보습"]),
            .init(name: "수딩젤", brand: "그린핑거", category: .skincare, priceText: "9,900원~", searchKeyword: "그린핑거 아기 수딩젤", tags: ["수딩", "여름"]),
            .init(name: "베이비 워시", brand: "아토팜", category: .skincare, priceText: "15,900원~", searchKeyword: "아토팜 베이비 워시", tags: ["워시", "목욕"]),
            .init(name: "기저귀 크림", brand: "데시틴", category: .skincare, priceText: "12,900원~", searchKeyword: "데시틴 기저귀 발진 크림", tags: ["발진", "크림"]),
        ],
        .medicine: [
            .init(name: "타이레놀 시럽", brand: "타이레놀", category: .medicine, priceText: "5,900원~", searchKeyword: "어린이 타이레놀 시럽", tags: ["해열", "시럽"]),
            .init(name: "코 세척기", brand: "노즈프리다", category: .medicine, priceText: "12,900원~", searchKeyword: "노즈프리다 코 세척기", tags: ["코막힘", "콧물"]),
            .init(name: "체온계", brand: "브라운", category: .medicine, priceText: "39,900원~", searchKeyword: "브라운 귀 체온계 아기", tags: ["체온계", "귀체온"]),
        ],
        .feeding: [
            .init(name: "젖병", brand: "닥터브라운", category: .feeding, priceText: "12,900원~", searchKeyword: "닥터브라운 젖병", tags: ["젖병", "배앓이"]),
            .init(name: "빨대컵", brand: "리치엘", category: .feeding, priceText: "9,900원~", searchKeyword: "리치엘 빨대컵 아기", tags: ["빨대컵", "컵"]),
            .init(name: "이유식 식기세트", brand: "에디슨", category: .feeding, priceText: "14,900원~", searchKeyword: "에디슨 아기 이유식 식기", tags: ["식기", "이유식", "숟가락"]),
        ],
        .bath: [
            .init(name: "아기 욕조", brand: "스토케", category: .bath, priceText: "45,000원~", searchKeyword: "아기 접이식 욕조", tags: ["욕조"]),
            .init(name: "목욕 가운", brand: "에이든아나이스", category: .bath, priceText: "19,900원~", searchKeyword: "아기 목욕 가운 타올", tags: ["가운", "타올"]),
        ],
        .clothes: [
            .init(name: "바디수트", brand: "카터스", category: .clothes, priceText: "15,900원~", searchKeyword: "카터스 아기 바디수트", tags: ["바디수트", "내의"]),
            .init(name: "수면 조끼", brand: "에이든아나이스", category: .clothes, priceText: "25,900원~", searchKeyword: "아기 수면 조끼", tags: ["수면", "조끼"]),
        ],
        .toy: [
            .init(name: "치발기", brand: "소피더지라프", category: .toy, priceText: "19,900원~", searchKeyword: "소피더지라프 치발기", tags: ["치발기", "이앓이"]),
            .init(name: "모빌", brand: "타이니러브", category: .toy, priceText: "35,900원~", searchKeyword: "타이니러브 아기 모빌", tags: ["모빌", "신생아"]),
        ],
    ]
}
