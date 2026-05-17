import FirebaseFirestore
import Foundation

/// CryAnalysisViewModel 이 의존하는 narrow protocol (ISP).
///
/// FirestoreService 전체를 추상화하는 대신, 울음 분석 기록 R/W 만 노출.
/// 가족 공유 호환: 호출자는 `babyVM.dataUserId()` 결과를 userId로 전달.
protocol CryFirestoreProviding: Sendable {
    func saveCryRecord(_ record: CryRecord, userId: String, babyId: String) async throws
    func fetchRecentCryRecords(userId: String, babyId: String, limit: Int) async throws -> [CryRecord]
}

extension FirestoreService: CryFirestoreProviding {}

extension FirestoreService {
    // MARK: - CryRecord

    /// CryRecord 저장 (같은 id면 overwrite — idempotent).
    /// 경로: users/{userId}/babies/{babyId}/cryRecords/{recordId}
    func saveCryRecord(_ record: CryRecord, userId: String, babyId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.cryRecords)
            .document(record.id)
        try ref.setData(from: record)
    }

    /// 최근 CryRecord 목록 (recordedAt 내림차순, limit 적용).
    func fetchRecentCryRecords(userId: String, babyId: String, limit: Int) async throws -> [CryRecord] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.cryRecords)
            .order(by: "recordedAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: CryRecord.self)
    }
}
