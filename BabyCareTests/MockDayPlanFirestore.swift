import Foundation
@testable import BabyCare

/// DayPlanStore 테스트용 Mock — in-memory 사용자별 스토어 + 호출 카운터 + 에러 주입.
/// Swift 6 Sendable: 단일 쓰레드 테스트 전용이므로 `@unchecked Sendable`.
final class MockDayPlanFirestore: DayPlanFirestoreProviding, @unchecked Sendable {
    private var store: [String: [DayPlan]] = [:]

    var fetchCount = 0
    var saveCount = 0
    var deleteCount = 0
    var capturedUserIds: [String] = []
    var errorToThrow: Error?

    func seed(_ plans: [DayPlan], userId: String) {
        store[userId] = plans
    }

    func fetchDayPlans(userId: String) async throws -> [DayPlan] {
        fetchCount += 1
        capturedUserIds.append(userId)
        if let e = errorToThrow { throw e }
        // 실제 서비스의 `.order(by: "createdAt", descending: false)` 를 그대로 반영 —
        // Firestore 는 정렬 필드가 동률이면 마지막 explicit orderBy 와 같은 방향으로
        // 문서 id 를 암묵적 tie-break 로 쓴다 (오름차순 → id 오름차순).
        return (store[userId] ?? []).sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id < $1.id
        }
    }

    func saveDayPlan(_ plan: DayPlan, userId: String) async throws {
        saveCount += 1
        capturedUserIds.append(userId)
        if let e = errorToThrow { throw e }
        var list = store[userId] ?? []
        if let i = list.firstIndex(where: { $0.id == plan.id }) { list[i] = plan } else { list.append(plan) }
        store[userId] = list
    }

    func deleteDayPlan(_ planId: String, userId: String) async throws {
        deleteCount += 1
        capturedUserIds.append(userId)
        if let e = errorToThrow { throw e }
        store[userId] = (store[userId] ?? []).filter { $0.id != planId }
    }
}
