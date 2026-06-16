import Foundation

struct PendingOperation: Codable, Identifiable, Sendable {
    let id: String
    let timestamp: Date
    let type: OperationType
    let collectionPath: String  // e.g. "users/abc/babies/xyz/activities"
    let documentId: String
    let jsonData: Data?  // nil for delete operations
    var retryCount: Int = 0

    enum OperationType: String, Codable, Sendable {
        case create, update, delete
    }
}

@MainActor @Observable
final class OfflineQueue {
    static let shared = OfflineQueue()

    var pendingCount: Int { operations.count }
    private(set) var operations: [PendingOperation] = []
    private(set) var isFlushing = false

    private let storageKey = "babycare_offline_queue"
    private let firestore: OfflineQueueFirestoreProviding

    init(firestore: OfflineQueueFirestoreProviding = FirestoreService.shared) {
        self.firestore = firestore
        load()
    }

    func enqueue(_ op: PendingOperation) {
        operations.append(op)
        save()
    }

    func flush() async {
        guard !isFlushing, !operations.isEmpty else { return }
        isFlushing = true
        defer { isFlushing = false }

        // 이번 flush 대상 스냅샷. flush 의 await 도중 enqueue 된 신규 op 은 batch 밖이라 보존된다.
        let batch = operations
        var failedByID: [String: PendingOperation] = [:]
        for op in batch {
            do {
                try await execute(op)
            } catch {
                var failedOp = op
                failedOp.retryCount += 1
                if failedOp.retryCount < 5 { // max 5 retries
                    failedByID[op.id] = failedOp
                }
                // Drop after 5 failures
            }
        }

        // 성공한 batch op 만 제거. 실패분은 retry++ 로 교체, flush 도중 새로 들어온 op 은 그대로 보존
        // (operations 통째 덮어쓰기 시 동시 enqueue 가 유실되는 #5 버그 방지).
        let batchIDs = Set(batch.map(\.id))
        operations = operations.compactMap { op in
            guard batchIDs.contains(op.id) else { return op }   // flush 도중 추가됨 → 보존
            return failedByID[op.id]                              // 성공/소진 → 제거, 실패 → retry++ 교체
        }
        save()
    }

    private func execute(_ op: PendingOperation) async throws {
        try await firestore.executePendingOperation(op)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(operations) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let ops = try? JSONDecoder().decode([PendingOperation].self, from: data) {
            operations = ops
        }
    }

    /// 로그아웃/계정 전환 시 큐 비우기 — 이전 계정 경로 write 가 새 세션에서 재생(cross-account)되는 것 차단.
    func clear() {
        operations = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
