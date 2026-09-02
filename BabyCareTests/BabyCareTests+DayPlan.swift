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
                )
            ]
        )
        let data = try JSONEncoder().encode(plan)
        let back = try JSONDecoder().decode(DayPlan.self, from: data)
        XCTAssertEqual(back, plan)
        XCTAssertEqual(back.entries[0].schedule.everyMinutes, 180)
        XCTAssertEqual(back.entries[1].schedule.minutesOfDay, [720])
    }

    // 옛 문서에 없던 필드가 들어와도 깨지지 않아야 한다
    func testDecodesDocumentWithoutOptionalFields() throws {
        let json = """
        {"id":"p1","name":"표","entries":[],"createdAt":0}
        """.data(using: .utf8)!
        let back = try JSONDecoder().decode(DayPlan.self, from: json)
        XCTAssertEqual(back.entries.count, 0)
        XCTAssertNil(back.babyId)
        XCTAssertTrue(back.isActive)   // 없으면 활성으로 본다
    }
}
