import FirebaseFirestore
import Foundation

extension FirestoreService {
        // MARK: - Growth

    func saveGrowthRecord(_ record: GrowthRecord, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(record.babyId)
            .collection(FirestoreCollections.growth)
            .document(record.id)
        try ref.setData(from: record)
    }

    func fetchGrowthRecords(userId: String, babyId: String) async throws -> [GrowthRecord] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.growth)
            .order(by: "date", descending: false)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: GrowthRecord.self)
    }
}
