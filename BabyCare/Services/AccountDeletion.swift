import FirebaseAuth
import Foundation

/// 계정 삭제가 기대는 로그인 쪽 — 앱에선 `FirebaseAccountAuth`, 시험에선 가짜.
protocol AccountAuthGateway: Sendable {
    var currentUserID: String? { get }
    /// 마지막으로 로그인(인증)한 시각 — ID 토큰의 auth_time.
    func lastSignInDate() async throws -> Date?
    func deleteCurrentUser() async throws
}

/// 그 사람의 서버 기록 전부를 지우는 쪽. 로그인한 채로 불러야 한다(규칙이 본인만 허용).
protocol AccountDataErasing: Sendable {
    func eraseAllUserData(userId: String) async throws
}

/// 계정 삭제.
struct AccountDeletion: Sendable {
    enum Outcome: Equatable, Sendable {
        case deleted
        case needsRecentLogin
        case failed
    }

    /// 로그인을 지울 수 있다고 보는 최근 로그인 범위.
    static let recentSignInWindow: TimeInterval = 4 * 60

    let auth: AccountAuthGateway
    let data: AccountDataErasing
    let photos: StorageServiceProviding
    let pushToken: @Sendable () async -> Void
    let now: @Sendable () -> Date

    /// RED 판: 고치기 전 순서 그대로 — 로그인을 먼저 지우고, 기록·사진 정리는 실패해도 「삭제됨」.
    func run() async -> Outcome {
        let userId = auth.currentUserID
        do {
            try await auth.deleteCurrentUser()
        } catch {
            return Self.isRecentLoginRequired(error) ? .needsRecentLogin : .failed
        }
        await pushToken()
        if let userId {
            do {
                try await data.eraseAllUserData(userId: userId)
            } catch {
                logSilent("계정 데이터 정리 실패 (Auth는 이미 삭제됨)", error: error, logger: AppLogger.auth)
            }
            do {
                try await photos.deleteUserStorage(userId: userId)
            } catch {
                logSilent("계정 Storage 사진 정리 실패 (Auth는 이미 삭제됨)", error: error, logger: AppLogger.storage)
            }
        }
        return .deleted
    }

    static func isRecentLoginRequired(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == AuthErrorDomain && nsError.code == AuthErrorCode.requiresRecentLogin.rawValue
    }
}

/// 실제 로그인(FirebaseAuth). 앱은 기본 Auth, 시험은 에뮬레이터 앱의 Auth 를 넘긴다.
/// `Auth` 는 Firebase 가 여러 스레드에서 쓰도록 만든 객체라 `@unchecked Sendable`.
struct FirebaseAccountAuth: AccountAuthGateway, @unchecked Sendable {
    let auth: Auth

    var currentUserID: String? { auth.currentUser?.uid }

    func lastSignInDate() async throws -> Date? {
        guard let user = auth.currentUser else { return nil }
        return try await user.getIDTokenResult().authDate
    }

    func deleteCurrentUser() async throws {
        guard let user = auth.currentUser else { throw AccountDeletionError.notSignedIn }
        try await user.delete()
    }
}

enum AccountDeletionError: Error {
    case notSignedIn
}
