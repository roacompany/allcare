import FirebaseFirestore
import Foundation

/// OfflineQueue 가 의존하는 generic document R/W narrow protocol (ISP).
///
/// PendingOperation 단위로 path-based setData / delete 를 위임. dict 직렬화 책임은
/// FirestoreService 가 보유 — `[String: Any]` 비-Sendable 타입 누수 차단.
protocol OfflineQueueFirestoreProviding: Sendable {
    func executePendingOperation(_ op: PendingOperation) async throws
}

extension FirestoreService: OfflineQueueFirestoreProviding {}

extension FirestoreService {
    // MARK: - Offline Queue Execution

    /// 큐잉된 작업 1건 실행. create/update 는 setData, delete 는 delete.
    /// jsonData 가 nil 이거나 dict 변환 실패 시 silent skip (큐에서 자연 제거).
    func executePendingOperation(_ op: PendingOperation) async throws {
        let ref = db.document(op.collectionPath + "/" + op.documentId)
        switch op.type {
        case .create, .update:
            // 큐잉 payload 를 typed Activity 로 복원 후 setData(from:) — 온라인 saveActivity 와 동일 인코더라
            // Date 가 Firestore Timestamp 로 저장된다. (JSON dict 직송 시 Date 가 Double 로 깨져
            // startTime range 쿼리에 안 걸려 기록이 영구 누락되는 #2 버그 방지.)
            guard let activity = Self.decodeQueuedActivity(op) else { return }
            try ref.setData(from: activity)
        case .delete:
            try await ref.delete()
        }
    }

    /// 큐잉된 Activity payload(JSON)를 typed Activity 로 복원. nil/garbage → nil (큐에서 자연 드롭).
    /// 오프라인 큐는 현재 Activity 만 적재(유일 producer = enqueueOfflineActivity).
    static func decodeQueuedActivity(_ op: PendingOperation) -> Activity? {
        guard let data = op.jsonData else { return nil }
        return try? JSONDecoder().decode(Activity.self, from: data)
    }
}
