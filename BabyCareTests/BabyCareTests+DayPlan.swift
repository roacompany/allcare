import XCTest
@testable import BabyCare

final class DayPlanTests: XCTestCase {

    // rawValue 는 Firestore 영구 계약 — 바뀌면 기존 문서가 깨진다
    func testScheduleKindRawValuesAreContract() {
        XCTAssertEqual(PlanSchedule.Kind.fixedTimes.rawValue, "fixed_times")
        XCTAssertEqual(PlanSchedule.Kind.afterFirst.rawValue, "after_first")
        XCTAssertEqual(PlanSchedule.Kind.afterEntry.rawValue, "after_entry")
        XCTAssertEqual(DayPlan.Lane.baby.rawValue, "baby")
        XCTAssertEqual(DayPlan.Lane.parent.rawValue, "parent")
    }

    func testDayPlanRoundTripsThroughJSON() throws {
        let plan = DayPlan(
            id: "p1",
            name: "신생아 시간표",
            entries: [
                DayPlan.Entry(
                    id: "e1", title: "분유", activityType: "feeding_bottle", lane: .baby,
                    schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 6),
                    order: 0
                ),
                DayPlan.Entry(
                    id: "e2", title: "내 밥", activityType: nil, lane: .parent,
                    schedule: .fixedTimes(minutesOfDay: [720]),
                    order: 1
                ),
                DayPlan.Entry(
                    id: "e3", title: "다음 유축", activityType: nil, lane: .baby,
                    schedule: .afterEntry(entryId: "e1", offsetMinutes: 30),
                    order: 2
                )
            ]
        )
        let data = try JSONEncoder().encode(plan)
        let back = try JSONDecoder().decode(DayPlan.self, from: data)
        XCTAssertEqual(back, plan)
        XCTAssertEqual(back.entries[0].schedule.everyMinutes, 180)
        XCTAssertEqual(back.entries[1].schedule.minutesOfDay, [720])
        XCTAssertEqual(back.entries[2].schedule.afterEntryId, "e1")
        XCTAssertEqual(back.entries[2].schedule.offsetMinutes, 30)
    }

    // 옛 문서에 없던 필드가 들어와도 깨지지 않아야 한다
    func testDecodesDocumentWithoutOptionalFields() throws {
        let json = """
        {"id":"p1","name":"표"}
        """.data(using: .utf8)!
        let back = try JSONDecoder().decode(DayPlan.self, from: json)
        XCTAssertEqual(back.entries.count, 0)
        XCTAssertNil(back.babyId)
        XCTAssertTrue(back.isActive)   // 없으면 활성으로 본다
        XCTAssertEqual(back.createdAt, Date(timeIntervalSince1970: 0))  // 없으면 epoch
    }

    // 미지의 kind rawValue는 .unknown으로 폴백 (신버전 기능 forward-compat)
    func testUnknownScheduleKindDecodesWithoutError() throws {
        let json = """
        {"kind":"weekday","minutesOfDay":null,"anchorType":null,"everyMinutes":null,"count":null,"afterEntryId":null,"offsetMinutes":null}
        """.data(using: .utf8)!
        let schedule = try JSONDecoder().decode(PlanSchedule.self, from: json)
        XCTAssertEqual(schedule.kind, .unknown)
    }

    // .unknown 센티넬은 encode 시 throw (데이터 손실 방지)
    func testUnknownScheduleKindEncodingThrows() throws {
        let schedule = PlanSchedule(kind: .unknown, minutesOfDay: nil, anchorType: nil, everyMinutes: nil, count: nil, afterEntryId: nil, offsetMinutes: nil)
        XCTAssertThrowsError(try JSONEncoder().encode(schedule)) { error in
            if case let .invalidValue(_, context) = error as? EncodingError {
                XCTAssertTrue(context.debugDescription.contains("read-only 센티넬"))
            } else {
                XCTFail("Expected EncodingError.invalidValue")
            }
        }
    }

    // 미지의 lane rawValue는 .baby로 폴백 (row 보존 · 모르는 줄도 아이 줄로 처리)
    func testUnknownLaneDecodesWithoutError() throws {
        let json = """
        {"id":"e1","title":"무언가","activityType":null,"lane":"futureLane","schedule":{"kind":"fixed_times","minutesOfDay":[720],"anchorType":null,"everyMinutes":null,"count":null,"afterEntryId":null,"offsetMinutes":null},"order":0}
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(DayPlan.Entry.self, from: json)
        XCTAssertEqual(entry.lane, .baby)  // 미지의 lane → .baby
    }
}

final class DayPlanExpanderTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    /// 2026-09-02 정오 — 월 중간·정오로 잡아 타임존 경계 이슈를 피한다
    private var day: Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 12))!
    }

    private func at(_ hour: Int, _ minute: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: hour, minute: minute))!
    }

    private func plan(_ entries: [DayPlan.Entry]) -> DayPlan {
        DayPlan(id: "p", name: "표", entries: entries)
    }

    // A — 고정 시각은 정박점 없이도 바로 자리를 잡는다
    func testFixedTimesProducesOneSlotPerTime() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "목욕", lane: .baby,
                          schedule: .fixedTimes(minutesOfDay: [19 * 60 + 30]), order: 0)
        ])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots[0].plannedAt, at(19, 30))
        XCTAssertEqual(slots[0].title, "목욕")
    }

    // B — 첫 기록이 없으면 자리는 있되 시각이 미정이다
    func testAfterFirstWithoutAnchorIsUnscheduledButPresent() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "분유", activityType: "feeding_bottle", lane: .baby,
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 6),
                          order: 0)
        ])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertEqual(slots.count, 6)
        XCTAssertTrue(slots.allSatisfy { $0.plannedAt == nil })
    }

    // B — 첫 기록이 들어오면 그 시각부터 펼쳐진다
    func testAfterFirstAnchorsOnFirstRecord() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "분유", activityType: "feeding_bottle", lane: .baby,
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 4),
                          order: 0)
        ])
        let anchors = DayAnchors(firstRecordByType: ["feeding_bottle": at(6, 20)])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: anchors, calendar: cal)
        XCTAssertEqual(slots.compactMap(\.plannedAt), [at(6, 20), at(9, 20), at(12, 20), at(15, 20)])
    }

    // B — 그날을 넘어가는 칸은 버린다(하루 시간표는 그날 것이다)
    func testAfterFirstDropsSlotsPastEndOfDay() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "분유", activityType: "feeding_bottle", lane: .baby,
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 6),
                          order: 0)
        ])
        let anchors = DayAnchors(firstRecordByType: ["feeding_bottle": at(20, 0)])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: anchors, calendar: cal)
        XCTAssertEqual(slots.compactMap(\.plannedAt), [at(20, 0), at(23, 0)])
    }

    // D — 앞 일이 끝나야 다음이 자리를 잡는다
    func testAfterEntryAnchorsOnPrecedingCompletion() {
        let p = plan([
            DayPlan.Entry(id: "bath", title: "목욕", lane: .baby,
                          schedule: .fixedTimes(minutesOfDay: [19 * 60 + 30]), order: 0),
            DayPlan.Entry(id: "bed", title: "잠자리", lane: .baby,
                          schedule: .afterEntry(entryId: "bath", offsetMinutes: 30), order: 1)
        ])
        let none = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertNil(none.first(where: { $0.entryId == "bed" })?.plannedAt)

        let done = DayAnchors(completedByEntry: ["bath": at(19, 45)])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: done, calendar: cal)
        XCTAssertEqual(slots.first(where: { $0.entryId == "bed" })?.plannedAt, at(20, 15))
    }

    // 정렬 — 시각이 정해진 것은 시각순, 미정은 맨 앞(하루의 시작을 기다리는 자리)
    func testSlotsSortUnscheduledFirstThenByTime() {
        let p = plan([
            DayPlan.Entry(id: "bath", title: "목욕", lane: .baby,
                          schedule: .fixedTimes(minutesOfDay: [19 * 60 + 30]), order: 1),
            DayPlan.Entry(id: "milk", title: "분유", activityType: "feeding_bottle", lane: .baby,
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 1),
                          order: 0),
            DayPlan.Entry(id: "lunch", title: "내 밥", lane: .parent,
                          schedule: .fixedTimes(minutesOfDay: [12 * 60]), order: 2)
        ])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertEqual(slots.map(\.entryId), ["milk", "lunch", "bath"])
    }

    // 줄이 둘이다 — 내 줄이 섞여 나온다
    func testSlotsCarryLane() {
        let p = plan([
            DayPlan.Entry(id: "lunch", title: "내 밥", lane: .parent,
                          schedule: .fixedTimes(minutesOfDay: [12 * 60]), order: 0)
        ])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertEqual(slots[0].lane, .parent)
    }

    // 같은 항목의 칸들은 서로 다른 id 를 갖는다(붙이기 단계가 이걸 쓴다)
    func testSlotIdsAreUniquePerOccurrence() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "분유", activityType: "feeding_bottle", lane: .baby,
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 3),
                          order: 0)
        ])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertEqual(Set(slots.map(\.id)).count, 3)
    }

    // 비활성 시간표는 펼쳐지지 않는다
    func testInactivePlanProducesNoSlots() {
        var p = plan([
            DayPlan.Entry(id: "e1", title: "목욕", lane: .baby,
                          schedule: .fixedTimes(minutesOfDay: [1170]), order: 0)
        ])
        p.isActive = false
        XCTAssertTrue(DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal).isEmpty)
    }

    // 미지의 kind(.unknown) — Task 1 이 forward-compat 로 추가한 센티넬. 언제인지 알 수 없으니
    // 시각을 지어내지 않고 칸을 아예 만들지 않는다. 형제 항목은 그 영향을 받지 않고 정상 펼쳐진다.
    func testUnknownScheduleKindProducesNoSlotsButSiblingsStillExpand() {
        let futureSchedule = PlanSchedule(
            kind: .unknown, minutesOfDay: nil, anchorType: nil,
            everyMinutes: nil, count: nil, afterEntryId: nil, offsetMinutes: nil
        )
        let p = plan([
            DayPlan.Entry(id: "future", title: "미래 기능", lane: .baby, schedule: futureSchedule, order: 0),
            DayPlan.Entry(id: "bath", title: "목욕", lane: .baby,
                          schedule: .fixedTimes(minutesOfDay: [19 * 60 + 30]), order: 1)
        ])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertTrue(slots.allSatisfy { $0.entryId != "future" })
        XCTAssertEqual(slots.map(\.entryId), ["bath"])
        XCTAssertEqual(slots[0].plannedAt, at(19, 30))
    }

    // F1(리뷰) — 앞 항목은 끝났지만 계산된 시각이 자정을 넘으면, 미정이 아니라 아예 칸이 없다
    // (오늘 것이 아니다). 같은 plan 의 다른 항목은 그대로 나온다 — 자정을 넘는 항목 하나가
    // 하루 전체를 끌고 가지 않는다.
    func testAfterEntryDropsWhenCompletionPushesPastMidnight() {
        let p = plan([
            DayPlan.Entry(id: "bath", title: "목욕", lane: .baby,
                          schedule: .fixedTimes(minutesOfDay: [23 * 60 + 45]), order: 0),
            DayPlan.Entry(id: "bed", title: "잠자리", lane: .baby,
                          schedule: .afterEntry(entryId: "bath", offsetMinutes: 30), order: 1),
            DayPlan.Entry(id: "lunch", title: "내 밥", lane: .parent,
                          schedule: .fixedTimes(minutesOfDay: [12 * 60]), order: 2)
        ])
        let done = DayAnchors(completedByEntry: ["bath": at(23, 50)])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: done, calendar: cal)
        XCTAssertTrue(slots.allSatisfy { $0.entryId != "bed" })
        XCTAssertEqual(slots.map(\.entryId), ["lunch", "bath"])
    }

    // F2(리뷰) — 하루 경계는 양쪽 다 잰다: 자정 이전으로 새는 음수 minutesOfDay 는 버린다.
    func testFixedTimesDropsNegativeMinutesOfDay() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "밤중수유", lane: .baby,
                          schedule: .fixedTimes(minutesOfDay: [-30]), order: 0)
        ])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertTrue(slots.isEmpty)
    }

    // F2(리뷰) — 완료 시각은 오늘인데 음수 offsetMinutes 가 어제로 밀어내면 버린다.
    // (하루 경계는 양쪽 다 — 시작 쪽도 잰다.)
    func testAfterEntryDropsWhenOffsetPushesBeforeStartOfDay() {
        let p = plan([
            DayPlan.Entry(id: "wake", title: "기상", lane: .baby,
                          schedule: .fixedTimes(minutesOfDay: [0]), order: 0),
            DayPlan.Entry(id: "prep", title: "준비", lane: .baby,
                          schedule: .afterEntry(entryId: "wake", offsetMinutes: -30), order: 1)
        ])
        let done = DayAnchors(completedByEntry: ["wake": at(0, 10)])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: done, calendar: cal)
        XCTAssertEqual(slots.map(\.entryId), ["wake"])
    }

    // F3(리뷰) — count 가 하루에 다 못 들어갈 만큼 커도(표현 가능한 최대값) 실제로 들어가는
    // 칸만 나오고 멈춘다 — 무한(또는 초장시간) 반복으로 메인 스레드를 얼리지 않는다.
    func testAfterFirstHugeCountYieldsOnlyOccurrencesThatFitInDay() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "분유", activityType: "feeding_bottle", lane: .baby,
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: Int.max),
                          order: 0)
        ])
        let anchors = DayAnchors(firstRecordByType: ["feeding_bottle": at(20, 0)])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: anchors, calendar: cal)
        XCTAssertEqual(slots.compactMap(\.plannedAt), [at(20, 0), at(23, 0)])
    }

    // F3(리뷰) — 오버플로우를 일으킬 만큼 큰 everyMinutes 라도 트랩(크래시)하지 않는다.
    // (every*i 곱셈 대신 Calendar 로 한 칸씩 전진하기 때문 — count 는 겨우 3.)
    func testAfterFirstHugeEveryMinutesDoesNotCrash() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "분유", activityType: "feeding_bottle", lane: .baby,
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: Int.max - 5, count: 3),
                          order: 0)
        ])
        let anchors = DayAnchors(firstRecordByType: ["feeding_bottle": at(6, 20)])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: anchors, calendar: cal)
        XCTAssertEqual(slots.compactMap(\.plannedAt), [at(6, 20)])
    }
}

final class DayPlanStoreTests: XCTestCase {

    func testCollectionConstantIsStable() {
        XCTAssertEqual(FirestoreCollections.dayPlans, "dayPlans")
    }

    func testMockRoundTrip() async throws {
        let mock = MockDayPlanFirestore()
        let plan = DayPlan(id: "p1", name: "표")
        try await mock.saveDayPlan(plan, userId: "u1")
        let back = try await mock.fetchDayPlans(userId: "u1")
        XCTAssertEqual(back, [plan])
        try await mock.deleteDayPlan("p1", userId: "u1")
        let empty = try await mock.fetchDayPlans(userId: "u1")
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(mock.saveCount, 1)
        XCTAssertEqual(mock.deleteCount, 1)
    }

    func testMockIsolatesUsers() async throws {
        let mock = MockDayPlanFirestore()
        try await mock.saveDayPlan(DayPlan(id: "p1", name: "내 것"), userId: "u1")
        let other = try await mock.fetchDayPlans(userId: "u2")
        XCTAssertTrue(other.isEmpty)
    }

    // 리뷰 F1 — Mock 이 insertion order 를 돌려주면, 실제 서비스(createdAt 오름차순 쿼리)와
    // 달라서 later task 의 리스트 정렬 테스트가 Mock 에는 통과하고 프로덕션에서는 틀릴 수 있다.
    // 나중(두 번째) 저장한 쪽이 더 이른 createdAt 을 갖게 해서, insertion order 로는 틀리고
    // createdAt 오름차순으로만 맞는 배치를 만든다.
    func testFetchDayPlansOrdersByCreatedAtNotInsertionOrder() async throws {
        let mock = MockDayPlanFirestore()
        let savedFirstButNewer = DayPlan(id: "a", name: "나중 생성", createdAt: Date(timeIntervalSince1970: 200))
        let savedSecondButOlder = DayPlan(id: "b", name: "먼저 생성", createdAt: Date(timeIntervalSince1970: 100))
        try await mock.saveDayPlan(savedFirstButNewer, userId: "u1")
        try await mock.saveDayPlan(savedSecondButOlder, userId: "u1")
        let result = try await mock.fetchDayPlans(userId: "u1")
        XCTAssertEqual(result.map(\.id), ["b", "a"])
    }

    // 리뷰 F1 — createdAt 이 동률이면 Firestore 는 마지막 explicit orderBy 와 같은 방향(오름차순)으로
    // 문서 id 를 암묵적 tie-break 로 쓴다. insertion order 로 저장해도 id 오름차순으로 나와야 한다.
    func testFetchDayPlansTieBreaksByIdWhenCreatedAtMatches() async throws {
        let mock = MockDayPlanFirestore()
        let tie = Date(timeIntervalSince1970: 500)
        let savedFirst = DayPlan(id: "b", name: "B", createdAt: tie)
        let savedSecond = DayPlan(id: "a", name: "A", createdAt: tie)
        try await mock.saveDayPlan(savedFirst, userId: "u1")
        try await mock.saveDayPlan(savedSecond, userId: "u1")
        let result = try await mock.fetchDayPlans(userId: "u1")
        XCTAssertEqual(result.map(\.id), ["a", "b"])
    }
}

@MainActor
final class DayPlanViewModelTests: XCTestCase {

    func testLoadPopulatesPlans() async {
        let mock = MockDayPlanFirestore()
        mock.seed([DayPlan(id: "p1", name: "표")], userId: "owner")
        let vm = DayPlanViewModel(provider: mock)
        await vm.load(userId: "owner")
        XCTAssertEqual(vm.plans.map(\.id), ["p1"])
        XCTAssertNil(vm.errorMessage)
    }

    func testSaveWritesToOwnerPath() async {
        let mock = MockDayPlanFirestore()
        let vm = DayPlanViewModel(provider: mock)
        await vm.save(DayPlan(id: "p1", name: "표"), userId: "owner")
        XCTAssertEqual(mock.saveCount, 1)
        XCTAssertEqual(mock.capturedUserIds, ["owner"])
    }

    // 실패를 삼키지 않는다 — 조용한 실패가 이 프로젝트의 반복 결함이다
    func testSaveSurfacesError() async {
        let mock = MockDayPlanFirestore()
        mock.errorToThrow = NSError(domain: "test", code: 1)
        let vm = DayPlanViewModel(provider: mock)
        await vm.save(DayPlan(id: "p1", name: "표"), userId: "owner")
        XCTAssertNotNil(vm.errorMessage)
    }

    // 되돌리는 길도 재야 한다
    func testDeleteRemovesFromList() async {
        let mock = MockDayPlanFirestore()
        mock.seed([DayPlan(id: "p1", name: "표")], userId: "owner")
        let vm = DayPlanViewModel(provider: mock)
        await vm.load(userId: "owner")
        await vm.delete(DayPlan(id: "p1", name: "표"), userId: "owner")
        XCTAssertTrue(vm.plans.isEmpty)
        XCTAssertEqual(mock.deleteCount, 1)
    }

    // F1(리뷰) — errorMessage 만으론 부족하다: rollback(plans = previous)이 실제로
    // 목록을 저장 전 상태로 되돌렸는지까지 잰다. 이 줄이 지워지거나 낙관적 반영이
    // do/catch 뒤로 옮겨져도 phantom(저장 안 된 새 항목)이 남을 수 있는데, 예전
    // 테스트(errorMessage != nil)는 그 경우에도 계속 초록이었다.
    func testSaveSurfacesErrorAndRollsBackPlans() async {
        let mock = MockDayPlanFirestore()
        let existing = [DayPlan(id: "p1", name: "기존 표")]
        mock.seed(existing, userId: "owner")
        let vm = DayPlanViewModel(provider: mock)
        await vm.load(userId: "owner")

        mock.errorToThrow = NSError(domain: "test", code: 1)
        await vm.save(DayPlan(id: "p2", name: "유령 표"), userId: "owner")

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(vm.plans, existing)  // p2 가 남아있으면 안 된다 — 저장 전과 정확히 같아야 한다
    }

    // F2(리뷰) — delete 의 실패 경로는 이제까지 아무 것도 재지 않았다("되돌리는 길도 재야
    // 한다"는 주석만 있고 정작 되돌아오지 않는 경우는 안 쟀다). 실패한 삭제는 화면에서
    // 사라지면 안 된다 — errorMessage 와 plans 잔존을 함께 잰다.
    func testDeleteSurfacesError() async {
        let mock = MockDayPlanFirestore()
        let existing = [DayPlan(id: "p1", name: "표")]
        mock.seed(existing, userId: "owner")
        let vm = DayPlanViewModel(provider: mock)
        await vm.load(userId: "owner")

        mock.errorToThrow = NSError(domain: "test", code: 1)
        await vm.delete(DayPlan(id: "p1", name: "표"), userId: "owner")

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(vm.plans, existing)  // 실패한 삭제는 목록에서 사라지면 안 된다
    }

    // F3(리뷰) — save 는 append-or-replace 다. optimisticReplace 를 쓰지 않은 근거(Task 4
    // 결정 3)가 바로 이 append 분기 — 이 테스트가 없으면 나중에 helper 로 바꿔도 아무 것도
    // 실패하지 않는다.
    func testSaveAppendsNewPlan() async {
        let mock = MockDayPlanFirestore()
        mock.seed([DayPlan(id: "p1", name: "기존 표")], userId: "owner")
        let vm = DayPlanViewModel(provider: mock)
        await vm.load(userId: "owner")

        await vm.save(DayPlan(id: "p2", name: "새 표"), userId: "owner")

        XCTAssertEqual(vm.plans.map(\.id), ["p1", "p2"])
    }

    // F3(리뷰) — 기존 id 로 저장하면 자리에서 교체되고, 중복으로 늘어나지 않는다.
    func testSaveReplacesExistingPlanInPlaceWithoutDuplicating() async {
        let mock = MockDayPlanFirestore()
        mock.seed([DayPlan(id: "p1", name: "원래 이름")], userId: "owner")
        let vm = DayPlanViewModel(provider: mock)
        await vm.load(userId: "owner")

        let renamed = DayPlan(id: "p1", name: "바뀐 이름")
        await vm.save(renamed, userId: "owner")

        XCTAssertEqual(vm.plans.count, 1)
        XCTAssertEqual(vm.plans, [renamed])
    }
}

final class PlanEntryDraftTests: XCTestCase {

    func testFixedTimesRequiresAtLeastOneTime() {
        var d = PlanEntryDraft(title: "목욕", kind: .fixedTimes)
        XCTAssertFalse(d.isValid)
        d.minutesOfDay = [19 * 60 + 30]
        XCTAssertTrue(d.isValid)
    }

    func testAfterFirstRequiresAnchorAndPositiveNumbers() {
        var d = PlanEntryDraft(title: "분유", kind: .afterFirst)
        XCTAssertFalse(d.isValid)
        d.anchorType = "feeding_bottle"
        d.everyMinutes = 180
        d.count = 6
        XCTAssertTrue(d.isValid)
        d.count = 0
        XCTAssertFalse(d.isValid)
    }

    func testAfterEntryRequiresPrecedingEntry() {
        var d = PlanEntryDraft(title: "잠자리", kind: .afterEntry)
        XCTAssertFalse(d.isValid)
        d.afterEntryId = "bath"
        d.offsetMinutes = 30
        XCTAssertTrue(d.isValid)
    }

    func testEmptyTitleIsInvalidForEveryKind() {
        var d = PlanEntryDraft(title: "  ", kind: .fixedTimes)
        d.minutesOfDay = [720]
        XCTAssertFalse(d.isValid)
    }

    func testBuildProducesMatchingSchedule() throws {
        var d = PlanEntryDraft(title: "분유", kind: .afterFirst)
        d.anchorType = "feeding_bottle"
        d.everyMinutes = 180
        d.count = 6
        d.lane = .baby
        let entry = try XCTUnwrap(d.build(order: 3))
        XCTAssertEqual(entry.schedule.kind, .afterFirst)
        XCTAssertEqual(entry.schedule.everyMinutes, 180)
        XCTAssertEqual(entry.order, 3)
        XCTAssertEqual(entry.title, "분유")
    }

    func testBuildReturnsNilWhenInvalid() {
        let d = PlanEntryDraft(title: "", kind: .fixedTimes)
        XCTAssertNil(d.build(order: 0))
    }

    // 정정 2 — .unknown(forward-compat 센티넬)은 부모가 고를 수 없는 종류다.
    // 나타나도 유효하지 않고, build 는 nil 을 낸다 — 데이터를 지어내지 않는다.
    func testUnknownKindIsInvalidAndBuildsNil() {
        var d = PlanEntryDraft(title: "미지의 종류", kind: .unknown)
        XCTAssertFalse(d.isValid)
        XCTAssertNil(d.build(order: 0))
        d.minutesOfDay = [600]   // 다른 필드를 채워도 여전히 무효 — kind 자체가 만들 수 없는 것이다
        XCTAssertFalse(d.isValid)
    }
}

// MARK: - Task 6 · 목록 화면의 묶는 규칙

final class PlanEntryGroupingTests: XCTestCase {

    /// kind 마다 유효한 schedule 을 하나씩 — `default` 를 쓰지 않는다.
    /// 네 번째 방식이 생기면 **여기가 컴파일 에러**로 먼저 걸린다.
    private func schedule(for kind: PlanSchedule.Kind) -> PlanSchedule {
        switch kind {
        case .fixedTimes: .fixedTimes(minutesOfDay: [720])
        case .afterFirst: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 6)
        case .afterEntry: .afterEntry(entryId: "x", offsetMinutes: 30)
        case .unknown: PlanSchedule(kind: .unknown)
        }
    }

    private func entry(_ id: String, _ kind: PlanSchedule.Kind, order: Int) -> DayPlan.Entry {
        DayPlan.Entry(id: id, title: id, schedule: schedule(for: kind), order: order)
    }

    func testGroupsByKindInFixedSectionOrder() {
        let plan = DayPlan(id: "p", name: "표", entries: [
            entry("bath", .fixedTimes, order: 2),
            entry("bed", .afterEntry, order: 3),
            entry("milk", .afterFirst, order: 1)
        ])
        let sections = PlanEntryGrouping.sections(for: plan)
        XCTAssertEqual(sections.map(\.kind), [.afterFirst, .fixedTimes, .afterEntry])
        XCTAssertEqual(sections[0].entries.map(\.id), ["milk"])
    }

    func testEmptyKindsAreOmitted() {
        let plan = DayPlan(id: "p", name: "표", entries: [entry("bath", .fixedTimes, order: 0)])
        let sections = PlanEntryGrouping.sections(for: plan)
        XCTAssertEqual(sections.map(\.kind), [.fixedTimes])
    }

    func testEntriesWithinSectionSortByOrder() {
        let plan = DayPlan(id: "p", name: "표", entries: [
            entry("b", .fixedTimes, order: 5),
            entry("a", .fixedTimes, order: 1)
        ])
        XCTAssertEqual(PlanEntryGrouping.sections(for: plan)[0].entries.map(\.id), ["a", "b"])
    }

    /// 🩸 이름을 열거하면 새 것이 조용히 빠진다(같은 결함 3회) —
    /// 묶는 순서는 손으로 적은 목록이라, 네 번째 방식이 생기면 **말없이 목록에서 사라진다**.
    /// 부모는 그 항목을 보지도 지우지도 못한다. 여기서 빨갛게 걸리게 한다.
    func testEveryPersistableKindGetsASection() {
        let persistable = PlanSchedule.Kind.allCases.filter { $0 != .unknown }
        let plan = DayPlan(id: "p", name: "표", entries: persistable.enumerated().map { i, kind in
            entry("e\(i)", kind, order: i)
        })
        let sections = PlanEntryGrouping.sections(for: plan)
        XCTAssertEqual(Set(sections.map(\.kind)), Set(persistable), "새 방식이 묶는 순서 목록에서 빠졌다")
        XCTAssertEqual(sections.flatMap(\.entries).count, persistable.count, "항목이 조용히 사라졌다")
    }
}

// MARK: - Task 6 · 줄 요약 문구

final class PlanEntrySummaryTests: XCTestCase {

    private func plan(_ entries: [DayPlan.Entry]) -> DayPlan {
        DayPlan(id: "p", name: "우리 하루", entries: entries)
    }

    func testFixedTimesListsEveryTime() {
        let e = DayPlan.Entry(id: "bath", title: "목욕", schedule: .fixedTimes(minutesOfDay: [1170, 420]), order: 0)
        XCTAssertEqual(PlanEntrySummary.text(for: e, in: plan([e])), "매일 07:00 · 19:30")
    }

    func testAfterFirstNamesTheAnchorRecord() {
        let e = DayPlan.Entry(
            id: "milk", title: "분유",
            schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 6), order: 0
        )
        let text = PlanEntrySummary.text(for: e, in: plan([e]))
        XCTAssertTrue(text.contains("3시간마다"), text)
        XCTAssertTrue(text.contains("하루 6번"), text)
    }

    func testAfterEntryNamesThePrecedingEntry() {
        let bath = DayPlan.Entry(id: "bath", title: "목욕", schedule: .fixedTimes(minutesOfDay: [1170]), order: 0)
        let bed = DayPlan.Entry(id: "bed", title: "잠자리", schedule: .afterEntry(entryId: "bath", offsetMinutes: 30), order: 1)
        XCTAssertEqual(PlanEntrySummary.text(for: bed, in: plan([bath, bed])), "목욕 30분 뒤")
    }

    /// 🔙 되돌리는 길 — 가리키던 항목을 지우면 이 칸은 **영영 「미정」**으로 남는다(Expander 실동작).
    /// 요약이 빈칸이면 부모는 왜 안 오는지 알 길이 없다. 말로 알려 준다.
    func testAfterEntryTellsTheTruthWhenTheTargetIsGone() {
        let bed = DayPlan.Entry(id: "bed", title: "잠자리", schedule: .afterEntry(entryId: "지워짐", offsetMinutes: 30), order: 0)
        let text = PlanEntrySummary.text(for: bed, in: plan([bed]))
        XCTAssertFalse(text.isEmpty)
        XCTAssertFalse(text.contains("지워짐"), "사라진 항목의 id 를 부모에게 보여주지 않는다: \(text)")
        XCTAssertTrue(text.contains("없어"), text)
    }

    func testIntervalLabelReadsNaturally() {
        XCTAssertEqual(PlanEntrySummary.intervalLabel(180), "3시간마다")
        XCTAssertEqual(PlanEntrySummary.intervalLabel(45), "45분마다")
        XCTAssertEqual(PlanEntrySummary.intervalLabel(90), "1시간 30분마다")
    }
}

// MARK: - Task 6 · 넣고 지우는 규칙

final class PlanEntryMutationTests: XCTestCase {

    private func entry(_ id: String, order: Int) -> DayPlan.Entry {
        DayPlan.Entry(id: id, title: id, schedule: .fixedTimes(minutesOfDay: [600]), order: order)
    }

    func testFirstEntryCreatesTheDefaultPlan() {
        let made = PlanEntryMutation.appending(entry("a", order: 0), to: nil)
        XCTAssertEqual(made.name, "우리 하루")
        XCTAssertEqual(made.entries.map(\.id), ["a"])
        XCTAssertTrue(made.isActive)
    }

    func testNewEntryGoesToTheEnd() {
        let existing = DayPlan(id: "p", name: "우리 하루", entries: [entry("a", order: 0), entry("b", order: 7)])
        XCTAssertEqual(PlanEntryMutation.nextOrder(in: existing), 8)
        let after = PlanEntryMutation.appending(entry("c", order: 8), to: existing)
        XCTAssertEqual(after.entries.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(after.id, "p", "같은 시간표에 붙는다 — 새로 만들지 않는다")
    }

    func testNextOrderOnEmptyPlanIsZero() {
        XCTAssertEqual(PlanEntryMutation.nextOrder(in: nil), 0)
        XCTAssertEqual(PlanEntryMutation.nextOrder(in: DayPlan(id: "p", name: "우리 하루")), 0)
    }

    func testRemovingLastEntryKeepsThePlan() {
        let p = DayPlan(id: "p", name: "우리 하루", entries: [entry("a", order: 0)])
        let after = PlanEntryMutation.removing(["a"], from: p)
        XCTAssertTrue(after.entries.isEmpty)
        XCTAssertEqual(after.id, "p", "마지막 하나를 지워도 시간표는 남는다 — 빈 화면에서 다시 넣는다")
    }

    /// 🔙 지운 항목을 가리키던 칸은 **사라지지 않는다** — 목록에 남아야 부모가 보고 지울 수 있다.
    func testDependentEntrySurvivesSoTheParentCanSeeAndFixIt() {
        let bath = DayPlan.Entry(id: "bath", title: "목욕", schedule: .fixedTimes(minutesOfDay: [1170]), order: 0)
        let bed = DayPlan.Entry(id: "bed", title: "잠자리", schedule: .afterEntry(entryId: "bath", offsetMinutes: 30), order: 1)
        let after = PlanEntryMutation.removing(["bath"], from: DayPlan(id: "p", name: "우리 하루", entries: [bath, bed]))
        XCTAssertEqual(after.entries.map(\.id), ["bed"])
        XCTAssertFalse(PlanEntrySummary.text(for: after.entries[0], in: after).isEmpty)
    }
}

// MARK: - Task 6 · 아이 이름 뒤 조사

final class KoreanParticleWithNameTests: XCTestCase {

    /// 🩸 시리에서 값비쌌던 자리 — 받침을 안 보면 「서아이와」가 화면에 뜬다.
    func testNameWithFinalConsonantTakesIWa() {
        XCTAssertEqual(KoreanParticle.withName("서준"), "서준이와")
        XCTAssertEqual(KoreanParticle.withName("민준"), "민준이와")
    }

    func testNameWithoutFinalConsonantTakesWa() {
        XCTAssertEqual(KoreanParticle.withName("서아"), "서아와")
        XCTAssertEqual(KoreanParticle.withName("지우"), "지우와")
    }

    func testNonKoreanNameFallsBackWithoutConsonant() {
        XCTAssertEqual(KoreanParticle.withName("Leo"), "Leo와")
    }
}

// MARK: - Task 1 · 오늘을 열었나

final class DayRunTests: XCTestCase {

    /// 문서 id = 로컬 날짜. 하루에 한 문서만 생기고, 같은 날 다시 눌러도 덮어쓴다(멱등).
    func testDocumentIdIsLocalCalendarDate() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let day = cal.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 23, minute: 50))!
        XCTAssertEqual(DayRun.documentId(for: day, calendar: cal), "2026-09-03")
    }

    /// 🩸 자정 직전/직후가 다른 날이어야 한다 — 같은 id 면 어제 하루를 덮어쓴다.
    func testDocumentIdChangesAcrossMidnight() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let before = cal.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 23, minute: 59))!
        let after = cal.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 0, minute: 1))!
        XCTAssertNotEqual(DayRun.documentId(for: before, calendar: cal),
                          DayRun.documentId(for: after, calendar: cal))
    }

    func testOpenUntilClosed() {
        var run = DayRun(id: "2026-09-03", planId: "p", startedAt: Date())
        XCTAssertTrue(run.isOpen)
        run.closedAt = Date()
        XCTAssertFalse(run.isOpen)
    }

    func testRoundTripsThroughJSON() throws {
        let run = DayRun(id: "2026-09-03", planId: "p", startedAt: Date(timeIntervalSince1970: 1_000_000))
        let data = try JSONEncoder().encode(run)
        let back = try JSONDecoder().decode(DayRun.self, from: data)
        XCTAssertEqual(back, run)
    }

    /// 신규 필드는 전부 optional — 옛 문서(planId·closedAt 없음)가 들어와도 살아야 한다.
    func testDecodesDocumentWithoutOptionalFields() throws {
        let json = #"{"id":"2026-09-03","startedAt":0}"#.data(using: .utf8)!
        let back = try JSONDecoder().decode(DayRun.self, from: json)
        XCTAssertEqual(back.id, "2026-09-03")
        XCTAssertNil(back.planId)
        XCTAssertTrue(back.isOpen)
    }
}

// MARK: - Task 2 · 그날의 정박점

final class DayAnchorsBuilderTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func at(_ h: Int, _ m: Int = 0, day: Int = 3) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: day, hour: h, minute: m))!
    }

    private func activity(_ type: Activity.ActivityType, _ start: Date, end: Date? = nil) -> Activity {
        Activity(id: UUID().uuidString, babyId: "b", type: type,
                 startTime: start, endTime: end, createdAt: start)
    }

    func testFirstRecordPerTypeIsTheEarliestOfThatType() {
        let acts = [
            activity(.feedingBottle, at(9)),
            activity(.feedingBottle, at(6, 20)),
            activity(.diaperWet, at(7))
        ]
        let a = DayAnchorsBuilder.anchors(from: acts, on: at(12), calendar: cal)
        XCTAssertEqual(a.firstRecordByType["feeding_bottle"], at(6, 20))
        XCTAssertEqual(a.firstRecordByType["diaper_wet"], at(7))
    }

    /// 🔴 이 단계에서 제일 비싼 함정 —
    /// `todayActivities` 는 「오늘 끝난 것」도 갖고 있어서, **어젯밤 22시에 시작한 잠**이 섞여 있다.
    /// 그걸 오늘의 첫 기록으로 삼으면 하루 전체가 어제 시각에 정박한다.
    func testYesterdaysSleepThatEndedThisMorningIsNotTodaysAnchor() {
        let overnight = activity(.sleep, at(22, 0, day: 2), end: at(7, 0, day: 3))
        let todayNap = activity(.sleep, at(13))
        let a = DayAnchorsBuilder.anchors(from: [overnight, todayNap], on: at(12), calendar: cal)
        XCTAssertEqual(a.firstRecordByType["sleep"], at(13), "어젯밤 잠이 오늘의 정박점이 됐다")
    }

    func testUnknownTypeIsNeverAnAnchor() {
        // .unknown 은 read-only 센티넬 — 정박점으로 쓰면 알 수 없는 종류가 하루를 정한다.
        var a = activity(.feedingBottle, at(8))
        a.type = .unknown
        let out = DayAnchorsBuilder.anchors(from: [a], on: at(12), calendar: cal)
        XCTAssertTrue(out.firstRecordByType.isEmpty)
    }

    func testEmptyDayHasNoAnchors() {
        XCTAssertTrue(DayAnchorsBuilder.anchors(from: [], on: at(12), calendar: cal).firstRecordByType.isEmpty)
    }
}

// MARK: - Task 3 · 기록이 칸을 채운다

final class DaySlotFillerTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func at(_ h: Int, _ m: Int = 0, day: Int = 3) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: day, hour: h, minute: m))!
    }

    private func activity(_ type: Activity.ActivityType, _ start: Date, end: Date? = nil) -> Activity {
        Activity(id: "a-\(type.rawValue)-\(start.timeIntervalSince1970)", babyId: "b", type: type,
                 startTime: start, endTime: end, createdAt: start)
    }

    private func slot(_ id: String, _ type: Activity.ActivityType?, at plannedAt: Date?, order: Int = 0) -> DayPlanExpander.Slot {
        DayPlanExpander.Slot(id: id, entryId: id, title: id, activityType: type?.rawValue,
                             lane: .baby, plannedAt: plannedAt, order: order)
    }

    func testRecordFillsTheNearestSlotOfTheSameType() {
        let slots = [slot("s1", .feedingBottle, at: at(9)), slot("s2", .feedingBottle, at: at(12))]
        let acts = [activity(.feedingBottle, at(12, 10))]
        let cells = DaySlotFiller.fill(slots: slots, activities: acts, on: at(13), calendar: cal)
        XCTAssertEqual(cells.first(where: { $0.slotId == "s2" })?.kind, .done)
        XCTAssertEqual(cells.first(where: { $0.slotId == "s1" })?.kind, .planned)
    }

    /// 채워진 칸은 **실제 시각**으로 보인다 — 밑그림을 실제가 덮어쓴다(결정 5).
    func testFilledCellShowsTheActualTimeNotThePlannedTime() {
        let slots = [slot("s1", .bath, at: at(19, 30))]
        let cells = DaySlotFiller.fill(slots: slots, activities: [activity(.bath, at(8))], on: at(20), calendar: cal)
        XCTAssertEqual(cells[0].at, at(8))
    }

    /// 시안 「② 낮」 — 8칸 계획에 9번째 기록이 오면 **칸이 하나 늘어난다**.
    func testUnmatchedRecordBecomesAnExtraCell() {
        let slots = [slot("s1", .feedingBottle, at: at(9))]
        let acts = [activity(.feedingBottle, at(9, 5)), activity(.feedingBottle, at(15))]
        let cells = DaySlotFiller.fill(slots: slots, activities: acts, on: at(16), calendar: cal)
        XCTAssertEqual(cells.count, 2)
        XCTAssertEqual(cells.filter { $0.kind == .extra }.count, 1)
        XCTAssertEqual(cells.first(where: { $0.kind == .extra })?.at, at(15))
    }

    /// 종류가 다르면 절대 안 붙는다 — 목욕 기록이 수유 칸을 채우면 하루가 거짓이 된다.
    func testDifferentTypeNeverFillsASlot() {
        let slots = [slot("s1", .feedingBottle, at: at(9))]
        let cells = DaySlotFiller.fill(slots: slots, activities: [activity(.bath, at(9))], on: at(10), calendar: cal)
        XCTAssertEqual(cells.first(where: { $0.slotId == "s1" })?.kind, .planned)
        XCTAssertEqual(cells.filter { $0.kind == .extra }.count, 1)
    }

    /// 기록 종류가 없는 항목(내 밥·샤워)은 기록으로 채워지지 않는다 — 빈 채로 남는다.
    func testSlotWithoutActivityTypeStaysPlanned() {
        let slots = [slot("s1", nil, at: at(12))]
        let cells = DaySlotFiller.fill(slots: slots, activities: [activity(.feedingBottle, at(12))], on: at(13), calendar: cal)
        XCTAssertEqual(cells.first(where: { $0.slotId == "s1" })?.kind, .planned)
    }

    /// 정박 전(plannedAt=nil) 칸도 짝을 받는다 — 「첫 수유를 기다리는 중」이 채워지는 순간.
    func testUnscheduledSlotCanBeFilled() {
        let slots = [slot("s1", .feedingBottle, at: nil)]
        let cells = DaySlotFiller.fill(slots: slots, activities: [activity(.feedingBottle, at(6, 30))], on: at(9), calendar: cal)
        XCTAssertEqual(cells[0].kind, .done)
        XCTAssertEqual(cells[0].at, at(6, 30))
    }

    /// 🔴 어젯밤 잠이 오늘 칸을 채우면 안 된다(`todayActivities` 는 그것도 갖고 있다).
    func testActivityThatStartedYesterdayDoesNotFillTodaysSlot() {
        let slots = [slot("s1", .sleep, at: at(13))]
        let overnight = activity(.sleep, at(22, 0, day: 2), end: at(7, 0, day: 3))
        let cells = DaySlotFiller.fill(slots: slots, activities: [overnight], on: at(14), calendar: cal)
        XCTAssertEqual(cells.first(where: { $0.slotId == "s1" })?.kind, .planned)
        XCTAssertTrue(cells.allSatisfy { $0.kind != .extra }, "어젯밤 잠이 오늘 칸으로 끼어들었다")
    }

    /// 가까운 쌍부터 붙는다 — 순서에 따라 답이 달라지면 안 된다.
    func testClosestPairWinsRegardlessOfInputOrder() {
        let slots = [slot("s1", .feedingBottle, at: at(9)), slot("s2", .feedingBottle, at: at(15))]
        let acts = [activity(.feedingBottle, at(14, 50)), activity(.feedingBottle, at(9, 10))]
        let forward = DaySlotFiller.fill(slots: slots, activities: acts, on: at(16), calendar: cal)
        let reversed = DaySlotFiller.fill(slots: slots.reversed(), activities: acts.reversed(), on: at(16), calendar: cal)
        XCTAssertEqual(forward.first(where: { $0.slotId == "s1" })?.at, at(9, 10))
        XCTAssertEqual(reversed.first(where: { $0.slotId == "s1" })?.at, at(9, 10))
    }

    /// 띠는 시간 순이다. 시각 미정(정박 전)은 맨 앞 — 하루가 거기서 시작하기를 기다리는 자리다.
    func testCellsSortUnscheduledFirstThenByTime() {
        let slots = [slot("s2", .feedingBottle, at: at(12)), slot("s1", .feedingSolid, at: nil)]
        let cells = DaySlotFiller.fill(slots: slots, activities: [], on: at(13), calendar: cal)
        XCTAssertEqual(cells.map(\.slotId), ["s1", "s2"])
    }
}

// MARK: - Task 3.5 · 항목이 「어떤 기록으로 채워지나」를 말한다

final class PlanEntryRecordTypeTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func at(_ h: Int, _ m: Int = 0, day: Int = 3) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: day, hour: h, minute: m))!
    }

    private func activity(_ type: Activity.ActivityType, _ start: Date) -> Activity {
        Activity(id: "a-\(start.timeIntervalSince1970)", babyId: "b", type: type,
                 startTime: start, createdAt: start)
    }

    /// 「첫 분유부터 3시간마다」로 짰으면 그 칸을 채우는 기록은 분유다 — 부모에게 두 번 묻지 않는다.
    func testAfterFirstEntryFallsBackToItsAnchorType() {
        let e = DayPlan.Entry(id: "milk", title: "분유",
                              schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 6),
                              order: 0)
        XCTAssertEqual(e.recordType, "feeding_bottle")
    }

    /// 명시한 종류가 있으면 그게 이긴다.
    func testExplicitActivityTypeWins() {
        let e = DayPlan.Entry(id: "x", title: "목욕", activityType: "bath",
                              schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 6),
                              order: 0)
        XCTAssertEqual(e.recordType, "bath")
    }

    /// 기록이 없는 일(내 밥·샤워)은 **비어 있는 게 맞다** — 없는 종류를 지어내지 않는다.
    func testEntryWithNoTypeAndNoAnchorHasNoRecordType() {
        let e = DayPlan.Entry(id: "meal", title: "내 밥",
                              schedule: .fixedTimes(minutesOfDay: [720]), order: 0)
        XCTAssertNil(e.recordType)
    }

    /// 🔴 이 태스크의 이유 — 시트가 `activityType` 을 안 채우므로, 정박 종류로만 짠 항목도
    ///    실제로 **칸이 채워져야** 한다. 이 테스트가 빨간 상태로 ②단계가 배포되면 기능이 죽는다.
    func testAnchorOnlyEntryActuallyGetsFilledEndToEnd() {
        let plan = DayPlan(id: "p", name: "우리 하루", entries: [
            DayPlan.Entry(id: "milk", title: "분유",
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 2),
                          order: 0)
        ])
        let acts = [activity(.feedingBottle, at(6, 30))]
        let anchors = DayAnchorsBuilder.anchors(from: acts, on: at(9), calendar: cal)
        let slots = DayPlanExpander.slots(plan: plan, day: at(9), anchors: anchors, calendar: cal)
        let cells = DaySlotFiller.fill(slots: slots, activities: acts, on: at(9), calendar: cal)

        XCTAssertEqual(cells.filter { $0.kind == .done }.count, 1, "기록이 칸을 못 채웠다")
        XCTAssertTrue(cells.allSatisfy { $0.kind != .extra }, "예정에 있던 기록이 끼어든 칸이 됐다")
    }

    /// ⓓ 미정 칸은 **최후 순위** — 시각이 잘 맞는 예정 칸이 미정 칸에 굶으면 안 된다(Task 3 리뷰 Important).
    func testScheduledSlotBeatsUnscheduledSlotOfTheSameType() {
        let scheduled = DayPlanExpander.Slot(id: "s-fixed", entryId: "e1", title: "분유",
                                             activityType: "feeding_bottle", lane: .baby,
                                             plannedAt: at(12), order: 0)
        let unscheduled = DayPlanExpander.Slot(id: "s-waiting", entryId: "e2", title: "분유",
                                               activityType: "feeding_bottle", lane: .baby,
                                               plannedAt: nil, order: 1)
        let cells = DaySlotFiller.fill(slots: [scheduled, unscheduled],
                                       activities: [activity(.feedingBottle, at(12, 5))],
                                       on: at(13), calendar: cal)
        XCTAssertEqual(cells.first(where: { $0.slotId == "s-fixed" })?.kind, .done,
                       "시각이 맞는 예정 칸이 미정 칸에 밀렸다")
        XCTAssertEqual(cells.first(where: { $0.slotId == "s-waiting" })?.kind, .planned)
    }

    /// 경쟁이 없으면 미정 칸도 그대로 채워진다 — 최후 순위지 금지가 아니다.
    func testUnscheduledSlotStillFillsWhenNothingElseWantsIt() {
        let unscheduled = DayPlanExpander.Slot(id: "s", entryId: "e", title: "분유",
                                               activityType: "feeding_bottle", lane: .baby,
                                               plannedAt: nil, order: 0)
        let cells = DaySlotFiller.fill(slots: [unscheduled],
                                       activities: [activity(.feedingBottle, at(6, 30))],
                                       on: at(9), calendar: cal)
        XCTAssertEqual(cells[0].kind, .done)
    }
}

// MARK: - Task 4 · 밤 요약

final class DaySummaryTests: XCTestCase {

    private func cell(_ type: Activity.ActivityType, _ kind: DayCell.Kind,
                      lane: DayPlan.Lane = .baby) -> DayCell {
        DayCell(id: UUID().uuidString, slotId: nil, title: type.displayName,
                activityType: type.rawValue, lane: lane, kind: kind, at: Date(), order: 0)
    }

    /// 시안 밤 화면 — 「서준이 일곱 번 먹고 세 번 잤어요」.
    func testCountsWhatHappened() {
        let cells = Array(repeating: cell(.feedingBottle, .done), count: 6)
            + [cell(.feedingBreast, .done)]
            + Array(repeating: cell(.sleep, .done), count: 3)
        let line = DaySummary.babyLine(cells: cells, babyName: "서준")
        XCTAssertEqual(line, "서준이 일곱 번 먹고 세 번 잤어요")
    }

    /// 🔴 설계 §5 — **못 한 것은 세지 않는다.** 빈 칸이 문장에 나타나면 안 된다.
    func testNeverCountsWhatDidNotHappen() {
        let cells = [cell(.feedingBottle, .done)] + Array(repeating: cell(.feedingBottle, .planned), count: 5)
        let line = DaySummary.babyLine(cells: cells, babyName: "서준")
        XCTAssertEqual(line, "서준이 한 번 먹었어요")
        XCTAssertFalse(line?.contains("5") ?? false)
        XCTAssertFalse(line?.contains("못") ?? false)
    }

    /// 끼어든 칸도 **한 것**이다 — 계획 밖이라고 빼면 실제보다 적게 말하게 된다.
    func testExtraCellsCountToo() {
        XCTAssertEqual(DaySummary.babyLine(cells: [cell(.feedingBottle, .extra)], babyName: "서준"),
                       "서준이 한 번 먹었어요")
    }

    /// 아무것도 안 한 날엔 **아무 말도 하지 않는다** — 「0번 먹었어요」는 비난이다.
    func testSaysNothingWhenNothingHappened() {
        XCTAssertNil(DaySummary.babyLine(cells: [cell(.sleep, .planned)], babyName: "서준"))
    }

    /// 🩸 받침 — 「서아가」가 아니라 이름 뒤 주격은 이/가 규칙을 탄다.
    func testNameParticleFollowsFinalConsonant() {
        XCTAssertEqual(DaySummary.babyLine(cells: [cell(.sleep, .done)], babyName: "서아"),
                       "서아가 한 번 잤어요")
    }

    /// 🔴 리뷰 Important — 유축(생산)만 있으면 먹지도 자지도 않은 것이다. 할 말이 없다.
    func testPumpingAloneSaysNothing() {
        XCTAssertNil(DaySummary.babyLine(cells: [cell(.feedingPumping, .done)], babyName: "서준"))
    }

    /// 🔴 리뷰 Important — 유축이 끼어 있어도 진짜 섭취 횟수를 부풀리면 안 된다.
    /// `isFeeding`이 `.feedingPumping`을 참으로 잘못 세면(예: 「먹기」 접두사만 보고 묶으면)
    /// 이 테스트가 "두 번 먹었어요"로 빨개진다.
    func testPumpingDoesNotInflateFeedCount() {
        let cells = [cell(.feedingBottle, .done), cell(.feedingPumping, .done)]
        XCTAssertEqual(DaySummary.babyLine(cells: cells, babyName: "서준"), "서준이 한 번 먹었어요")
    }

    /// 🔴 리뷰 Important — 내 줄(부모)의 잠은 아이 줄이 아니다. 아이는 먹기만 했는데
    /// 부모 잠까지 섞이면 「일곱 번 먹고 한 번 잤어요」로 없는 일이 생긴다.
    /// lane 필터를 지우면 이 테스트가 빨개진다.
    func testParentLaneSleepDoesNotCountAsBabys() {
        let cells = [cell(.feedingBottle, .done), cell(.sleep, .done, lane: .parent)]
        XCTAssertEqual(DaySummary.babyLine(cells: cells, babyName: "서준"), "서준이 한 번 먹었어요")
    }
}
