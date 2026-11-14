import FirebaseAuth
import UIKit
import XCTest
@testable import BabyCare

/// 계정 삭제 순서 — 「기록 먼저, 로그인 나중」.
/// 고치기 전(3/16 041fa2a ~ 2.8.13): 로그인을 먼저 지우고 기록을 지우러 가서, 그 뒤 요청이 로그인 없이 나가 규칙에 막혔다
/// (처리방침은 「회원 탈퇴 시 개인정보는 즉시 파기합니다」). 정리 실패는 삼키고 「삭제됨」으로 끝났다.
final class AccountDeletionTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - 순서·결과

    /// 최근에 로그인했으면: 기록 → 사진 → 이 기기 알림 표 → 로그인 순서로 지우고 「삭제됨」.
    func test_freshLogin_erasesRecordsBeforeDeletingTheLogin() async {
        let world = World(signedInAgo: 60)
        let outcome = await world.deletion(now: now).run()
        XCTAssertEqual(outcome, .deleted)
        XCTAssertEqual(world.log.steps, ["erase:u1", "photos:u1", "pushToken", "deleteLogin"])
    }

    /// 로그인한 지 오래면 아무것도 지우지 않고 「다시 로그인」을 청한다(빈 계정이 남는 일을 막는다).
    func test_staleLogin_deletesNothingAndAsksToSignInAgain() async {
        let world = World(signedInAgo: 30 * 60)
        let outcome = await world.deletion(now: now).run()
        XCTAssertEqual(outcome, .needsRecentLogin)
        XCTAssertEqual(world.log.steps, [])
    }

    func test_unknownSignInTime_isTreatedAsStale() async {
        let world = World(signedInAgo: nil)
        let outcome = await world.deletion(now: now).run()
        XCTAssertEqual(outcome, .needsRecentLogin)
        XCTAssertEqual(world.log.steps, [])
    }

    /// 경계: 4분 안은 지운다 · 4분을 넘으면 묻는다.
    func test_recentSignInWindow_boundary() async {
        let inside = World(signedInAgo: AccountDeletion.recentSignInWindow - 1)
        let insideOutcome = await inside.deletion(now: now).run()
        XCTAssertEqual(insideOutcome, .deleted)
        let outside = World(signedInAgo: AccountDeletion.recentSignInWindow + 1)
        let outsideOutcome = await outside.deletion(now: now).run()
        XCTAssertEqual(outsideOutcome, .needsRecentLogin)
        XCTAssertEqual(outside.log.steps, [])
    }

    /// 기록 지우기가 실패하면 로그인은 남긴다 — 다시 눌러 마저 지울 수 있게(지우기는 몇 번 해도 같다).
    func test_recordErasureFails_keepsTheLoginForRetry() async {
        let world = World(signedInAgo: 60)
        world.eraser.error = NSError(domain: "test", code: 1)
        let outcome = await world.deletion(now: now).run()
        XCTAssertEqual(outcome, .failed)
        XCTAssertEqual(world.log.steps, ["erase:u1"])
    }

    /// 사진 정리가 실패해도 계정 삭제는 끝까지 간다 — 사진 쪽 문제로 계정 삭제가 영영 막히면 안 된다.
    func test_photoCleanupFails_stillDeletesTheLogin() async {
        let world = World(signedInAgo: 60)
        world.photos.error = NSError(domain: "test", code: 2)
        let outcome = await world.deletion(now: now).run()
        XCTAssertEqual(outcome, .deleted)
        XCTAssertEqual(world.log.steps, ["erase:u1", "photos:u1", "pushToken", "deleteLogin"])
    }

    /// 기록을 지운 뒤 로그인 삭제가 「최근 로그인 필요」로 거부되면(서버 기준이 4분보다 짧을 때) 다시 로그인을 청한다.
    func test_loginDeletionRejectedAsNotRecent_afterErase_asksToSignInAgain() async {
        let world = World(signedInAgo: 60)
        world.auth.deleteError = NSError(domain: AuthErrorDomain, code: AuthErrorCode.requiresRecentLogin.rawValue)
        let outcome = await world.deletion(now: now).run()
        XCTAssertEqual(outcome, .needsRecentLogin)
        XCTAssertEqual(world.log.steps, ["erase:u1", "photos:u1", "pushToken", "deleteLogin"])
    }

    func test_loginDeletionOtherError_isFailure() async {
        let world = World(signedInAgo: 60)
        world.auth.deleteError = NSError(domain: AuthErrorDomain, code: AuthErrorCode.networkError.rawValue)
        let outcome = await world.deletion(now: now).run()
        XCTAssertEqual(outcome, .failed)
    }

    /// 로그인돼 있지 않으면 아무것도 하지 않고 실패(고치기 전: 아무것도 안 지우고 「삭제됨」처럼 로그아웃됐다).
    func test_notSignedIn_doesNothing() async {
        let world = World(signedInAgo: 60)
        world.auth.currentUserID = nil
        let outcome = await world.deletion(now: now).run()
        XCTAssertEqual(outcome, .failed)
        XCTAssertEqual(world.log.steps, [])
    }
}

// MARK: - 가짜들 — 불린 순서를 한 장부(StepLog)에 적는다

private final class StepLog: @unchecked Sendable {
    private(set) var steps: [String] = []
    func add(_ step: String) { steps.append(step) }
}

private final class FakeAccountAuth: AccountAuthGateway, @unchecked Sendable {
    var currentUserID: String? = "u1"
    var signedInAt: Date?
    var deleteError: Error?
    let log: StepLog

    init(log: StepLog) { self.log = log }

    func lastSignInDate() async throws -> Date? { signedInAt }

    func deleteCurrentUser() async throws {
        log.add("deleteLogin")
        if let deleteError { throw deleteError }
    }
}

private final class FakeAccountData: AccountDataErasing, @unchecked Sendable {
    var error: Error?
    let log: StepLog

    init(log: StepLog) { self.log = log }

    func eraseAllUserData(userId: String) async throws {
        log.add("erase:\(userId)")
        if let error { throw error }
    }
}

private final class FakePhotos: StorageServiceProviding, @unchecked Sendable {
    var error: Error?
    let log: StepLog

    init(log: StepLog) { self.log = log }

    func uploadBabyPhoto(_ image: UIImage, userId: String, babyId: String) async throws -> String { "" }
    func uploadDiaryPhoto(_ image: UIImage, userId: String, babyId: String, diaryId: String, index: Int) async throws -> String { "" }
    func deleteBabyStorage(userId: String, babyId: String) async throws {}

    func deleteUserStorage(userId: String) async throws {
        log.add("photos:\(userId)")
        if let error { throw error }
    }
}

private final class World {
    let log = StepLog()
    let auth: FakeAccountAuth
    let eraser: FakeAccountData
    let photos: FakePhotos
    let signedInAgo: TimeInterval?

    init(signedInAgo: TimeInterval?) {
        auth = FakeAccountAuth(log: log)
        eraser = FakeAccountData(log: log)
        photos = FakePhotos(log: log)
        self.signedInAgo = signedInAgo
    }

    func deletion(now: Date) -> AccountDeletion {
        auth.signedInAt = signedInAgo.map { now.addingTimeInterval(-$0) }
        let log = log
        return AccountDeletion(
            auth: auth,
            data: eraser,
            photos: photos,
            pushToken: { log.add("pushToken") },
            now: { now }
        )
    }
}
