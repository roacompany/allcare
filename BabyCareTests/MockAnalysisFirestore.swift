import Foundation
@testable import BabyCare

/// AnalysisEngine 의 hospitalReports 캐시 흐름 테스트용 Mock.
final class MockAnalysisFirestore: AnalysisFirestoreProviding, @unchecked Sendable {
    /// fetchCachedAnalysisResult 반환값 (key: "\(babyId)_\(visitId)")
    var stubCache: [String: AnalysisResult] = [:]
    var errorOnSave: Error?

    private(set) var saveCalls: [(result: AnalysisResult, userId: String)] = []
    private(set) var fetchCalls: [(babyId: String, visitId: String, userId: String)] = []

    var saveCallCount: Int { saveCalls.count }
    var fetchCallCount: Int { fetchCalls.count }

    func saveAnalysisResult(_ result: AnalysisResult, userId: String) async throws {
        if let err = errorOnSave { throw err }
        saveCalls.append((result: result, userId: userId))
    }

    func fetchCachedAnalysisResult(babyId: String, visitId: String, userId: String) async -> AnalysisResult? {
        fetchCalls.append((babyId: babyId, visitId: visitId, userId: userId))
        return stubCache["\(babyId)_\(visitId)"]
    }
}
