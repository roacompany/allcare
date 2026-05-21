import FirebaseFirestore
import Foundation

/// CatalogService 가 의존하는 카탈로그 fetch narrow protocol (ISP).
/// productCatalog 컬렉션은 top-level (user scope 없음). 추천 로직은 pure function 으로 분리.
protocol CatalogFirestoreProviding: Sendable {
    func fetchCatalog() async throws -> [CatalogProduct]
}

extension FirestoreService: CatalogFirestoreProviding {}

extension FirestoreService {
    // MARK: - Catalog

    /// productCatalog 전체 fetch. 필수 필드(name/brand/category) 누락 문서는 경고 후 skip.
    /// imageURL/coupangURL 은 두 가지 키 표기(camelCase + 변형) 모두 허용 — admin 입력 호환성.
    func fetchCatalog() async throws -> [CatalogProduct] {
        let snapshot = try await db.collection(FirestoreCollections.productCatalog).getDocuments()
        return snapshot.documents.compactMap { doc -> CatalogProduct? in
            let data = doc.data()
            guard
                let name = data["name"] as? String,
                let brand = data["brand"] as? String,
                let category = data["category"] as? String
            else {
                AppLogger.catalog.warning("CatalogProduct SKIP \(doc.documentID): missing required field")
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
}
