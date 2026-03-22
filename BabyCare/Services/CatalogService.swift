import Foundation
import FirebaseFirestore

enum CatalogService {
    static func fetchCatalog() async throws -> [CatalogProduct] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection(FirestoreCollections.productCatalog).getDocuments()
        return snapshot.documents.compactMap { doc -> CatalogProduct? in
            let data = doc.data()
            guard
                let name = data["name"] as? String,
                let brand = data["brand"] as? String,
                let category = data["category"] as? String,
                let coupangURL = data["coupangURL"] as? String,
                let tags = data["tags"] as? [String],
                let createdAtTS = data["createdAt"] as? Timestamp,
                let updatedAtTS = data["updatedAt"] as? Timestamp
            else { return nil }

            return CatalogProduct(
                id: doc.documentID,
                name: name,
                brand: brand,
                category: category,
                coupangURL: coupangURL,
                imageURL: data["imageURL"] as? String,
                tags: tags,
                createdAt: createdAtTS.dateValue(),
                updatedAt: updatedAtTS.dateValue()
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
}
