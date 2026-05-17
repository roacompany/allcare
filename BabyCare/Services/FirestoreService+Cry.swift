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
    /// Firebase iOS SDK 동기 setData — 로컬 persistence 즉시 보장, 네트워크 sync 는
    /// SDK pending queue 가 비동기 처리. await 완료 ≠ 서버 commit 완료.
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
    /// 부분 결과 가능 — 개별 문서 decode 실패는 경고 로그 후 제외 (decodeDocuments).
    /// 전체 throws 는 Firestore 쿼리 실패에서만 발생.
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
