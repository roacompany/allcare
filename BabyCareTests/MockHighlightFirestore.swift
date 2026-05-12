import Foundation
@testable import BabyCare

/// HighlightAISummaryService / HighlightPrecacheService 통합 테스트용 Mock.
///
/// In-memory dict 기반 스텁 + 호출 카운터 (cache hit/miss 검증용).
/// Swift 6 Sendable: 단일 쓰레드 테스트 전용이므로 `@unchecked Sendable`.
final class MockHighlightFirestore: HighlightFirestoreProviding, @unchecked Sendable {
    // MARK: - 스텁

    /// fetchHighlightAICache 반환값. key = "\(weekKey)_\(metricKey)".
    var cacheStore: [String: HighlightAICache] = [:]

    // MARK: - 에러 주입

    var errorOnFetch: Error?
    var errorOnSave: Error?
    var errorOnDelete: Error?

    // MARK: - 호출 카운터

    private(set) var fetchCalls: [(userId: String, babyId: String, weekKey: String, metricKey: String)] = []
    private(set) var saveCalls: [HighlightAICache] = []
    private(set) var deleteCalls: [(userId: String, babyId: String, weekKey: String)] = []

    // MARK: - 편의 프로퍼티

    var fetchCallCount: Int { fetchCalls.count }
    var saveCallCount: Int { saveCalls.count }
    var deleteCallCount: Int { deleteCalls.count }

    // MARK: - Protocol Conformance

    func fetchHighlightAICache(userId: String, babyId: String, weekKey: String, metricKey: String) async -> HighlightAICache? {
        fetchCalls.append((userId: userId, babyId: babyId, weekKey: weekKey, metricKey: metricKey))
        if errorOnFetch != nil { return nil }
        let key = "\(weekKey)_\(metricKey)"
        return cacheStore[key]
    }

    func saveHighlightAICache(_ cache: HighlightAICache, userId: String, babyId: String) async throws {
        if let err = errorOnSave { throw err }
        saveCalls.append(cache)
        cacheStore[cache.id] = cache
    }

    func deleteHighlightAICache(userId: String, babyId: String, weekKey: String) async throws {
        if let err = errorOnDelete { throw err }
        deleteCalls.append((userId: userId, babyId: babyId, weekKey: weekKey))
        let keysToRemove = cacheStore.keys.filter { $0.hasPrefix("\(weekKey)_") }
        keysToRemove.forEach { cacheStore.removeValue(forKey: $0) }
    }
}
