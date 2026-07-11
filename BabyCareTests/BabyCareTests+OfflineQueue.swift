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

    // MARK: - #2 Date 직렬화 — 큐잉 payload가 typed 모델로 복원되는지 (setData(from:) → Timestamp 보존)

    func testDecodeQueuedDocument_reconstructsActivityWithDateIntact() throws {
        let original = Activity(
            babyId: "b1",
            type: .feedingBottle,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            amount: 120,
            feedingContent: .breastMilk
        )
        let op = makeActivityOp(id: "1", activity: original)

        let decoded = FirestoreService.decodeQueuedDocument(op) as? Activity

        XCTAssertNotNil(decoded, "큐잉된 Activity는 typed Activity로 복원되어 setData(from:)로 Timestamp 저장되어야 한다")
        XCTAssertEqual(decoded?.id, original.id)
        XCTAssertEqual(decoded?.startTime, original.startTime, "startTime이 정확히 보존되어야 한다 (Double 손상 없이)")
        XCTAssertEqual(decoded?.amount, 120)
        XCTAssertEqual(decoded?.feedingContent, .breastMilk)
    }

    func testDecodeQueuedDocument_nilOrGarbageJSON_returnsNil() {
        let noData = PendingOperation(id: "x", timestamp: Date(), type: .create,
                                      collectionPath: "p", documentId: "d", jsonData: nil)
        XCTAssertNil(FirestoreService.decodeQueuedDocument(noData))

        let garbage = PendingOperation(id: "y", timestamp: Date(), type: .create,
                                       collectionPath: "users/u1/babies/b1/activities", documentId: "d",
                                       jsonData: Data("not json".utf8))
        XCTAssertNil(FirestoreService.decodeQueuedDocument(garbage), "garbage JSON은 typed 복원 실패 → 큐에서 자연 드롭")
    }

    // MARK: - 큐 확대 (일기/성장/건강) — typed 복원 디스패치 + 공용 적재 enqueueSave

    private func makeQueuedOp(_ doc: some Encodable, collection: String, id: String) -> PendingOperation {
        PendingOperation(
            id: UUID().uuidString,
            timestamp: Date(),
            type: .create,
            collectionPath: FirestoreCollections.babyChildPath(userId: "u1", babyId: "b1", collection: collection),
            documentId: id,
            jsonData: try? JSONEncoder().encode(doc)
        )
    }

    func testBabyChildPath_shape() {
        XCTAssertEqual(
            FirestoreCollections.babyChildPath(userId: "u1", babyId: "b1", collection: FirestoreCollections.diary),
            "users/u1/babies/b1/diary"
        )
    }

    func testDecodeQueuedDocument_dispatchesByCollection() {
        let entry = DiaryEntry(babyId: "b1", date: Date(), content: "오프라인 일기", mood: .happy)
        let decodedEntry = FirestoreService.decodeQueuedDocument(
            makeQueuedOp(entry, collection: FirestoreCollections.diary, id: entry.id)
        )
        XCTAssertEqual((decodedEntry as? DiaryEntry)?.content, "오프라인 일기")

        let growth = GrowthRecord(babyId: "b1", weight: 8.4)
        let decodedGrowth = FirestoreService.decodeQueuedDocument(
            makeQueuedOp(growth, collection: FirestoreCollections.growth, id: growth.id)
        )
        XCTAssertEqual((decodedGrowth as? GrowthRecord)?.weight, 8.4)

        let vax = Vaccination(babyId: "b1", vaccine: .bcg, doseNumber: 1, scheduledDate: Date())
        let decodedVax = FirestoreService.decodeQueuedDocument(
            makeQueuedOp(vax, collection: FirestoreCollections.vaccinations, id: vax.id)
        )
        XCTAssertEqual((decodedVax as? Vaccination)?.vaccine, .bcg)
    }

    func testDecodeQueuedDocument_unsupportedCollection_returnsNil() {
        let activity = Activity(babyId: "b1", type: .sleep)
        XCTAssertNil(FirestoreService.decodeQueuedDocument(
            makeQueuedOp(activity, collection: "notACollection", id: "x")
        ), "미지원 컬렉션은 silent skip — 신규 도메인 적재 시 디스패치 case 추가 필수")
    }

    func testOfflineQueue_enqueueSaveAndFlush_executesTypedOp() async {
        let mock = MockOfflineQueueFirestore()
        let queue = OfflineQueue(firestore: mock)

        let entry = DiaryEntry(babyId: "b1", date: Date(), content: "지하철 일기", mood: .tired)
        let path = FirestoreCollections.babyChildPath(userId: "u1", babyId: "b1", collection: FirestoreCollections.diary)
        XCTAssertTrue(queue.enqueueSave(entry, collectionPath: path, documentId: entry.id))
        XCTAssertEqual(queue.pendingCount, 1)

        await queue.flush()
        XCTAssertEqual(mock.executeCallCount, 1)
        XCTAssertEqual(mock.executedOps.first?.collectionPath, path)
        XCTAssertEqual(mock.executedOps.first?.documentId, entry.id)
        XCTAssertEqual(
            (mock.executedOps.first.flatMap { FirestoreService.decodeQueuedDocument($0) } as? DiaryEntry)?.content,
            "지하철 일기",
            "flush 시 typed 복원이 가능해야 Date→Timestamp 보존 경로를 탄다"
        )
        XCTAssertEqual(queue.pendingCount, 0)
    }

    func testOfflineQueue_enqueueSave_encodingFailureReturnsFalse() {
        struct Unencodable: Encodable {
            func encode(to encoder: Encoder) throws { throw NSError(domain: "enc", code: 1) }
        }
        let queue = OfflineQueue(firestore: MockOfflineQueueFirestore())
        XCTAssertFalse(
            queue.enqueueSave(Unencodable(), collectionPath: "p", documentId: "d"),
            "인코딩 실패는 false — 호출부가 로깅해 데이터 손실 가시화"
        )
        XCTAssertEqual(queue.pendingCount, 0)
    }
}
