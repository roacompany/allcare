import FirebaseFirestore
import Foundation

extension FirestoreService {
        // MARK: - Baby

    func saveBaby(_ baby: Baby, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(baby.id)
        try ref.setData(from: baby)
    }

    func fetchBabies(userId: String) async throws -> [Baby] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Baby.self)
    }

    /// Baby 삭제 시 하위 컬렉션(activities, growth, diary)도 함께 삭제.
    func deleteBaby(_ babyId: String, userId: String) async throws {
        let babyRef = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)

        // 하위 컬렉션 cascade 삭제
        for subcollection in [FirestoreCollections.activities, FirestoreCollections.growth, FirestoreCollections.diary] {
            let docs = try await babyRef.collection(subcollection).getDocuments()
            for doc in docs.documents {
                try await doc.reference.delete()
            }
        }

        try await babyRef.delete()
    }
}
