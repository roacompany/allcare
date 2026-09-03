import XCTest
@testable import BabyCare

// 분리: BabyCareTests+DayPlan.swift 가 아닌 새 파일 — DayPlan 파일이 1,047줄이라
// .swiftlint.yml file_length error 1200 에 이 태스크 몫을 더하면 넘긴다(컨트롤러 판단).
// 포함 클래스: DayRunStoreTests (Task 5 · dayRuns 저장소 계약) · TodayViewModelTests (Task 6 · 오늘 VM — 열고 이어 붙이고 닫는다)

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

// MARK: - Task 6 · 오늘 VM

@MainActor
final class TodayViewModelTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func at(_ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: h, minute: m))!
    }

    private func makeVM(runs: MockDayRunFirestore = .init(),
                        plans: MockDayPlanFirestore = .init()) -> TodayViewModel {
        TodayViewModel(dayRunProvider: runs, planProvider: plans, calendar: cal)
    }

    private var planWithOneBottle: DayPlan {
        DayPlan(id: "p", name: "우리 하루", entries: [
            DayPlan.Entry(id: "milk", title: "분유", activityType: "feeding_bottle",
                          schedule: .fixedTimes(minutesOfDay: [12 * 60]), order: 0)
        ])
    }

    func testStartTodayWritesOneDocumentPerDay() async {
        let runs = MockDayRunFirestore()
        let vm = makeVM(runs: runs)
        await vm.startToday(userId: "u1", day: at(7))
        XCTAssertEqual(vm.run?.id, "2026-09-03")
        XCTAssertTrue(vm.run?.isOpen == true)
        XCTAssertEqual(runs.saveCount, 1)
    }

    /// 같은 날 두 번 눌러도 하루는 하나다 — 시작 시각이 리셋되면 안 된다.
    func testStartingTwiceKeepsTheFirstStartTime() async {
        let runs = MockDayRunFirestore()
        let vm = makeVM(runs: runs)
        await vm.startToday(userId: "u1", day: at(7))
        let first = vm.run?.startedAt
        await vm.startToday(userId: "u1", day: at(9))
        XCTAssertEqual(vm.run?.startedAt, first)
    }

    func testCloseTodayMarksItClosed() async {
        let vm = makeVM()
        await vm.startToday(userId: "u1", day: at(7))
        await vm.closeToday(userId: "u1")
        XCTAssertFalse(vm.run?.isOpen ?? true)
    }

    /// 시간표 + 기록 → 칸. VM 은 이어 붙이기만 하고 규칙은 순수 함수가 갖는다.
    func testCellsComeFromPlanAndActivities() async {
        let plans = MockDayPlanFirestore()
        plans.seed([planWithOneBottle], userId: "u1")
        let vm = makeVM(plans: plans)
        let act = Activity(id: "a1", babyId: "b", type: .feedingBottle,
                           startTime: at(12, 10), createdAt: at(12, 10))
        await vm.load(userId: "u1", day: at(13), activities: [act])
        XCTAssertEqual(vm.cells.count, 1)
        XCTAssertEqual(vm.cells[0].kind, .done)
        XCTAssertEqual(vm.cells[0].at, at(12, 10))
    }

    /// 🔙 불러오기 실패를 삼키지 않는다 — 「없는 하루」와 「못 읽은 하루」는 다르다.
    func testLoadSurfacesError() async {
        let runs = MockDayRunFirestore()
        runs.fetchError = NSError(domain: "t", code: 1)
        let vm = makeVM(runs: runs)
        await vm.load(userId: "u1", day: at(13), activities: [])
        XCTAssertNotNil(vm.errorMessage)
    }

    /// 시작 실패도 삼키지 않는다 — 눌렀는데 아무 일도 안 일어나면 손님은 다시 누른다.
    func testStartSurfacesErrorAndDoesNotClaimSuccess() async {
        let runs = MockDayRunFirestore()
        runs.saveError = NSError(domain: "t", code: 1)
        let vm = makeVM(runs: runs)
        await vm.startToday(userId: "u1", day: at(7))
        XCTAssertNil(vm.run, "저장이 실패했는데 열린 것처럼 보인다")
        XCTAssertNotNil(vm.errorMessage)
    }

    func testSummaryIsNilWhileNothingHappened() async {
        let vm = makeVM()
        await vm.load(userId: "u1", day: at(13), activities: [])
        XCTAssertNil(vm.summaryLine(babyName: "서준"))
    }
}
