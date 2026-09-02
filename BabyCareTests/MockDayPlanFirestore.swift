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
        return store[userId] ?? []
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
