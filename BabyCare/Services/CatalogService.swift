import Foundation

enum CatalogService {
    /// 카탈로그 전체 fetch — FirestoreService 경유.
    static func fetchCatalog(provider: CatalogFirestoreProviding = FirestoreService.shared) async throws -> [CatalogProduct] {
        try await provider.fetchCatalog()
    }

    static func findMatches(
        userText: String,
        category: BabyProduct.ProductCategory,
        catalog: [CatalogProduct]
    ) -> [CatalogProduct] {
        let words = userText
            .lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { return [] }

        return catalog.filter { product in
            guard product.category == category.rawValue else { return false }
            let lowercasedTags = product.tags.map { $0.lowercased() }
            let matchCount = words.filter { word in
                lowercasedTags.contains(where: { $0.contains(word) })
            }.count
            return matchCount >= 1
        }
    }

    // MARK: - Popular Products (카탈로그 기반 top-N)

    /// Firestore 카탈로그에서 태그 수(= 구매 기록 대리 지표) 기준 상위 N개 반환.
    /// 외부 추천 API 호출 없이 정적 카탈로그 데이터만 사용합니다.
    static func popularProducts(from catalog: [CatalogProduct], limit: Int = 5) -> [CatalogProduct] {
        return catalog
            .sorted { $0.tags.count > $1.tags.count }
            .prefix(limit)
            .map { $0 }
    }
}
