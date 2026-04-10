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

    func fetchDiaryEntries(
        userId: String,
        babyId: String,
        limit: Int = 20,
        after cursor: DocumentSnapshot? = nil
    ) async throws -> (entries: [DiaryEntry], lastDocument: DocumentSnapshot?) {
        var query = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.diary)
            .order(by: "date", descending: true)
            .limit(to: limit)

        if let cursor {
            query = query.start(afterDocument: cursor)
        }

        let snapshot = try await query.getDocuments()
        let entries = decodeDocuments(snapshot.documents, as: DiaryEntry.self)
        let lastDocument = snapshot.documents.count == limit ? snapshot.documents.last : nil
        return (entries: entries, lastDocument: lastDocument)
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
