import Foundation
import FirebaseFirestore

extension FirestoreService {
    /// users/{uid}/stats/lifetime 문서 원자 증가
    /// field: "feedingCount" | "sleepCount" | "diaperCount" | "growthRecordCount"
    func incrementStats(userId: String, field: String, by value: Int = 1) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.stats)
            .document(UserStats.lifetimeId)

        try await ref.setData([
            field: FieldValue.increment(Int64(value)),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func fetchStats(userId: String) async throws -> UserStats? {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.stats)
            .document(UserStats.lifetimeId)
        let snapshot = try await ref.getDocument()
        return try? snapshot.data(as: UserStats.self)
    }

    /// 이미 firstRecordAt 있으면 no-op
    func setFirstRecordIfMissing(userId: String, at date: Date) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.stats)
            .document(UserStats.lifetimeId)
        let snapshot = try await ref.getDocument()
        if let data = snapshot.data(), data["firstRecordAt"] != nil { return }
        try await ref.setData(["firstRecordAt": Timestamp(date: date)], merge: true)
    }
}
