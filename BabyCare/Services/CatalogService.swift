import Foundation
import FirebaseFirestore

enum CatalogService {
    static func fetchCatalog() async throws -> [CatalogProduct] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection(FirestoreCollections.productCatalog).getDocuments()
        print("[CatalogService] fetched \(snapshot.documents.count) documents")
        return snapshot.documents.compactMap { doc -> CatalogProduct? in
            let data = doc.data()
            guard
                let name = data["name"] as? String,
                let brand = data["brand"] as? String,
                let category = data["category"] as? String
            else {
                print("[CatalogService] SKIP \(doc.documentID): missing required field")
                return nil
            }

            let coupangURL = (data["coupangURL"] as? String) ?? (data["coupangUrl"] as? String) ?? ""
            let tags = (data["tags"] as? [String]) ?? []
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt

            return CatalogProduct(
                id: doc.documentID,
                name: name,
                brand: brand,
                category: category,
                coupangURL: coupangURL,
                imageURL: (data["imageURL"] as? String) ?? (data["imageUrl"] as? String),
                tags: tags,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
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
        // 태그가 많을수록 더 구체적으로 등록된 인기 제품으로 간주
        return catalog
            .sorted { $0.tags.count > $1.tags.count }
            .prefix(limit)
            .map { $0 }
    }
}
