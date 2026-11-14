import FirebaseFirestore
import XCTest
@testable import BabyCare

/// 서버 확인 쓰기 — 규칙이 거부할 수 있는 쓰기(초대 만들기·공유 문서·「사용함」 표시)가 거부를 사람에게 알리는 약속.
/// 고치기 전: `try await ref.setData(from:)` 가 서버를 안 기다려(Codable 판은 동기) 거부가 화면 어디에도 안 나왔다.
final class ServerConfirmationTests: XCTestCase {

    private let permissionDenied = NSError(domain: FirestoreErrorDomain,
                                           code: FirestoreErrorCode.permissionDenied.rawValue)

    func test_serverAccepts_returnsNormally() async throws {
        try await FirestoreService.awaitServerConfirmation(timeout: 2) { done in done(nil) }
    }

    /// 규칙 거부(PERMISSION_DENIED)가 그대로 올라와야 화면이 「실패」를 말할 수 있다.
    func test_serverRejects_throwsTheServerError() async {
        do {
            try await FirestoreService.awaitServerConfirmation(timeout: 2) { [permissionDenied] done in
                done(permissionDenied)
            }
            XCTFail("서버 거부를 삼켰다")
        } catch {
            XCTAssertEqual((error as NSError).domain, FirestoreErrorDomain)
            XCTAssertEqual((error as NSError).code, FirestoreErrorCode.permissionDenied.rawValue)
        }
    }

    /// 서버 답은 나중에 온다 — 그때까지 기다렸다가 답(여기선 거부)을 돌려줘야 한다.
    func test_answerArrivesLater_waitsForIt() async {
        let start = Date()
        do {
            try await FirestoreService.awaitServerConfirmation(timeout: 5) { [permissionDenied] done in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { done(permissionDenied) }
            }
            XCTFail("답이 오기 전에 돌아왔다(기다리지 않았다)")
        } catch {
            XCTAssertEqual((error as NSError).code, FirestoreErrorCode.permissionDenied.rawValue)
            XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.25)
        }
    }

    /// 오프라인이면 Firestore 는 답을 안 준다 — 끝없이 기다리면 화면이 「참여 중...」에서 멈춘다.
    func test_noAnswer_timesOut() async {
        do {
            try await FirestoreService.awaitServerConfirmation(timeout: 0.2) { _ in }
            XCTFail("답이 없는데 성공으로 돌아왔다")
        } catch {
            XCTAssertEqual(error as? ServerConfirmationError, .timedOut)
        }
    }

    /// 시간 초과 뒤 늦은 답이 와도 두 번 끝내지 않는다(CheckedContinuation 을 두 번 끝내면 앱이 꺼진다).
    func test_lateAnswerAfterTimeout_isIgnored() async throws {
        do {
            try await FirestoreService.awaitServerConfirmation(timeout: 0.1) { done in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { done(nil) }
            }
            XCTFail("답이 없는데 성공으로 돌아왔다")
        } catch {
            XCTAssertEqual(error as? ServerConfirmationError, .timedOut)
        }
        try await Task.sleep(for: .milliseconds(500)) // 늦은 답이 도착할 시간 — 여기서 앱이 꺼지면 실패
    }
}
