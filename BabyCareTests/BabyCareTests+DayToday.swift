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

    // MARK: - Fix round 1 · load() 원자성 (리뷰 Important)

    /// 원자성 — 시간표를 못 읽으면 하루도 갱신되면 안 된다. run 만 새로 반영되고
    /// plan · cells 는 이전 값에 머물면, 화면이 서로 다른 시점을 가리키는 반쪽짜리
    /// 상태가 된다(리뷰 Important — `async let` 두 값을 따로따로 프로퍼티에 대입하면 생기는 결함).
    func testLoadDoesNotPartiallyUpdateWhenPlanFetchFails() async {
        let runs = MockDayRunFirestore()
        let plans = MockDayPlanFirestore()
        runs.seed(DayRun(id: "2026-09-03", startedAt: at(7)), userId: "u1")
        plans.seed([planWithOneBottle], userId: "u1")
        let vm = makeVM(runs: runs, plans: plans)

        // 1차 — 시간표까지 정상으로 불러와 run · cells 기준선을 세운다.
        let act = Activity(id: "a1", babyId: "b", type: .feedingBottle,
                           startTime: at(12, 10), createdAt: at(12, 10))
        await vm.load(userId: "u1", day: at(13), activities: [act])
        let baselineRun = vm.run
        let baselineCells = vm.cells
        XCTAssertEqual(baselineCells.count, 1)

        // 2차 — 하루 문서는 바뀌었지만(닫힘) 시간표를 못 읽는다.
        var changedRun = DayRun(id: "2026-09-03", startedAt: at(7))
        changedRun.closedAt = at(20)
        runs.seed(changedRun, userId: "u1")
        plans.errorToThrow = NSError(domain: "t", code: 1)
        await vm.load(userId: "u1", day: at(13), activities: [act])

        // 🔑 하나라도 실패하면 run · plan · cells 전부 이전 값 그대로다 — 반쪽 갱신 금지.
        XCTAssertEqual(vm.run, baselineRun, "시간표는 실패했는데 하루 문서만 새로 반영됐다")
        XCTAssertEqual(vm.cells, baselineCells, "run 과 cells 가 서로 다른 시점을 가리킨다")
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - Fix round 1 · closeToday() 의 세 보장 (리뷰 Minor, 미검증 구간)

    /// 닫기 저장이 실패하면 닫힌 것처럼 보이면 안 된다 — startToday 와 같은 계약.
    func testCloseSurfacesErrorAndDoesNotClaimClosed() async {
        let runs = MockDayRunFirestore()
        let vm = makeVM(runs: runs)
        await vm.startToday(userId: "u1", day: at(7))
        runs.saveError = NSError(domain: "t", code: 1)
        await vm.closeToday(userId: "u1")
        XCTAssertTrue(vm.run?.isOpen ?? false, "저장이 실패했는데 닫힌 것처럼 보인다")
        XCTAssertNotNil(vm.errorMessage)
    }

    /// 같은 하루를 두 번 닫아도 처음 닫힌 시각은 그대로다 — 두 번째는 저장을 부르지 않는 no-op.
    func testClosingTwiceDoesNotOverwriteTheOriginalClosedAt() async {
        let runs = MockDayRunFirestore()
        let vm = makeVM(runs: runs)
        await vm.startToday(userId: "u1", day: at(7))
        await vm.closeToday(userId: "u1")
        let firstClosedAt = vm.run?.closedAt
        XCTAssertNotNil(firstClosedAt)
        await vm.closeToday(userId: "u1")
        XCTAssertEqual(vm.run?.closedAt, firstClosedAt)
        XCTAssertEqual(runs.saveCount, 2, "시작 1 + 닫기 1 = 2 — 두 번째 닫기는 저장을 부르면 안 된다")
    }

    /// 열지 않은 하루를 닫으려 해도 안전한 no-op — 에러도, 저장도 없다.
    func testClosingADayThatWasNeverOpenedIsANoOp() async {
        let runs = MockDayRunFirestore()
        let vm = makeVM(runs: runs)
        await vm.closeToday(userId: "u1")
        XCTAssertNil(vm.run)
        XCTAssertEqual(runs.saveCount, 0)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - Fix round 1 · startToday() 자정 넘김 (리뷰 Minor, 미검증 구간)

    /// 자정을 넘겨 앱을 열어 둔 경우 — run 이 다른 날짜의 문서를 들고 있으면
    /// 오늘 다시 시작을 눌렀을 때 일찍 return 하지 않고 새 문서를 써야 한다.
    func testStartTodayWritesNewRunWhenExistingRunIsFromADifferentDay() async {
        let runs = MockDayRunFirestore()
        let vm = makeVM(runs: runs)
        await vm.startToday(userId: "u1", day: at(7))
        XCTAssertEqual(vm.run?.id, "2026-09-03")

        let nextDay = cal.date(byAdding: .day, value: 1, to: at(7))!
        await vm.startToday(userId: "u1", day: nextDay)
        XCTAssertEqual(vm.run?.id, "2026-09-04")
        XCTAssertEqual(runs.saveCount, 2, "다른 날이면 새 문서를 써야 한다 — 일찍 return 하면 저장이 1번에 머문다")
    }
}

// MARK: - Task 7 · 띠 카드 문구
//
// 컨트롤러 판단(2026-09-03): 브리프는 이 클래스를 BabyCareTests+DayPlan.swift(1,047줄)에
// 붙이라고 했지만, 그 파일은 .swiftlint.yml file_length error(1200)에 이미 근접해 있어
// 이 몫을 더하면 넘긴다. 대신 이 파일(BabyCareTests+DayToday.swift, Task 7이 소비하는
// TodayViewModel/DayCell과 같은 도메인)에 붙인다.

final class TodayBandCopyTests: XCTestCase {

    private func cell(_ kind: DayCell.Kind) -> DayCell {
        DayCell(id: UUID().uuidString, slotId: kind == .extra ? nil : "s", title: "분유",
                activityType: "feeding_bottle", lane: .baby, kind: kind, at: Date(), order: 0)
    }

    private var openRun: DayRun { DayRun(id: "2026-09-03", startedAt: Date()) }
    private var closedRun: DayRun {
        var r = openRun; r.closedAt = Date(); return r
    }

    func testBeforeStartInvitesToStart() {
        // fix round 1 Finding 1 — 헤드라인이 시작 버튼과 같은 문장이면 시작 전 카드가
        // 같은 말을 두 번 한다(화면엔 버튼도 그려진다). 헤드라인은 이름만 말한다.
        XCTAssertEqual(TodayBandCopy.headline(run: nil, cells: []), "우리 하루")
    }

    func testMorningWaitsForTheFirstRecord() {
        XCTAssertEqual(TodayBandCopy.headline(run: openRun, cells: [cell(.planned)]),
                       "첫 기록을 기다리는 중")
    }

    func testDaytimeCountsWhatPassed() {
        let cells = [cell(.done), cell(.done), cell(.planned)]
        XCTAssertEqual(TodayBandCopy.headline(run: openRun, cells: cells), "두 칸 지났어요")
    }

    /// 시안 「② 낮」 — 끼어든 칸이 있으면 **오늘의 칸 수**를 말한다.
    func testExtraCellsAnnounceTheNewTotal() {
        let cells = [cell(.done), cell(.extra), cell(.planned)]
        XCTAssertEqual(TodayBandCopy.headline(run: openRun, cells: cells), "오늘은 세 칸이 됐어요")
    }

    func testClosedDayIsKind() {
        XCTAssertEqual(TodayBandCopy.headline(run: closedRun, cells: [cell(.done)]), "오늘도 잘 지났어요")
    }

    // MARK: - fix round 1 Finding 2 · 둘째 줄(subheadline) — 설명이 필요한 두 상태에만 있다

    func testBeforeStartSubheadlineExplainsWhatOpeningDoes() {
        XCTAssertEqual(TodayBandCopy.subheadline(run: nil, cells: []),
                       "오늘을 열면 짜 둔 시간표가 하루 동안 흐릅니다")
    }

    func testMorningSubheadlineExplainsWhatComesNext() {
        XCTAssertEqual(TodayBandCopy.subheadline(run: openRun, cells: [cell(.planned)]),
                       "첫 기록이 오면 오늘 시간이 정해져요")
    }

    func testDaytimeSubheadlineIsNil() {
        let cells = [cell(.done), cell(.planned)]
        XCTAssertNil(TodayBandCopy.subheadline(run: openRun, cells: cells))
    }

    func testClosedSubheadlineIsNil() {
        XCTAssertNil(TodayBandCopy.subheadline(run: closedRun, cells: [cell(.done)]))
    }

    /// 🔴 설계 §2 결정 6 · §5 — 재촉·지연·분수는 **어떤 상태에서도**, **헤드라인·둘째 줄 어디에도**
    /// 나오지 않는다. fix round 1 Finding 3 — 이름이 "어떤 상태에서도"라면 끼어든 칸(낮 ②)도
    /// 걸어야 한다. 빠뜨리면 이름이 거짓말하는 테스트가 된다.
    func testNeverNagsInAnyState() {
        let states: [(DayRun?, [DayCell])] = [
            (nil, []), (openRun, [cell(.planned)]),
            (openRun, [cell(.done), cell(.planned)]),
            (openRun, [cell(.done), cell(.extra), cell(.planned)]),
            (closedRun, [cell(.done), cell(.planned)])
        ]
        for (run, cells) in states {
            let texts = [TodayBandCopy.headline(run: run, cells: cells),
                         TodayBandCopy.subheadline(run: run, cells: cells)].compactMap { $0 }
            for text in texts {
                for banned in ["지연", "늦", "밀렸", "못 한", "/", "연속"] {
                    XCTAssertFalse(text.contains(banned), "「\(banned)」가 문구에 있다: \(text)")
                }
            }
        }
    }
}

// MARK: - PO 결정 2026-09-05 · 카드가 무엇을 그릴지는 **한 자리**에서 정한다
//
// ① 시간표가 없으면 카드를 아예 안 그린다(PO 결정) · ③ 실패는 화면이 말한다 ·
// ④ 못 읽었으면 오늘 문서를 덮어쓰지 않는다.
// 🧩 판정을 카드 안에 두면 「숨긴다」와 「못 읽었다」가 화면마다 갈라진다 — `presentation` 하나만 본다.

@MainActor
final class TodayCardPresentationTests: XCTestCase {

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

    private var plan: DayPlan {
        DayPlan(id: "p", name: "우리 하루", entries: [
            DayPlan.Entry(id: "milk", title: "분유", activityType: "feeding_bottle",
                          schedule: .fixedTimes(minutesOfDay: [12 * 60]), order: 0)
        ])
    }

    /// 🔴 PO 결정 — 시간표를 안 짠 사람에게 카드는 **아예 안 뜬다**.
    /// 뜨면 「오늘을 열면 짜 둔 시간표가 하루 동안 흐릅니다」가 지킬 수 없는 약속이 된다
    /// (시간표가 없으면 칸이 영원히 안 채워진다).
    func testCardIsHiddenWhenThereIsNoPlan() async {
        let vm = makeVM()
        await vm.load(userId: "u1", day: at(13), activities: [])
        XCTAssertEqual(vm.presentation, .hidden)
    }

    /// 🔴 **못 읽은 것을 「없다」고 말하지 않는다.** 실패를 숨김으로 처리하면
    /// 규칙 배포를 잊어도·통신이 끊겨도 화면에 아무 신호가 없다(리뷰 C3).
    func testLoadFailureIsNotMistakenForHavingNoPlan() async {
        let plans = MockDayPlanFirestore()
        plans.errorToThrow = NSError(domain: "t", code: 1)
        let vm = makeVM(plans: plans)
        await vm.load(userId: "u1", day: at(13), activities: [])
        XCTAssertEqual(vm.presentation, .failed)
    }

    /// 읽기 전엔 있다고도 없다고도 하지 않는다 — 시간표 있는 사람 화면이 깜빡이면 안 된다.
    func testNothingIsDecidedBeforeTheFirstLoad() {
        XCTAssertEqual(makeVM().presentation, .loading)
    }

    func testCardIsDrawnWhenAPlanExists() async {
        let plans = MockDayPlanFirestore()
        plans.seed([plan], userId: "u1")
        let vm = makeVM(plans: plans)
        await vm.load(userId: "u1", day: at(13), activities: [])
        XCTAssertEqual(vm.presentation, .ready)
    }

    /// 🔙 되돌리는 길 — 「다시 시도」가 통하면 실패에서 빠져나온다(붙인 날부터 안 재지는 자리).
    func testRetryAfterAFailureRecovers() async {
        let plans = MockDayPlanFirestore()
        plans.errorToThrow = NSError(domain: "t", code: 1)
        let vm = makeVM(plans: plans)
        await vm.load(userId: "u1", day: at(13), activities: [])
        XCTAssertEqual(vm.presentation, .failed)

        plans.errorToThrow = nil
        plans.seed([plan], userId: "u1")
        await vm.load(userId: "u1", day: at(13), activities: [])
        XCTAssertEqual(vm.presentation, .ready)
        XCTAssertNil(vm.errorMessage)
    }

    /// 🔴 ④ — 못 읽은 상태에서 시작하면 `setData` 가 오늘 문서를 **통째로 덮어쓴다**.
    /// 이미 닫은 하루가 되살아난다. **모르면 쓰지 않는다.**
    func testStartDoesNotOverwriteTodayWhenTheLoadFailed() async {
        let runs = MockDayRunFirestore()
        var closed = DayRun(id: "2026-09-03", startedAt: at(7))
        closed.closedAt = at(20)
        runs.seed(closed, userId: "u1")
        runs.fetchError = NSError(domain: "t", code: 1)
        let vm = makeVM(runs: runs)
        await vm.load(userId: "u1", day: at(13), activities: [])
        XCTAssertEqual(runs.saveCount, 0)

        await vm.startToday(userId: "u1", day: at(13))

        XCTAssertEqual(runs.saveCount, 0, "못 읽었는데 오늘 문서를 덮어썼다 — 닫은 하루가 되살아난다")
        XCTAssertNil(vm.run, "열리지 않았는데 열린 것처럼 보인다")
    }
}

// MARK: - ⑦ 내 줄(lane) — 아기 기록이 부모 칸을 채우지 않는다
//
// 🔴 같은 모양의 결함이 이 트랙에서 **세 번째**다(3.5 activityType · 4 babyLine · 지금 lane).
// 지금은 시트에 줄 고르기가 없어 전부 `.baby` 라 잠들어 있지만, 설계 §5 의 「내 줄」이
// ②-B 에서 켜지는 순간 부모 칸이 아기 기록을 먹고 아기 칸이 빈다.

final class DaySlotFillerLaneTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func at(_ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: h, minute: m))!
    }

    private func activity(_ type: Activity.ActivityType, _ start: Date) -> Activity {
        Activity(id: "a-\(type.rawValue)-\(start.timeIntervalSince1970)", babyId: "b", type: type,
                 startTime: start, createdAt: start)
    }

    private func slot(_ id: String, _ type: Activity.ActivityType?, at plannedAt: Date?,
                      lane: DayPlan.Lane) -> DayPlanExpander.Slot {
        DayPlanExpander.Slot(id: id, entryId: id, title: id, activityType: type?.rawValue,
                             lane: lane, plannedAt: plannedAt, order: 0)
    }

    /// 부모가 「나도 한숨 자기」를 짜 뒀는데 **아기가 잔 기록**이 그 칸을 채우면 하루가 거짓이 된다.
    func testParentLaneSlotIsNotFilledByTheBabysRecord() {
        let slots = [slot("mine", .sleep, at: at(13), lane: .parent)]
        let cells = DaySlotFiller.fill(slots: slots, activities: [activity(.sleep, at(13, 5))],
                                       on: at(14), calendar: cal)
        XCTAssertEqual(cells.first(where: { $0.slotId == "mine" })?.kind, .planned,
                       "아기 수면 기록이 부모 칸을 채웠다")
    }

    /// 그 기록이 사라지진 않는다 — 아이 줄의 끼어든 칸으로 남는다.
    func testTheRecordStillShowsUpAsAnExtraOnTheBabysLane() {
        let slots = [slot("mine", .sleep, at: at(13), lane: .parent)]
        let cells = DaySlotFiller.fill(slots: slots, activities: [activity(.sleep, at(13, 5))],
                                       on: at(14), calendar: cal)
        let extra = cells.first(where: { $0.kind == .extra })
        XCTAssertNotNil(extra, "부모 칸에 안 붙였으면 끼어든 칸으로라도 남아야 한다")
        XCTAssertEqual(extra?.lane, .baby)
    }

    /// 🔒 「전부 막는」 구현도 초록이 되지 않게 — 아이 줄은 그대로 채워진다.
    func testBabyLaneStillFillsNormally() {
        let slots = [slot("baby", .sleep, at: at(13), lane: .baby)]
        let cells = DaySlotFiller.fill(slots: slots, activities: [activity(.sleep, at(13, 5))],
                                       on: at(14), calendar: cal)
        XCTAssertEqual(cells.first(where: { $0.slotId == "baby" })?.kind, .done)
    }
}

// MARK: - ⑥ 시트가 「고르지 않음」이라 말하는데 실제로는 채워진다
//
// 🔴 `Entry.recordType` = `activityType ?? schedule.anchorType`(Task 3.5). 「첫 분유부터」로 짜면
// 비워 둬도 분유 기록이 그 칸을 채우는데, 화면은 「고르지 않음」이라 말한다 — **기본 경로에서 거짓말**.

final class PlanEntryRecordTypeTruthTests: XCTestCase {

    private func afterFirstBottle() -> PlanEntryDraft {
        var d = PlanEntryDraft(title: "분유", kind: .afterFirst)
        d.anchorType = "feeding_bottle"
        d.everyMinutes = 180
        d.count = 6
        return d
    }

    func testAfterFirstWithoutAnExplicitTypeIsFilledByTheAnchor() {
        let d = afterFirstBottle()
        XCTAssertEqual(d.effectiveRecordType, "feeding_bottle")
        XCTAssertEqual(d.recordTypeLabel, "분유", "채워질 종류가 있는데 화면이 다른 말을 한다")
    }

    /// 진짜로 채울 것이 없는 일(내 밥·샤워)은 그대로 「고르지 않음」이다.
    func testFixedTimesWithoutATypeReallyHasNone() {
        var d = PlanEntryDraft(title: "내 밥", kind: .fixedTimes)
        d.minutesOfDay = [12 * 60]
        XCTAssertNil(d.effectiveRecordType)
        XCTAssertEqual(d.recordTypeLabel, "고르지 않음")
    }

    /// 명시로 고른 것이 정박 종류를 이긴다.
    func testAnExplicitChoiceWins() {
        var d = afterFirstBottle()
        d.activityType = "sleep"
        XCTAssertEqual(d.effectiveRecordType, "sleep")
        XCTAssertEqual(d.recordTypeLabel, "수면")
    }

    /// 선택지 이름도 사실대로 — 정박 종류가 이미 답을 갖고 있으면 「고르지 않음」이 아니다.
    /// (누르면 「분유」가 뜨는 「고르지 않음」 버튼은 같은 거짓말의 작은 판이다.)
    func testTheUnsetOptionSaysWhatItActuallyMeans() {
        XCTAssertEqual(afterFirstBottle().unsetRecordTypeLabel, "첫 기록 종류 그대로")
        var plain = PlanEntryDraft(title: "내 밥", kind: .fixedTimes)
        plain.minutesOfDay = [12 * 60]
        XCTAssertEqual(plain.unsetRecordTypeLabel, "고르지 않음")
    }

    /// 🔑 화면이 말하는 것 = **저장되는 것**. 두 자리가 갈라지면 거짓말이 다시 시작된다.
    func testTheLabelAgreesWithTheEntryThatGetsSaved() {
        let d = afterFirstBottle()
        let entry = d.build(order: 0)
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.recordType, d.effectiveRecordType)
    }
}
