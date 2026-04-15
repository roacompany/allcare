import Foundation

// MARK: - ProductRecommendationService
//
// 정적 카탈로그(AgeBasedProducts.json) 기반 월령 추천 서비스.
// 외부 API 호출 없이 번들 내 JSON만 사용합니다.
// Views → Services 직접 참조 금지 원칙에 따라 ProductViewModel을 통해서만 노출됩니다.

enum ProductRecommendationService {

    // MARK: - Catalog Loading

    /// 번들의 AgeBasedProducts.json을 파싱해 전체 카탈로그를 반환합니다.
    /// - Parameter bundle: JSON 파일이 포함된 번들. 기본값은 앱 메인 번들.
    static func loadCatalog(bundle: Bundle = .main) -> [ProductRecommendation] {
        // 앱 번들에서 먼저 찾고, 없으면 현재 번들 전체 검색
        let searchBundles: [Bundle] = [bundle, .main] + Bundle.allBundles
        for b in searchBundles {
            if let url = b.url(forResource: "AgeBasedProducts", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let catalog = try? JSONDecoder().decode([ProductRecommendation].self, from: data) {
                return catalog
            }
        }
        return []
    }

    // MARK: - Age-based Recommendations

    /// 주어진 월령에 해당하는 추천 용품 목록을 반환합니다.
    /// - Parameter ageInMonths: 아기의 현재 월령
    /// - Returns: 해당 월령 구간에 속하는 ProductRecommendation 배열
    static func recommendations(for ageInMonths: Int) -> [ProductRecommendation] {
        let catalog = loadCatalog()
        return recommendations(for: ageInMonths, catalog: catalog)
    }

    /// 미리 로드된 카탈로그에서 월령 추천을 반환합니다 (테스트 용이성).
    static func recommendations(
        for ageInMonths: Int,
        catalog: [ProductRecommendation]
    ) -> [ProductRecommendation] {
        catalog.filter { item in
            let start = item.ageRangeStart ?? 0
            let end = item.ageRangeEnd ?? 36
            return ageInMonths >= start && ageInMonths <= end
        }
    }

    // MARK: - Popular Products

    /// 구매 기록 기반 인기 용품 top-N을 반환합니다.
    /// - Parameters:
    ///   - products: 전체 제품 목록
    ///   - limit: 반환할 최대 개수
    /// - Returns: 구매 기록(purchasePrice 기준 총 지출)이 많은 순으로 정렬된 용품
    static func popularProducts(from products: [BabyProduct], limit: Int = 5) -> [BabyProduct] {
        // 카테고리별 등록 빈도 기준으로 상위 N개 반환
        let categoryCount = Dictionary(
            products.map { ($0.category, 1) },
            uniquingKeysWith: +
        )
        let topCategories = categoryCount
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.key)

        // 각 인기 카테고리에서 가장 최근 구매 용품 1개씩 반환
        var result: [BabyProduct] = []
        for category in topCategories {
            if let product = products
                .filter({ $0.category == category })
                .sorted(by: { $0.updatedAt > $1.updatedAt })
                .first {
                result.append(product)
            }
        }
        return Array(result.prefix(limit))
    }

    // MARK: - Reorder Candidates

    /// 재구매 임박 소모품(7일 이내)을 필터링합니다.
    /// - Parameters:
    ///   - products: 전체 제품 목록
    ///   - reorderDates: productId → 다음 재구매 예상일 딕셔너리
    ///   - thresholdDays: 알림 임계 일수 (기본 7일)
    /// - Returns: 7일 이내 재구매가 필요한 제품 목록
    static func reorderCandidates(
        from products: [BabyProduct],
        reorderDates: [String: Date],
        thresholdDays: Int = 7
    ) -> [BabyProduct] {
        let now = Date()
        return products.filter { product in
            guard let nextDate = reorderDates[product.id] else { return false }
            let days = Calendar.current.dateComponents([.day], from: now, to: nextDate).day ?? Int.max
            return days <= thresholdDays
        }
    }
}
