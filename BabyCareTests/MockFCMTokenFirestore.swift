import Foundation
@testable import BabyCare

/// FCMTokenService 흐름 테스트용 Mock.
/// 호출 인자/횟수 검증 + 에러 주입. Swift 6 Sendable: 단일 쓰레드 테스트 전용 @unchecked.
final class MockFCMTokenFirestore: FCMTokenFirestoreProviding, @unchecked Sendable {
    private(set) var saveCalls: [(userId: String, deviceId: String, token: String)] = []
    private(set) var deleteCalls: [(userId: String, deviceId: String)] = []

    var errorOnSave: Error?
    var errorOnDelete: Error?

    var saveCallCount: Int { saveCalls.count }
    var deleteCallCount: Int { deleteCalls.count }

    func saveFCMToken(userId: String, deviceId: String, token: String) async throws {
        if let err = errorOnSave { throw err }
        saveCalls.append((userId: userId, deviceId: deviceId, token: token))
    }

    func deleteFCMToken(userId: String, deviceId: String) async throws {
        if let err = errorOnDelete { throw err }
        deleteCalls.append((userId: userId, deviceId: deviceId))
    }
}
