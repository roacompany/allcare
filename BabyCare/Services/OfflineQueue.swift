import Foundation
import FirebaseFirestore

struct PendingOperation: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let type: OperationType
    let collectionPath: String  // e.g. "users/abc/babies/xyz/activities"
    let documentId: String
    let jsonData: Data?  // nil for delete operations
    var retryCount: Int = 0

    enum OperationType: String, Codable {
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

    init() { load() }

    func enqueue(_ op: PendingOperation) {
        operations.append(op)
        save()
    }

    func flush() async {
        guard !isFlushing, !operations.isEmpty else { return }
        isFlushing = true

        var failed: [PendingOperation] = []
        for op in operations {
            do {
                try await execute(op)
            } catch {
                var failedOp = op
                failedOp.retryCount += 1
                if failedOp.retryCount < 5 { // max 5 retries
                    failed.append(failedOp)
                }
                // Drop after 5 failures
            }
        }
        operations = failed
        save()
        isFlushing = false
    }

    private func execute(_ op: PendingOperation) async throws {
        let db = Firestore.firestore()
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
}
