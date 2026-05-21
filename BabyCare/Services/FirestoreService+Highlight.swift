import FirebaseFirestore
import Foundation

/// HighlightAISummaryService / HighlightPrecacheService 가 의존하는 narrow protocol (ISP).
///
/// FirestoreService 전체를 추상화하는 대신, 하이라이트 캐시에 필요한 CRUD만 노출.
/// 가족 공유 호환: 호출자는 `babyVM.dataUserId()` 결과를 userId로 전달.
protocol HighlightFirestoreProviding: Sendable {
    func fetchHighlightAICache(userId: String, babyId: String, weekKey: String, metricKey: String) async -> HighlightAICache?
    func saveHighlightAICache(_ cache: HighlightAICache, userId: String, babyId: String) async throws
    func deleteHighlightAICache(userId: String, babyId: String, weekKey: String) async throws
}

extension FirestoreService: HighlightFirestoreProviding {}

extension FirestoreService {
    // MARK: - HighlightAICache

    /// 단일 캐시 문서 조회.
    /// 문서 없거나 디코딩 실패 시 nil 반환 (cache miss).
    func fetchHighlightAICache(userId: String, babyId: String, weekKey: String, metricKey: String) async -> HighlightAICache? {
        let docId = "\(weekKey)_\(metricKey)"
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.highlightCache)
            .document(docId)
        do {
            let snapshot = try await ref.getDocument()
            guard snapshot.exists else { return nil }
            return try? snapshot.data(as: HighlightAICache.self)
        } catch {
            logSilent("highlight cache 조회 실패", error: error, logger: AppLogger.highlight)
            return nil
        }
    }

    /// 캐시 문서 저장 (같은 docId면 overwrite — idempotent).
    /// 호출자는 babyVM.dataUserId() 결과를 userId로 전달.
    func saveHighlightAICache(_ cache: HighlightAICache, userId: String, babyId: String) async throws {
        let docId = cache.id
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.highlightCache)
            .document(docId)
        try ref.setData(from: cache)
    }

    /// weekKey 단위로 해당 주 캐시 전체 삭제 (RC 버전 변경 시 무효화).
    /// 단일 doc이 아닌 prefix 기반 다건 삭제: weekKey_* 패턴.
    func deleteHighlightAICache(userId: String, babyId: String, weekKey: String) async throws {
        let collectionRef = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.highlightCache)
        let snapshot = try await collectionRef
            .whereField("weekKey", isEqualTo: weekKey)
            .getDocuments()
        for document in snapshot.documents {
            try await document.reference.delete()
        }
    }
}
