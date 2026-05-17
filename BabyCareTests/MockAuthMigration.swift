import Foundation
@testable import BabyCare

/// AuthViewModel 의 deleteUserData / migrateFamilySharingIfNeeded 흐름 테스트용 Mock.
///
/// 호출 횟수 + 인자 검증 가능. 실제 Firestore batch 로직은 통합 테스트 영역.
/// Swift 6 Sendable: 단일 쓰레드 테스트 전용이므로 `@unchecked Sendable`.
final class MockAuthMigration: AuthMigrationProviding, @unchecked Sendable {
    // MARK: - 호출 카운터

    private(set) var deleteAllUserDataCalls: [String] = []
    private(set) var migrateCalls: [String] = []

    // MARK: - 에러 주입

    var errorOnDeleteAllUserData: Error?

    // MARK: - 편의

    var deleteAllUserDataCallCount: Int { deleteAllUserDataCalls.count }
    var migrateCallCount: Int { migrateCalls.count }

    // MARK: - Protocol Conformance

    func deleteAllUserData(userId: String) async throws {
        deleteAllUserDataCalls.append(userId)
        if let err = errorOnDeleteAllUserData { throw err }
    }

    func migrateFamilySharingIfNeeded(userId: String) async {
        migrateCalls.append(userId)
    }
}
