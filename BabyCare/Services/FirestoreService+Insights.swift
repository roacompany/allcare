import FirebaseFirestore
import Foundation

extension FirestoreService {
    // MARK: - WeeklyMetricSnapshot

    /// 주간 metric 스냅샷 저장. 같은 weekKey면 overwrite (idempotent).
    /// 호출자 (ActivityViewModel) 는 babyVM.dataUserId() 결과를 userId로 전달.
    func saveWeeklyMetricSnapshot(_ snapshot: WeeklyMetricSnapshot, userId: String, babyId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.weeklyMetrics)
            .document(snapshot.weekKey)
        try ref.setData(from: snapshot)
    }

    /// 최근 K주 스냅샷 조회 (최신 먼저). orderBy weekStartDate desc + limit.
    /// 단일 필드 정렬이라 composite index 불필요.
    func fetchWeeklyMetricSnapshots(userId: String, babyId: String, limit: Int) async throws -> [WeeklyMetricSnapshot] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.weeklyMetrics)
            .order(by: "weekStartDate", descending: true)
            .limit(to: limit)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: WeeklyMetricSnapshot.self)
    }
}
