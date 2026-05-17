import Foundation
@testable import BabyCare

/// CryAnalysisViewModel 통합 테스트용 Mock.
///
/// In-memory 배열 기반 스텁 + 호출 카운터.
/// Swift 6 Sendable: 단일 쓰레드 테스트 전용이므로 `@unchecked Sendable`.
final class MockCryFirestore: CryFirestoreProviding, @unchecked Sendable {
    // MARK: - 스토어

    /// saveCryRecord 누적. 가장 최근이 last index.
    var savedRecords: [CryRecord] = []
    /// fetchRecentCryRecords 반환값 (기본: savedRecords 의 limit slice).
    var fetchOverride: [CryRecord]?

    // MARK: - 에러 주입

    var errorOnSave: Error?
    var errorOnFetch: Error?

    // MARK: - 호출 카운터

    private(set) var saveCalls: [(userId: String, babyId: String, record: CryRecord)] = []
    private(set) var fetchCalls: [(userId: String, babyId: String, limit: Int)] = []

    var saveCallCount: Int { saveCalls.count }
    var fetchCallCount: Int { fetchCalls.count }

    // MARK: - Protocol Conformance

    func saveCryRecord(_ record: CryRecord, userId: String, babyId: String) async throws {
        if let err = errorOnSave { throw err }
        saveCalls.append((userId: userId, babyId: babyId, record: record))
        savedRecords.append(record)
    }

    func fetchRecentCryRecords(userId: String, babyId: String, limit: Int) async throws -> [CryRecord] {
        if let err = errorOnFetch { throw err }
        fetchCalls.append((userId: userId, babyId: babyId, limit: limit))
        if let override = fetchOverride { return Array(override.prefix(limit)) }
        return Array(savedRecords.sorted { $0.recordedAt > $1.recordedAt }.prefix(limit))
    }
}
