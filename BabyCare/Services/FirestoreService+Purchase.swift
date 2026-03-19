import FirebaseFirestore
import Foundation

extension FirestoreService {
        // MARK: - Purchase Records

    func savePurchaseRecord(_ record: PurchaseRecord, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.purchases)
            .document(record.id)
        try ref.setData(from: record)
    }

    func fetchPurchaseRecords(userId: String) async throws -> [PurchaseRecord] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.purchases)
            .order(by: "purchaseDate", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: PurchaseRecord.self)
    }

    func fetchPurchaseRecords(userId: String, from startDate: Date, to endDate: Date) async throws -> [PurchaseRecord] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.purchases)
            .whereField("purchaseDate", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("purchaseDate", isLessThanOrEqualTo: Timestamp(date: endDate))
            .order(by: "purchaseDate", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: PurchaseRecord.self)
    }

    func deletePurchaseRecord(_ recordId: String, userId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.purchases)
            .document(recordId)
            .delete()
    }

    // MARK: - Baby (single)

    func fetchBaby(userId: String, babyId: String) async throws -> Baby? {
        let doc = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .getDocument()
        do {
            return try doc.data(as: Baby.self)
        } catch {
            Self.logger.warning("Baby \(babyId) decode failed: \(error.localizedDescription)")
            return nil
        }
    }
}
