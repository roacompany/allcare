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
            guard let data = op.jsonData,
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            try await ref.setData(dict)
        case .delete:
            try await ref.delete()
        }
    }
}
