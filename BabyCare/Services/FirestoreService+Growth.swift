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

    /// 백필용 count 집계 — 성장 기록 총 수를 서버에서 집계.
    func countGrowthRecords(userId: String, babyId: String) async throws -> Int {
        let query = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.growth)
        let agg = try await query.count.getAggregation(source: .server)
        return agg.count.intValue
    }

    /// 백필용 earliest — 가장 오래된 growth record의 date 반환.
    func fetchEarliestGrowthRecord(userId: String, babyId: String) async throws -> GrowthRecord? {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.growth)
            .order(by: "date", descending: false)
            .limit(to: 1)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: GrowthRecord.self).first
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

    func updateGrowthRecord(_ record: GrowthRecord, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(record.babyId)
            .collection(FirestoreCollections.growth)
            .document(record.id)
        try ref.setData(from: record)
    }

    func deleteGrowthRecord(_ recordId: String, userId: String, babyId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.growth)
            .document(recordId)
            .delete()
    }
}
