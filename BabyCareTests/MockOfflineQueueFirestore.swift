import Foundation
@testable import BabyCare

/// OfflineQueue.flush 흐름 테스트용 Mock.
/// 재시도 카운트 / 최대 5회 후 drop / 부분 실패 시 잔여 큐 검증 가능.
final class MockOfflineQueueFirestore: OfflineQueueFirestoreProviding, @unchecked Sendable {
    /// 특정 operation id 에 대해 실패시킬 에러 (재시도 시뮬레이션).
    var errorByOperationId: [String: Error] = [:]
    /// 모든 op 에 동일 에러 (전역 fail).
    var errorOnExecute: Error?

    private(set) var executedOps: [PendingOperation] = []

    /// execute 진입 시 호출되는 테스트 훅 (flush 도중 enqueue 같은 동시 상황 재현용).
    var onExecute: (@Sendable (PendingOperation) async -> Void)?

    var executeCallCount: Int { executedOps.count }

    func executePendingOperation(_ op: PendingOperation) async throws {
        executedOps.append(op)
        if let hook = onExecute { await hook(op) }
        if let err = errorOnExecute { throw err }
        if let err = errorByOperationId[op.id] { throw err }
    }
}
