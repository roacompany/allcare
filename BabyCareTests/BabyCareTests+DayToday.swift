import XCTest
@testable import BabyCare

// 분리: BabyCareTests+DayPlan.swift 가 아닌 새 파일 — DayPlan 파일이 1,047줄이라
// .swiftlint.yml file_length error 1200 에 이 태스크 몫을 더하면 넘긴다(컨트롤러 판단).
// 포함 클래스: DayRunStoreTests (Task 5 · dayRuns 저장소 계약)

// MARK: - Task 5 · dayRuns 저장소 계약

final class DayRunStoreTests: XCTestCase {

    func testCollectionConstantIsStable() {
        XCTAssertEqual(FirestoreCollections.dayRuns, "dayRuns")
    }

    func testMockRoundTrip() async throws {
        let mock = MockDayRunFirestore()
        let run = DayRun(id: "2026-09-03", planId: "p", startedAt: Date())
        try await mock.saveDayRun(run, userId: "u1")
        let back = try await mock.fetchDayRun(userId: "u1", documentId: "2026-09-03")
        XCTAssertEqual(back, run)
        XCTAssertEqual(mock.saveCount, 1)
        XCTAssertEqual(mock.fetchCount, 1)
    }

    /// owner-path 격리 — 다른 사용자의 하루가 보이면 안 된다(#49 결함군).
    func testMockIsolatesUsers() async throws {
        let mock = MockDayRunFirestore()
        try await mock.saveDayRun(DayRun(id: "2026-09-03", startedAt: Date()), userId: "u1")
        let other = try await mock.fetchDayRun(userId: "u2", documentId: "2026-09-03")
        XCTAssertNil(other)
    }

    func testMissingDayReturnsNilNotError() async throws {
        let mock = MockDayRunFirestore()
        // 🔑 `XCTAssertNil(try await …)` 는 이 SDK 에서 "async call in an autoclosure
        // that does not support concurrency" — 값을 먼저 받아 assert (레포 다른 테스트와 동일 관례).
        let result = try await mock.fetchDayRun(userId: "u1", documentId: "2026-01-01")
        XCTAssertNil(result)
    }
}
