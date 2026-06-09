import XCTest
@testable import BabyCare

/// 오프라인 큐 데이터 손실 회귀 방지 (2026-06-10 감사 #2 Date 직렬화 / #5 flush lost-write).
@MainActor
final class OfflineQueueTests: XCTestCase {

    private let storageKey = "babycare_offline_queue"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        super.tearDown()
    }

    private func makeActivityOp(id: String, activity: Activity? = nil) -> PendingOperation {
        let act = activity ?? Activity(babyId: "b1", type: .feedingBottle)
        let json = try? JSONEncoder().encode(act)
        return PendingOperation(
            id: id,
            timestamp: Date(),
            type: .create,
            collectionPath: "users/u1/babies/b1/activities",
            documentId: act.id,
            jsonData: json
        )
    }

    // MARK: - #5 flush lost-write (RED driver)

    func testFlush_enqueueDuringFlush_preservesConcurrentlyAddedOperation() async {
        let mock = MockOfflineQueueFirestore()
        let queue = OfflineQueue(firestore: mock)
        let opA = makeActivityOp(id: "A")
        let opB = makeActivityOp(id: "B")
        queue.enqueue(opA)
        // A를 실행하는 도중(서버 왕복 await 중) 새 기록 B가 큐에 들어온다.
        mock.onExecute = { op in
            guard op.id == "A" else { return }
            await MainActor.run { queue.enqueue(opB) }
        }

        await queue.flush()

        // A는 성공 → 제거, B는 flush 도중 추가 → 보존되어야 한다.
        XCTAssertEqual(queue.operations.map(\.id), ["B"],
                       "flush 도중 enqueue된 작업이 유실되면 안 된다 (operations 통째 덮어쓰기 버그)")
    }

    // MARK: - #5 reconcile characterization (refactor 보호)

    func testFlush_succeededRemoved_failedRetainedWithIncrementedRetry() async {
        let mock = MockOfflineQueueFirestore()
        let queue = OfflineQueue(firestore: mock)
        queue.enqueue(makeActivityOp(id: "ok"))
        queue.enqueue(makeActivityOp(id: "fail"))
        mock.errorByOperationId["fail"] = NSError(domain: "test", code: 1)

        await queue.flush()

        XCTAssertEqual(queue.operations.map(\.id), ["fail"], "성공한 작업만 제거되어야 한다")
        XCTAssertEqual(queue.operations.first?.retryCount, 1, "실패한 작업의 retryCount는 증가해야 한다")
    }

    // MARK: - #2 Date 직렬화 — 큐잉 payload가 typed Activity로 복원되는지 (setData(from:) → Timestamp 보존)

    func testDecodeQueuedActivity_reconstructsActivityWithDateIntact() throws {
        let original = Activity(
            babyId: "b1",
            type: .feedingBottle,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            amount: 120,
            feedingContent: .breastMilk
        )
        let op = makeActivityOp(id: "1", activity: original)

        let decoded = FirestoreService.decodeQueuedActivity(op)

        XCTAssertNotNil(decoded, "큐잉된 Activity는 typed Activity로 복원되어 setData(from:)로 Timestamp 저장되어야 한다")
        XCTAssertEqual(decoded?.id, original.id)
        XCTAssertEqual(decoded?.startTime, original.startTime, "startTime이 정확히 보존되어야 한다 (Double 손상 없이)")
        XCTAssertEqual(decoded?.amount, 120)
        XCTAssertEqual(decoded?.feedingContent, .breastMilk)
    }

    func testDecodeQueuedActivity_nilOrGarbageJSON_returnsNil() {
        let noData = PendingOperation(id: "x", timestamp: Date(), type: .create,
                                      collectionPath: "p", documentId: "d", jsonData: nil)
        XCTAssertNil(FirestoreService.decodeQueuedActivity(noData))

        let garbage = PendingOperation(id: "y", timestamp: Date(), type: .create,
                                       collectionPath: "p", documentId: "d",
                                       jsonData: Data("not json".utf8))
        XCTAssertNil(FirestoreService.decodeQueuedActivity(garbage))
    }
}
