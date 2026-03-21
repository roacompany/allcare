import FirebaseFirestore
import Foundation

extension FirestoreService {
        // MARK: - Diary

    func saveDiaryEntry(_ entry: DiaryEntry, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(entry.babyId)
            .collection(FirestoreCollections.diary)
            .document(entry.id)
        try ref.setData(from: entry)
    }

    func fetchDiaryEntries(userId: String, babyId: String) async throws -> [DiaryEntry] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.diary)
            .order(by: "date", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: DiaryEntry.self)
    }

    func deleteDiaryEntry(_ entry: DiaryEntry, userId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(entry.babyId)
            .collection(FirestoreCollections.diary)
            .document(entry.id)
            .delete()
    }
}
