import Foundation
@testable import BabyCare

/// CatalogService.fetchCatalog 흐름 테스트용 Mock.
final class MockCatalogFirestore: CatalogFirestoreProviding, @unchecked Sendable {
    var stubCatalog: [CatalogProduct] = []
    var errorOnFetch: Error?
    private(set) var fetchCallCount = 0

    func fetchCatalog() async throws -> [CatalogProduct] {
        fetchCallCount += 1
        if let err = errorOnFetch { throw err }
        return stubCatalog
    }
}
