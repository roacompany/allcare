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
