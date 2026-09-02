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
