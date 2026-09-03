import Foundation
import FirebaseFirestore

/// VM 이 의존하는 것만 — 하루를 읽고 쓴다.
protocol DayRunFirestoreProviding: Sendable {
    func fetchDayRun(userId: String, documentId: String) async throws -> DayRun?
    func saveDayRun(_ run: DayRun, userId: String) async throws
}

extension FirestoreService {

    private func dayRunsRef(userId: String) -> CollectionReference {
        db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.dayRuns)
    }

    /// 하루 한 문서 — 문서 id 가 곧 날짜라 목록을 훑지 않는다.
    /// 🔑 이 레포 다른 곳은 `try? snapshot.data(as:)` 를 쓰지만 **여기선 던진다** —
    ///    `nil` 이 「아직 안 열었다」를 뜻하는 자리라, 디코드 실패를 nil 로 삼키면
    ///    **열려 있는 하루를 못 읽고 새로 덮어쓴다**(fail-open).
    func fetchDayRun(userId: String, documentId: String) async throws -> DayRun? {
        let snapshot = try await dayRunsRef(userId: userId).document(documentId).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: DayRun.self)
    }

    /// 같은 날 다시 열어도 덮어쓴다(멱등) — 문서 id 가 날짜이기 때문이다.
    func saveDayRun(_ run: DayRun, userId: String) async throws {
        try dayRunsRef(userId: userId).document(run.id).setData(from: run)
    }
}

extension FirestoreService: DayRunFirestoreProviding {}
