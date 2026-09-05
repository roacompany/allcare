import Foundation
@testable import BabyCare

final class MockDayRunFirestore: DayRunFirestoreProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: [String: DayRun]] = [:]   // userId → docId → DayRun

    private(set) var fetchCount = 0
    private(set) var saveCount = 0
    var fetchError: Error?
    var saveError: Error?

    func seed(_ run: DayRun, userId: String) {
        lock.withLock {
            store[userId, default: [:]][run.id] = run
        }
    }

    // 🔑 async 함수 안에서 `lock()/unlock()` 직접 호출은 이 SDK 에서 컴파일 에러다
    // ("unavailable from asynchronous contexts") — `withLock` 스코프 클로저로 감싼다.
    // 잠금 범위·의미는 원안(brief)과 동일, 문법만 async-safe 로 바꿨다.
    func fetchDayRun(userId: String, documentId: String) async throws -> DayRun? {
        try lock.withLock {
            fetchCount += 1
            if let e = fetchError { throw e }
            return store[userId]?[documentId]
        }
    }

    func saveDayRun(_ run: DayRun, userId: String) async throws {
        try lock.withLock {
            saveCount += 1
            if let e = saveError { throw e }
            store[userId, default: [:]][run.id] = run
        }
    }
}
