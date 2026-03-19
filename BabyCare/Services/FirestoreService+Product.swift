import FirebaseFirestore
import Foundation

extension FirestoreService {
        // MARK: - Product

    func saveProduct(_ product: BabyProduct, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.products)
            .document(product.id)
        try ref.setData(from: product)
    }

    func fetchProducts(userId: String) async throws -> [BabyProduct] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.products)
            .order(by: "updatedAt", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: BabyProduct.self)
    }

    func deleteProduct(_ productId: String, userId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.products)
            .document(productId)
            .delete()
    }
}
