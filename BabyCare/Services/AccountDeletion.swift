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

/// 계정 삭제 — 「기록 먼저, 로그인 나중」.
///
/// 로그인을 먼저 지우면 그 뒤 요청은 로그인 없이 나가 규칙(본인만 허용)에 막힌다 — 3월(041fa2a)부터 2.8.13 까지
/// 계정 삭제가 서버 기록을 하나도 못 지운 까닭이다. 그래서:
/// 1. 로그인을 지금 지울 수 있는지(최근 로그인) **먼저** 본다 — 아니면 아무것도 지우지 않고 「다시 로그인」.
/// 2. 로그인한 채로 기록 → 사진 → 이 기기 알림 표를 지운다.
/// 3. 마지막에 로그인을 지운다.
///
/// 최근 로그인 기준은 Firebase 문서에 숫자가 없다(실사례 약 5분) → 4분으로 여유를 둔다. 그래도 서버가
/// 「최근 로그인 필요」로 거부하면(기록은 이미 지운 뒤) 같은 「다시 로그인」으로 안내한다 — 다시 누르면 남은 로그인만 지운다.
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

    func run() async -> Outcome {
        guard let userId = auth.currentUserID else { return .failed }

        // 1. 로그인을 지금 지울 수 있나 — 아니면 아무것도 지우지 않는다(빈 계정이 남지 않게)
        let signedInAt: Date?
        do {
            signedInAt = try await auth.lastSignInDate()
        } catch {
            logSilent("계정 삭제: 마지막 로그인 시각을 못 읽음", error: error, logger: AppLogger.auth)
            return .failed
        }
        guard let signedInAt, now().timeIntervalSince(signedInAt) <= Self.recentSignInWindow else {
            return .needsRecentLogin
        }

        // 2. 로그인한 채로 기록 → 사진 → 이 기기 알림 표
        do {
            try await data.eraseAllUserData(userId: userId)
        } catch {
            // 로그인은 남긴다 — 다시 누르면 마저 지운다(지우기는 몇 번 해도 같다)
            logSilent("계정 삭제: 기록 지우기 실패(로그인 유지)", error: error, logger: AppLogger.auth)
            return .failed
        }
        do {
            try await photos.deleteUserStorage(userId: userId)
        } catch {
            // 사진 쪽 문제로 계정 삭제가 영영 막히면 안 된다 — 기록은 이미 지웠으므로 계속 간다
            logSilent("계정 삭제: 사진 정리 실패(계속 진행)", error: error, logger: AppLogger.storage)
        }
        await pushToken()

        // 3. 로그인
        do {
            try await auth.deleteCurrentUser()
        } catch {
            logSilent("계정 삭제: 로그인 지우기 실패(기록은 지워짐)", error: error, logger: AppLogger.auth)
            return Self.isRecentLoginRequired(error) ? .needsRecentLogin : .failed
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
