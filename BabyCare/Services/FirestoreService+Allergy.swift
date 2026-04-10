import FirebaseFirestore
import Foundation

extension FirestoreService {
    // MARK: - Allergy

    func saveAllergyRecord(_ record: AllergyRecord, userId: String, babyId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.allergies)
            .document(record.id)
        try await ref.setData(from: record)
    }

    func fetchAllergyRecords(userId: String, babyId: String) async throws -> [AllergyRecord] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.allergies)
            .order(by: "date", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: AllergyRecord.self)
    }

    func deleteAllergyRecord(_ recordId: String, userId: String, babyId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.allergies)
            .document(recordId)
            .delete()
    }
}
