import FirebaseFirestore
import Foundation

/// AnalysisEngine 의 hospitalReports 캐시 R/W narrow protocol (ISP).
/// 경로: users/{userId}/babies/{babyId}/hospitalReports/{resultId}
protocol AnalysisFirestoreProviding: Sendable {
    func saveAnalysisResult(_ result: AnalysisResult, userId: String) async throws
    func fetchCachedAnalysisResult(babyId: String, visitId: String, userId: String) async -> AnalysisResult?
}

extension FirestoreService: AnalysisFirestoreProviding {}

extension FirestoreService {
    // MARK: - Analysis Result (Hospital Report Cache)

    /// AnalysisResult 저장 (같은 id면 overwrite — idempotent).
    func saveAnalysisResult(_ result: AnalysisResult, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users).document(userId)
            .collection(FirestoreCollections.babies).document(result.babyId)
            .collection(FirestoreCollections.hospitalReports).document(result.id)
        try ref.setData(from: result)
    }

    /// hospitalVisitId 로 가장 최근 1건 조회. 캐시 miss 시 nil.
    func fetchCachedAnalysisResult(babyId: String, visitId: String, userId: String) async -> AnalysisResult? {
        let snapshot = try? await db.collection(FirestoreCollections.users).document(userId)
            .collection(FirestoreCollections.babies).document(babyId)
            .collection(FirestoreCollections.hospitalReports)
            .whereField("hospitalVisitId", isEqualTo: visitId)
            .limit(to: 1)
            .getDocuments()
        return snapshot?.documents.first.flatMap { try? $0.data(as: AnalysisResult.self) }
    }
}
