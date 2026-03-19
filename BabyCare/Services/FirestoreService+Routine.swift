import FirebaseFirestore
import Foundation

extension FirestoreService {
        // MARK: - Routine

    func saveRoutine(_ routine: Routine, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.routines)
            .document(routine.id)
        try ref.setData(from: routine)
    }

    func fetchRoutines(userId: String) async throws -> [Routine] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.routines)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Routine.self)
    }

    func deleteRoutine(_ routineId: String, userId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.routines)
            .document(routineId)
            .delete()
    }
}
