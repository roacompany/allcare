import FirebaseFirestore
import XCTest
@testable import BabyCare

/// 2026-11-14 교차 검토로 찾은 지우기·쓰기 안전 결함 — 남의 기록을 지우지 않는다 · 「실패」라고 알린 쓰기는 들어가지 않는다 ·
/// 로그인이 지워져 아무도 못 지우게 되기 전에 다 지운다.
final class DeletionSafetyTests: XCTestCase {

    private func baby(owner: String?) -> Baby {
        var b = Baby(id: "b1", name: "가상 아기", birthDate: Date(timeIntervalSince1970: 1_800_000_000), gender: .female)
        b.ownerUserId = owner
        return b
    }

    // MARK: - 아기 삭제는 주인만

    func test_owner_mayDeleteOwnBaby() {
        XCTAssertTrue(BabyViewModel.mayDelete(baby(owner: nil), currentUserId: "me"))
        XCTAssertTrue(BabyViewModel.mayDelete(baby(owner: "me"), currentUserId: "me"))
    }

    /// 공유받은 가족이 지우면 주인의 기록이 통째로 지워졌다 — 앱이 막는다(규칙은 공유 가족의 쓰기를 열어 둔다).
    func test_sharedMember_mayNotDeleteOwnersBaby() {
        XCTAssertFalse(BabyViewModel.mayDelete(baby(owner: "owner"), currentUserId: "member"))
    }

    func test_signedOut_mayNotDelete() {
        XCTAssertFalse(BabyViewModel.mayDelete(baby(owner: nil), currentUserId: nil))
    }

    // MARK: - 계정 삭제 끝의 초대 정리

    /// 「내 초대 목록」 규칙 배포 전(권한 거부)만 넘긴다 — 계정 삭제가 규칙 배포를 기다리며 막히지 않게.
    func test_inviteCleanup_rulesNotYetDeployed_mayBeIgnored() {
        let denied = NSError(domain: FirestoreErrorDomain, code: FirestoreErrorCode.permissionDenied.rawValue)
        XCTAssertTrue(FirestoreService.mayIgnoreInviteCleanupFailure(denied))
    }

    /// 망·서버 오류·시간 초과는 넘기지 않는다 — 넘기면 곧 로그인이 지워져 아기 이름이 든 초대를 아무도 못 지운다.
    func test_inviteCleanup_networkOrServerFailure_stopsAccountDeletion() {
        let unavailable = NSError(domain: FirestoreErrorDomain, code: FirestoreErrorCode.unavailable.rawValue)
        let deadline = NSError(domain: FirestoreErrorDomain, code: FirestoreErrorCode.deadlineExceeded.rawValue)
        XCTAssertFalse(FirestoreService.mayIgnoreInviteCleanupFailure(unavailable))
        XCTAssertFalse(FirestoreService.mayIgnoreInviteCleanupFailure(deadline))
        XCTAssertFalse(FirestoreService.mayIgnoreInviteCleanupFailure(ServerConfirmationError.timedOut))
    }

    // MARK: - 새로 만드는 쓰기 — 「실패」라고 알렸으면 들어가지 않는다

    /// 시간 안에 서버 답이 없으면 방금 쓴 것을 거둔다(한 번) — 안 거두면 기기에 남은 쓰기가 나중에 들어가
    /// 「실패」라고 알린 초대가 생기거나 공유가 열린다(초대는 「사용함」 표시도 안 된 채).
    func test_createTimesOut_retractsOnce() async {
        let retracted = Counter()
        do {
            try await FirestoreService.confirmOrRetract(timeout: 0.1, { _ in }, retract: { retracted.add() })
            XCTFail("답이 없는데 성공으로 돌아왔다")
        } catch {
            XCTAssertEqual(error as? ServerConfirmationError, .timedOut)
        }
        XCTAssertEqual(retracted.value, 1, "시간 초과인데 거두지 않았다")
    }

    func test_createAccepted_doesNotRetract() async throws {
        let retracted = Counter()
        try await FirestoreService.confirmOrRetract(timeout: 2, { done in done(nil) }, retract: { retracted.add() })
        XCTAssertEqual(retracted.value, 0)
    }

    /// 규칙 거부는 SDK 가 기기에서도 지운다 — 거둘 것이 없다(거부를 그대로 알린다).
    func test_createRejected_doesNotRetract_andThrowsTheRejection() async {
        let retracted = Counter()
        let denied = NSError(domain: FirestoreErrorDomain, code: FirestoreErrorCode.permissionDenied.rawValue)
        do {
            try await FirestoreService.confirmOrRetract(timeout: 2, { done in done(denied) }, retract: { retracted.add() })
            XCTFail("거부를 삼켰다")
        } catch {
            XCTAssertEqual((error as NSError).code, FirestoreErrorCode.permissionDenied.rawValue)
        }
        XCTAssertEqual(retracted.value, 0)
    }
}

/// 거둔 횟수(시험용).
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func add() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}
