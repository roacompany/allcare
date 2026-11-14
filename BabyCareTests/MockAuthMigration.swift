import Foundation
@testable import BabyCare

/// AuthViewModel 의 migrateFamilySharingIfNeeded 흐름 테스트용 Mock.
/// (계정 삭제는 AccountDeletion — 그 시험은 BabyCareTests+AccountDeletion 의 가짜들을 쓴다.)
///
/// Swift 6 Sendable: 단일 쓰레드 테스트 전용이므로 `@unchecked Sendable`.
final class MockAuthMigration: AuthMigrationProviding, @unchecked Sendable {
    // MARK: - 호출 카운터

    private(set) var migrateCalls: [String] = []

    var migrateCallCount: Int { migrateCalls.count }

    // MARK: - Protocol Conformance

    func migrateFamilySharingIfNeeded(userId: String) async {
        migrateCalls.append(userId)
    }
}
