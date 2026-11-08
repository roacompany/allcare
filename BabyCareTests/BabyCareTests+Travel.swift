import XCTest
import SwiftUI
import UIKit
@testable import BabyCare

// MARK: - 여행 준비 — 공통 달력·시각·기준 여행 (테스트 전용 값 · 앱 코드에 예시를 넣지 않는다)

enum TravelTestClock {
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        c.locale = Locale(identifier: "ko_KR")
        return c
    }()

    static func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi))!
    }
}

enum TravelFixtures {
    private static func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        TravelTestClock.at(y, m, d, h, mi)
    }

    static func outbound(airline: String = "KE", departAt: Date? = TravelTestClock.at(2027, 5, 10, 15, 10)) -> TripBooking {
        TripBooking(id: "f1", kind: .flight, airline: airline, flightNumber: "\(airline)725",
                    fromAirport: "ICN", toAirport: "KIX",
                    depart: departAt.map(TripWhen.at), arrive: .at(at(2027, 5, 10, 17, 0)))
    }

    static func inbound(airline: String = "KE") -> TripBooking {
        TripBooking(id: "f2", kind: .flight, airline: airline, flightNumber: "\(airline)724",
                    fromAirport: "KIX", toAirport: "ICN",
                    depart: .at(at(2027, 5, 14, 11, 55)), arrive: .at(at(2027, 5, 14, 14, 0)))
    }

    static let car = TripBooking(id: "c1", kind: .rentalCar, company: "렌터카",
                                 pickupPlace: "간사이공항", pickup: .at(TravelTestClock.at(2027, 5, 10, 18, 0)),
                                 returnPlace: "간사이공항", carReturn: .at(TravelTestClock.at(2027, 5, 14, 9, 30)),
                                 freeCancel: .at(TravelTestClock.at(2027, 5, 7, 18, 0)))

    static let hotel = TripBooking(id: "h1", kind: .hotel, name: "오사카 숙소", address: "오사카",
                                   checkIn: .at(TravelTestClock.at(2027, 5, 12, 15, 0)),
                                   checkOut: .at(TravelTestClock.at(2027, 5, 14, 10, 0)),
                                   freeCancel: .at(TravelTestClock.at(2027, 5, 10, 12, 0)))

    static func osakaTrip(bookings: [TripBooking]? = nil, moves: [TripMove] = []) -> Trip {
        Trip(id: "t1", babyId: "b1", countryCode: "JP", city: "오사카·교토",
             startDay: "2027-05-10", endDay: "2027-05-14",
             bookings: bookings ?? [outbound(), inbound(), car, hotel],
             moves: moves,
             createdAt: TravelTestClock.at(2027, 5, 2), updatedAt: TravelTestClock.at(2027, 5, 2))
    }
}

// MARK: - Task 2 · 모델

final class TripModelTests: XCTestCase {
    private let cal = TravelTestClock.cal

    // rawValue 는 Firestore 영구 계약 — 바뀌면 저장된 여행이 깨진다
    func testRawValuesAreContract() {
        XCTAssertEqual(TripBooking.Kind.flight.rawValue, "flight")
        XCTAssertEqual(TripBooking.Kind.hotel.rawValue, "hotel")
        XCTAssertEqual(TripBooking.Kind.rentalCar.rawValue, "rental_car")
        XCTAssertEqual(TripAssignee.mother.rawValue, "mother")
        XCTAssertEqual(TripAssignee.father.rawValue, "father")
        XCTAssertEqual(TripAssignee.both.rawValue, "both")
        XCTAssertEqual(TripAssignee.unassigned.rawValue, "unassigned")
        XCTAssertEqual(TripAssignee.selectable.map(\.label), ["엄마", "아빠", "함께", "담당 없음"])
    }

    func testTripRoundTripsThroughJSON() throws {
        var trip = TravelFixtures.osakaTrip(moves: [
            TripMove(id: "m1", startAt: TravelTestClock.at(2027, 5, 10, 18, 30), minutes: 90,
                     fromLabel: "간사이공항", toLabel: "아라시야마 숙소")
        ])
        trip.taskStates = [TripTaskState(taskId: "bassinet", isDone: true,
                                         doneAt: TravelTestClock.at(2027, 5, 3), doneBy: "u1", assignee: .mother)]
        let data = try JSONEncoder().encode(trip)
        let back = try JSONDecoder().decode(Trip.self, from: data)
        // 맵으로 저장하니 순서는 안 지킨다 — 순서를 맞춰 비교
        trip.bookings.sort { $0.id < $1.id }
        XCTAssertEqual(back, trip)
    }

    // 저장 모양 = id 를 키로 한 맵(칸 하나씩 고칠 수 있게) · 초기의 배열 모양도 읽는다
    func testStoredAsMapsKeyedById() throws {
        let trip = TravelFixtures.osakaTrip()
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(trip)) as? [String: Any])
        let bookings = try XCTUnwrap(json["bookings"] as? [String: Any])
        XCTAssertEqual(Set(bookings.keys), ["f1", "f2", "c1", "h1"])
        let legacy = #"{"id":"t1","babyId":"b1","countryCode":"JP","city":"오사카","startDay":"2027-05-10","endDay":"2027-05-14","bookings":[{"id":"h1","kind":"hotel"}],"createdAt":0,"updatedAt":0}"#
        XCTAssertEqual(try JSONDecoder().decode(Trip.self, from: Data(legacy.utf8)).bookings.map(\.id), ["h1"])
    }

    // 옛 앱이 새 종류를 만나도 여행 문서가 통째로 버려지지 않는다
    func testUnknownKindDecodesAsUnknown() throws {
        let booking = try JSONDecoder().decode(TripBooking.self, from: Data(#"{"id":"b1","kind":"cruise"}"#.utf8))
        XCTAssertEqual(booking.kind, .unknown)
        let state = try JSONDecoder().decode(TripTaskState.self,
                                             from: Data(#"{"taskId":"x","isDone":false,"assignee":"grandma"}"#.utf8))
        XCTAssertEqual(state.assignee, .unknown)
    }

    // 모르는 값은 읽기만 — 저장하면 덮어써서 지운다
    func testEncodingUnknownKindThrows() {
        XCTAssertThrowsError(try JSONEncoder().encode(TripBooking(id: "b1", kind: .unknown)))
        XCTAssertThrowsError(try JSONEncoder().encode(TripTaskState(taskId: "x", isDone: false, assignee: .unknown)))
    }

    // 빠진 배열은 빈 배열로 읽는다(앞으로 칸이 늘어도 옛 문서가 읽힌다)
    func testMissingArraysDecodeAsEmpty() throws {
        let json = #"{"id":"t1","babyId":"b1","countryCode":"JP","city":"오사카","startDay":"2027-05-10","endDay":"2027-05-14","createdAt":0,"updatedAt":0}"#
        let trip = try JSONDecoder().decode(Trip.self, from: Data(json.utf8))
        XCTAssertEqual(trip.bookings, [])
        XCTAssertEqual(trip.taskStates, [])
        XCTAssertEqual(trip.moves, [])
    }

    func testDaysCoverStartThroughEnd() {
        let days = TravelFixtures.osakaTrip().days(calendar: cal)
        XCTAssertEqual(days.count, 5)
        XCTAssertEqual(days.first, TravelTestClock.at(2027, 5, 10))
        XCTAssertEqual(days.last, TravelTestClock.at(2027, 5, 14))
        XCTAssertEqual(Trip.dayKey(TravelTestClock.at(2027, 5, 10, 23, 59), calendar: cal), "2027-05-10")
        XCTAssertEqual(Trip.date(fromDayKey: "2027-05-14", calendar: cal), TravelTestClock.at(2027, 5, 14))
        XCTAssertNil(Trip.date(fromDayKey: "5/14", calendar: cal))
    }
}

// MARK: - Task 3 · 규칙 카탈로그 · 공항 시설 · 할 일 엔진

final class TripTaskEngineTests: XCTestCase {
    private let cal = TravelTestClock.cal
    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }

    private func child(meat: MeatPresence = .present, height: Double? = 70.5, weight: Double? = 8.4,
                       hasSolids: Bool = true) -> TripChildContext {
        TripChildContext(birthDate: at(2026, 8, 30), heightCm: height, weightKg: weight, meat: meat, hasSolids: hasSolids)
    }

    private func tasks(_ trip: Trip = TravelFixtures.osakaTrip(), child: TripChildContext? = nil,
                       now: Date = TravelTestClock.at(2027, 5, 2, 10, 0)) -> [TripTask] {
        TripTaskEngine.tasks(trip: trip, child: child ?? self.child(), now: now, calendar: cal)
    }

    func testCatalogValuesMatchSources() {
        XCTAssertEqual(TripRuleCatalog.koreanAir, "KE")
        XCTAssertEqual(TripRuleCatalog.bassinetDeadlineHours, 48)
        XCTAssertEqual(TripRuleCatalog.infantMealDeadlineHours, 24)
        XCTAssertEqual(TripRuleCatalog.bassinetMaxHeightCm, 75)
        XCTAssertEqual(TripRuleCatalog.bassinetMaxWeightKg, 11)
        for key in [TripRuleKey.bassinet, .infantMeal, .solidsQuarantine, .liquidsOnboard, .carSeat] {
            XCTAssertFalse(TripRuleCatalog.card(key).sources.isEmpty, "\(key) 는 출처가 있어야 한다")
        }
        XCTAssertTrue(TripRuleCatalog.card(.hotelCrib).sources.isEmpty, "아기침대 요청은 챙기면 좋은 일 — 출처를 지어내지 않는다")
    }

    func testBassinetHasOneRowWithBothLegDeadlines() {
        let all = tasks()
        XCTAssertEqual(all.filter { $0.key == .bassinet }.count, 1)
        let bassinet = all.first { $0.id == "bassinet" }
        XCTAssertEqual(bassinet?.deadlines.map(\.at), [at(2027, 5, 8, 15, 10), at(2027, 5, 12, 11, 55)])
        XCTAssertEqual(bassinet?.deadlines.map(\.label), ["가는 편", "오는 편"])
    }

    func testInfantMealDeadlinesAre24HoursBefore() {
        let meal = tasks().first { $0.id == "infant_meal" }
        XCTAssertEqual(meal?.deadlines.map(\.at), [at(2027, 5, 9, 15, 10), at(2027, 5, 13, 11, 55)])
    }

    func testFreeCancelBecomesDeadlineOfBabyCheckTask() {
        let all = tasks()
        XCTAssertEqual(Set(all.map(\.id)), ["bassinet", "infant_meal", "solids_quarantine", "car_seat-c1", "hotel_crib-h1"])
        XCTAssertEqual(all.first { $0.id == "car_seat-c1" }?.deadlines, [TripDeadline(label: "무료 취소 기한", at: at(2027, 5, 7, 18, 0))])
        let crib = all.first { $0.id == "hotel_crib-h1" }
        XCTAssertEqual(crib?.deadlines, [TripDeadline(label: "무료 취소 기한", at: at(2027, 5, 10, 12, 0))])
        XCTAssertEqual(crib?.detail, "오사카 숙소")
        XCTAssertEqual(crib?.bookingId, "h1")
    }

    func testBookingWithoutFreeCancelHasNoDeadline() {
        var hotel = TravelFixtures.hotel
        hotel.freeCancel = nil
        let crib = tasks(TravelFixtures.osakaTrip(bookings: [hotel])).first { $0.id == "hotel_crib-h1" }
        XCTAssertEqual(crib?.deadlines, [])
    }

    func testNonKoreanAirFlightMakesNoAirlineTasks() {
        let trip = TravelFixtures.osakaTrip(bookings: [TravelFixtures.outbound(airline: "OZ"), TravelFixtures.inbound(airline: "OZ")])
        let ids = Set(tasks(trip).map(\.id))
        XCTAssertFalse(ids.contains("bassinet"))
        XCTAssertFalse(ids.contains("infant_meal"))
    }

    // 🩸 오는 편 마감이 00:00 기준으로 계산됐다(빌드 113) — 출발 시각이 없으면 마감을 지어내지 않고 「아직 못 낸 마감」으로 말한다.
    func testFlightWithoutDepartureTimeHasNoInventedDeadline() {
        let trip = TravelFixtures.osakaTrip(bookings: [TravelFixtures.outbound(departAt: nil), TravelFixtures.inbound()])
        let bassinet = tasks(trip).first { $0.id == "bassinet" }
        XCTAssertEqual(bassinet?.deadlines.map(\.at), [at(2027, 5, 12, 11, 55)])
        XCTAssertEqual(bassinet?.deadlines.map(\.label), ["오는 편"])
        XCTAssertEqual(bassinet?.openDeadlines, ["가는 편"])
    }

    func testDateOnlyDepartureAlsoWaitsForItsTime() {
        var back = TravelFixtures.inbound()
        back.depart = .day("2027-05-14")
        let trip = TravelFixtures.osakaTrip(bookings: [TravelFixtures.outbound(), back])
        let meal = tasks(trip).first { $0.id == "infant_meal" }
        XCTAssertEqual(meal?.deadlines.map(\.label), ["가는 편"])
        XCTAssertEqual(meal?.openDeadlines, ["오는 편"])
    }

    func testAirlineTaskStaysEvenWhenNoTimeIsKnownYet() {
        var back = TravelFixtures.inbound()
        back.depart = .day("2027-05-14")
        let bassinet = tasks(TravelFixtures.osakaTrip(bookings: [back])).first { $0.id == "bassinet" }
        XCTAssertEqual(bassinet?.deadlines, [])
        XCTAssertEqual(bassinet?.openDeadlines, ["오는 편"])
    }

    func testDateOnlyFreeCancelLastsToTheEndOfThatDay() {
        var hotel = TravelFixtures.hotel
        hotel.freeCancel = .day("2027-05-07")
        let deadline = tasks(TravelFixtures.osakaTrip(bookings: [hotel])).first { $0.id == "hotel_crib-h1" }?.deadlines.first
        XCTAssertEqual(deadline?.text(calendar: cal), "5.7(금)")
        XCTAssertEqual(deadline.map { cal.isDate($0.at, inSameDayAs: at(2027, 5, 7)) }, true)
    }

    func testSolidsNoteFollowsMeatPresence() {
        let present = tasks(child: child(meat: .present)).first { $0.id == "solids_quarantine" }
        XCTAssertEqual(present?.childNote, "최근 7일 이유식 기록에 고기 든 것이 있어요")
        XCTAssertEqual(present?.childNoteIsAlert, true)
        let absent = tasks(child: child(meat: .absent)).first { $0.id == "solids_quarantine" }
        XCTAssertEqual(absent?.childNote, "최근 7일 이유식 기록 이름에서 고기를 찾지 못했어요")
        XCTAssertEqual(absent?.childNoteIsAlert, false)
        let unknown = tasks(child: child(meat: .unknown)).first { $0.id == "solids_quarantine" }
        XCTAssertEqual(unknown?.childNote, "이름 없는 이유식 기록이 있어 고기가 들었는지 몰라요")
        XCTAssertNil(tasks(child: child(meat: .noSolids, hasSolids: false)).first { $0.id == "solids_quarantine" })
    }

    func testBassinetNoteFollowsGrowth() {
        let within = tasks().first { $0.id == "bassinet" }
        XCTAssertEqual(within?.childNote, "우리 아이 해당(키·체중 기준 안)")
        XCTAssertEqual(within?.childNoteIsAlert, false)
        let heavy = tasks(child: child(weight: 11.5)).first { $0.id == "bassinet" }
        XCTAssertEqual(heavy?.childNote, "키 75cm·체중 11kg을 넘으면 기내에서 못 쓸 수 있어요")
        XCTAssertEqual(heavy?.childNoteIsAlert, true)
        let unknown = tasks(child: child(height: nil)).first { $0.id == "bassinet" }
        XCTAssertEqual(unknown?.childNote, "키·체중을 입력하면 알려 드려요")
    }

    func testRecommendedDateIsSevenDaysBeforeDeadlineButNotPast() {
        let early = tasks(now: at(2027, 4, 20, 10, 0))
        XCTAssertEqual(early.first { $0.id == "bassinet" }?.recommendedOn, at(2027, 5, 1))
        XCTAssertEqual(early.first { $0.id == "solids_quarantine" }?.recommendedOn, at(2027, 5, 3), "마감 없으면 출발 7일 전")
        let late = tasks(now: at(2027, 5, 6, 10, 0))
        XCTAssertEqual(late.first { $0.id == "bassinet" }?.recommendedOn, at(2027, 5, 6), "지났으면 오늘")
    }

    func testInfantMealOnlyUnderTwoYears() {
        let older = TripChildContext(birthDate: at(2025, 4, 1), heightCm: nil, weightKg: nil, meat: .noSolids, hasSolids: false)
        XCTAssertNil(tasks(child: older).first { $0.id == "infant_meal" })
    }

    func testFacilityLookup() {
        XCTAssertEqual(AirportFacilityCatalog.facility(airport: "ICN", airline: "KE")?.terminal, "제2여객터미널")
        XCTAssertEqual(AirportFacilityCatalog.facility(airport: "KIX", airline: "KE")?.terminal, "제1터미널")
        XCTAssertNotNil(AirportFacilityCatalog.facility(airport: "KIX", airline: "KE")?.caution)
        XCTAssertNil(AirportFacilityCatalog.facility(airport: "ICN", airline: "OZ"))
        XCTAssertNil(AirportFacilityCatalog.facility(airport: "NRT", airline: "KE"))
    }
}

// MARK: - Task 4 · 순서 · 표시

final class TripTaskOrderingTests: XCTestCase {
    private let cal = TravelTestClock.cal
    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }

    private func task(_ id: String, recommended: Date, deadline: Date? = nil) -> TripTask {
        TripTask(id: id, key: .hotelCrib, title: id, detail: nil,
                 deadlines: deadline.map { [TripDeadline(label: "무료 취소 기한", at: $0)] } ?? [],
                 recommendedOn: recommended, childNote: nil, childNoteIsAlert: false, bookingId: nil)
    }

    func testOpenTasksByRecommendedDateThenDeadline() {
        let a = task("a", recommended: at(2027, 5, 6), deadline: at(2027, 5, 13))
        let b = task("b", recommended: at(2027, 5, 6), deadline: at(2027, 5, 8))
        let c = task("c", recommended: at(2027, 5, 4))
        XCTAssertEqual(TripTaskOrdering.ordered([a, b, c], states: []).map(\.id), ["c", "b", "a"])
    }

    func testDoneTasksGoLast() {
        let a = task("a", recommended: at(2027, 5, 2))
        let b = task("b", recommended: at(2027, 5, 3))
        let done = [TripTaskState(taskId: "a", isDone: true)]
        XCTAssertEqual(TripTaskOrdering.ordered([a, b], states: done).map(\.id), ["b", "a"])
    }

    func testDDayCountsCalendarDays() {
        let now = at(2027, 5, 6, 10, 0)
        XCTAssertEqual(TripTaskOrdering.dDay(to: at(2027, 5, 8, 15, 10), now: now, calendar: cal), 2)
        XCTAssertEqual(TripTaskOrdering.dDay(to: at(2027, 5, 6, 23, 0), now: now, calendar: cal), 0)
        XCTAssertEqual(TripTaskOrdering.dDay(to: at(2027, 5, 5, 9, 0), now: now, calendar: cal), -1)
    }

    func testUrgentFromThreeDaysBefore() {
        let now = at(2027, 5, 6, 10, 0)
        XCTAssertTrue(TripTaskOrdering.isUrgent(at(2027, 5, 9, 9, 0), now: now, calendar: cal))
        XCTAssertFalse(TripTaskOrdering.isUrgent(at(2027, 5, 10, 9, 0), now: now, calendar: cal))
    }

    func testPastDeadlineIsUrgent() {
        let now = at(2027, 5, 6, 10, 0)
        XCTAssertTrue(TripTaskOrdering.isUrgent(at(2027, 5, 4, 9, 0), now: now, calendar: cal))
        XCTAssertEqual(TripDateText.dDayText(-2), "지남")
        XCTAssertEqual(TripDateText.dDayText(0), "D-day")
        XCTAssertEqual(TripDateText.dDayText(2), "D-2")
    }

    func testDateTextFormat() {
        XCTAssertEqual(TripDateText.dayTime(at(2027, 5, 8, 15, 10), calendar: cal), "5.8(토) 15:10")
        XCTAssertEqual(TripDateText.day(at(2027, 5, 14), calendar: cal), "5.14(금)")
        XCTAssertEqual(TripDateText.recommended(at(2027, 5, 6), calendar: cal), "5.6(목)쯤 하면 좋아요")
    }
}

// MARK: - Task 5 · 아기 리듬

enum RhythmFixtures {
    private static func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }

    /// 5/2~5/8 — 낮잠 09:40 70분 매일 · 14:10 80분 6일(7일엔 없음) · 밤잠 20:10~다음 날 06:50 ·
    /// 병수유 06:50부터 230분마다(밤잠 전까지) · 이유식 08:10 · 17:40
    static func week(days: ClosedRange<Int> = 1...7, food: String? = "소고기 죽", carSeatNapDays: Set<Int> = []) -> [Activity] {
        var list: [Activity] = []
        for d in days {
            list.append(Activity(id: "n1-\(d)", babyId: "b1", type: .sleep, startTime: at(2027, 5, d + 1, 9, 40),
                                 endTime: at(2027, 5, d + 1, 10, 50),
                                 sleepMethod: carSeatNapDays.contains(d) ? .carSeat : .bed))
            if d != 7 {
                list.append(Activity(id: "n2-\(d)", babyId: "b1", type: .sleep, startTime: at(2027, 5, d + 1, 14, 10),
                                     endTime: at(2027, 5, d + 1, 15, 30)))
            }
            list.append(Activity(id: "night-\(d)", babyId: "b1", type: .sleep, startTime: at(2027, 5, d + 1, 20, 10),
                                 endTime: at(2027, 5, d + 2, 6, 50)))
            for (i, minute) in [410, 640, 870, 1100].enumerated() {
                list.append(Activity(id: "f\(i)-\(d)", babyId: "b1", type: .feedingBottle,
                                     startTime: at(2027, 5, d + 1, minute / 60, minute % 60)))
            }
            list.append(Activity(id: "s1-\(d)", babyId: "b1", type: .feedingSolid, startTime: at(2027, 5, d + 1, 8, 10), foodName: food))
            list.append(Activity(id: "s2-\(d)", babyId: "b1", type: .feedingSolid, startTime: at(2027, 5, d + 1, 17, 40), foodName: food))
        }
        return list
    }

    static let window = DateInterval(start: TravelTestClock.at(2027, 5, 2), end: TravelTestClock.at(2027, 5, 9))
}

final class BabyRhythmSummaryTests: XCTestCase {
    private let cal = TravelTestClock.cal

    private func build(_ activities: [Activity]) -> BabyRhythm {
        BabyRhythmSummary.build(activities: activities, window: RhythmFixtures.window, calendar: cal)
    }

    func testNapBlocksMedianAndShare() {
        let naps = build(RhythmFixtures.week()).naps
        XCTAssertEqual(naps.map(\.startMinute), [580, 850])
        XCTAssertEqual(naps.map(\.minutes), [70, 80])
        XCTAssertEqual(naps[0].share, 1.0, accuracy: 0.001)
        XCTAssertEqual(naps[1].share, 6.0 / 7.0, accuracy: 0.001)
    }

    func testBedtimeAndWake() {
        let r = build(RhythmFixtures.week())
        XCTAssertEqual(r.bedtimeMinute, 1210)
        XCTAssertEqual(r.wakeMinute, 410)
    }

    func testDayFeedInterval() {
        XCTAssertEqual(build(RhythmFixtures.week()).dayFeedIntervalMin, 230)
    }

    func testFeedIntervalNilWhenFewerThanFourGaps() {
        XCTAssertNil(build(RhythmFixtures.week(days: 1...1)).dayFeedIntervalMin, "하루치 간격 3개 — 4개 미만이면 비워 둔다")
    }

    func testSolidTimesAndMeat() {
        let r = build(RhythmFixtures.week())
        XCTAssertEqual(r.solids.map(\.startMinute), [490, 1060])
        XCTAssertEqual(r.meat, .present)
        XCTAssertTrue(r.hasSolids)
        XCTAssertEqual(build(RhythmFixtures.week(food: "물고기 죽")).meat, .absent, "물고기는 고기가 아니다")
        XCTAssertEqual(build(RhythmFixtures.week(food: nil)).meat, .unknown)
        XCTAssertEqual(build(RhythmFixtures.week().filter { $0.type != .feedingSolid }).meat, .noSolids)
    }

    func testCarSeatNaps() {
        XCTAssertEqual(build(RhythmFixtures.week(carSeatNapDays: [2, 5])).carSeatNaps, 2)
    }

    // 같은 기록이 두 번 들어와도(자정 넘긴 잠은 어제·오늘 목록 양쪽에 있다) 한 번만 센다
    func testOvernightSleepCountsOnce() {
        let week = RhythmFixtures.week()
        let doubled = week + week.filter { $0.id.hasPrefix("night-") }
        XCTAssertEqual(build(doubled), build(week))
    }

    // 창보다 먼저 시작한 잠(5/1 밤)은 세지 않는다
    func testRecordsBeforeWindowAreIgnored() {
        let before = Activity(id: "night-0", babyId: "b1", type: .sleep,
                              startTime: TravelTestClock.at(2027, 5, 1, 23, 0), endTime: TravelTestClock.at(2027, 5, 2, 9, 30))
        XCTAssertEqual(build(RhythmFixtures.week() + [before]), build(RhythmFixtures.week()))
    }

    func testWindowBeforeAndAfterDeparture() {
        let trip = TravelFixtures.osakaTrip()
        XCTAssertEqual(BabyRhythmSummary.window(trip: trip, now: TravelTestClock.at(2027, 5, 6, 10, 0), calendar: cal),
                       DateInterval(start: TravelTestClock.at(2027, 4, 29), end: TravelTestClock.at(2027, 5, 6)))
        XCTAssertEqual(BabyRhythmSummary.window(trip: trip, now: TravelTestClock.at(2027, 5, 11, 8, 0), calendar: cal),
                       DateInterval(start: TravelTestClock.at(2027, 5, 3), end: TravelTestClock.at(2027, 5, 10)))
    }

    func testSparseRecordsMarkRhythmRough() {
        XCTAssertTrue(build(RhythmFixtures.week(days: 1...3)).isRough)
        XCTAssertFalse(build(RhythmFixtures.week()).isRough)
        XCTAssertEqual(build(RhythmFixtures.week()).daysWithRecords, 7)
    }
}

// MARK: - Task 7 · 지도 주소 · 알림 계획

final class TripReminderPlannerTests: XCTestCase {
    private let cal = TravelTestClock.cal
    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }

    private func reminders(now: Date, states: [TripTaskState] = [], trip: Trip = TravelFixtures.osakaTrip()) -> [TripReminder] {
        let child = TripChildContext(birthDate: at(2026, 8, 30), heightCm: 70.5, weightKg: 8.4, meat: .present, hasSolids: true)
        let tasks = TripTaskEngine.tasks(trip: trip, child: child, now: now, calendar: cal)
        return TripReminderPlanner.reminders(trip: trip, tasks: tasks, states: states, now: now, calendar: cal)
    }

    private func fire(_ id: String, in list: [TripReminder]) -> Date? { list.first { $0.identifier == id }?.fireAt }

    func testTwoRemindersPerDeadline() {
        let list = reminders(now: at(2027, 5, 2, 10, 0))
        XCTAssertEqual(fire("trip-t1-bassinet-0-d3", in: list), at(2027, 5, 5, 9, 0))
        XCTAssertEqual(fire("trip-t1-bassinet-0-d1", in: list), at(2027, 5, 7, 9, 0))
        XCTAssertEqual(fire("trip-t1-bassinet-1-d3", in: list), at(2027, 5, 9, 9, 0))
        XCTAssertEqual(fire("trip-t1-bassinet-1-d1", in: list), at(2027, 5, 11, 9, 0))
        XCTAssertEqual(fire("trip-t1-car_seat-c1-0-d1", in: list), at(2027, 5, 6, 9, 0))
        XCTAssertTrue(list.allSatisfy { $0.identifier.hasPrefix("trip-t1-") })
    }

    func testNoReminderInThePast() {
        let list = reminders(now: at(2027, 5, 6, 10, 0))
        XCTAssertNil(fire("trip-t1-bassinet-0-d3", in: list))
        XCTAssertNil(fire("trip-t1-car_seat-c1-0-d1", in: list), "5/6 09:00 은 이미 지났다")
        XCTAssertNotNil(fire("trip-t1-bassinet-0-d1", in: list))
        XCTAssertTrue(list.allSatisfy { $0.fireAt > at(2027, 5, 6, 10, 0) })
    }

    func testDoneTaskHasNoReminders() {
        let list = reminders(now: at(2027, 5, 2, 10, 0), states: [TripTaskState(taskId: "bassinet", isDone: true)])
        XCTAssertFalse(list.contains { $0.identifier.hasPrefix("trip-t1-bassinet-") })
        XCTAssertTrue(list.contains { $0.identifier.hasPrefix("trip-t1-infant_meal-") })
    }

    func testReminderIdsAreStablePerDeadline() {
        var trip = TravelFixtures.osakaTrip()
        let before = Set(reminders(now: at(2027, 5, 2, 10, 0), trip: trip).map(\.identifier))
        trip.bookings[1].depart = .at(at(2027, 5, 14, 13, 0))  // 오는 편 시각만 바뀜
        let after = Set(reminders(now: at(2027, 5, 2, 10, 0), trip: trip).map(\.identifier))
        XCTAssertEqual(before, after)
    }

    func testReminderText() {
        let list = reminders(now: at(2027, 5, 2, 10, 0))
        let d1 = list.first { $0.identifier == "trip-t1-bassinet-0-d1" }
        XCTAssertEqual(d1?.title, "여행 마감 내일")
        XCTAssertEqual(d1?.body, "배시넷 신청 · 가는 편 5.8(토) 15:10까지")
        XCTAssertEqual(list.first { $0.identifier == "trip-t1-bassinet-0-d3" }?.title, "여행 마감 3일 전")
    }

    func testMapsLinksEncodeQuery() {
        XCTAssertEqual(GoogleMapsLink.place("간사이공항")?.absoluteString,
                       "https://www.google.com/maps/search/?api=1&query=%EA%B0%84%EC%82%AC%EC%9D%B4%EA%B3%B5%ED%95%AD")
        let dir = GoogleMapsLink.directions(from: "간사이공항", to: "아라시야마 숙소")?.absoluteString ?? ""
        XCTAssertTrue(dir.hasPrefix("https://www.google.com/maps/dir/?api=1&origin="))
        XCTAssertTrue(dir.contains("&destination=%EC%95%84%EB%9D%BC%EC%8B%9C%EC%95%BC%EB%A7%88%20%EC%88%99%EC%86%8C"))
        XCTAssertTrue(dir.hasSuffix("&travelmode=driving"))
        XCTAssertNil(GoogleMapsLink.place("   "))
    }
}

// MARK: - Task 8 · 저장소 · 뷰모델

@MainActor
final class TripViewModelTests: XCTestCase {
    private let cal = TravelTestClock.cal
    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }

    private func detail(store: MockTripFirestore = MockTripFirestore(),
                        scheduler: MockTripReminderScheduler = MockTripReminderScheduler(),
                        childData: MockTripChildData = MockTripChildData(),
                        now: Date = TravelTestClock.at(2027, 5, 2, 10, 0)) -> TripDetailViewModel {
        TripDetailViewModel(trip: TravelFixtures.osakaTrip(), ownerUserId: "o", currentUserId: "p",
                            babyBirthDate: at(2026, 8, 30), provider: store, childData: childData,
                            reminders: scheduler, now: { now }, calendar: cal)
    }

    // 공유받은 보호자는 소유자 경로로 읽는다
    func testLoadUsesOwnerPathForSharedBaby() async {
        let store = MockTripFirestore()
        store.seed([TravelFixtures.osakaTrip()], userId: "o", babyId: "b1")
        let vm = TripListViewModel(provider: store)
        await vm.load(currentUserId: "p", ownerUserId: "o", babyId: "b1")
        XCTAssertEqual(store.capturedUserIds, ["o"])
        XCTAssertEqual(vm.trips.map(\.id), ["t1"])
    }

    // 로그아웃 뒤에도 dataUserId 는 소유자 uid 를 돌려준다 — currentUserId 가 없으면 아무것도 안 읽는다
    func testLoadWithoutCurrentUserDoesNothing() async {
        let store = MockTripFirestore()
        store.seed([TravelFixtures.osakaTrip()], userId: "o", babyId: "b1")
        let vm = TripListViewModel(provider: store)
        await vm.load(currentUserId: nil, ownerUserId: "o", babyId: "b1")
        XCTAssertEqual(store.fetchCount, 0)
        XCTAssertEqual(vm.trips, [])
    }

    // 빈 상태로 만든다 — 예시 예약·할 일을 미리 넣지 않는다
    func testCreateSavesEmptyTripUnderBaby() async {
        let store = MockTripFirestore()
        let vm = TripListViewModel(provider: store, now: { TravelTestClock.at(2027, 5, 5, 20, 0) })
        let trip = await vm.create(city: "오사카", countryCode: "JP", startDay: "2027-05-10", endDay: "2027-05-14",
                                   currentUserId: "p", ownerUserId: "o", babyId: "b1")
        XCTAssertEqual(store.created.last?.userId, "o")
        XCTAssertEqual(trip?.babyId, "b1")
        XCTAssertEqual(trip?.bookings, [])
        XCTAssertEqual(trip?.taskStates, [])
        XCTAssertEqual(trip?.moves, [])
        XCTAssertEqual(trip?.createdBy, "p")
        XCTAssertEqual(vm.trips.count, 1)
    }

    func testNextTripIsEarliestNotFinished() {
        let vm = TripListViewModel(provider: MockTripFirestore())
        let past = Trip(id: "past", babyId: "b1", countryCode: "JP", city: "삿포로", startDay: "2027-04-01", endDay: "2027-05-02")
        let soon = TravelFixtures.osakaTrip()
        let later = Trip(id: "later", babyId: "b1", countryCode: "JP", city: "후쿠오카", startDay: "2027-06-01", endDay: "2027-06-03")
        vm.trips = [later, past, soon]
        XCTAssertEqual(vm.nextTrip(today: at(2027, 5, 5), calendar: cal)?.id, "t1")
        XCTAssertEqual(vm.nextTrip(today: at(2027, 5, 14), calendar: cal)?.id, "t1", "여행 마지막 날까지는 그 여행")
        XCTAssertEqual(vm.nextTrip(today: at(2027, 5, 15), calendar: cal)?.id, "later")
    }

    func testDeleteCancelsReminders() async {
        let store = MockTripFirestore()
        store.seed([TravelFixtures.osakaTrip()], userId: "o", babyId: "b1")
        let scheduler = MockTripReminderScheduler()
        let vm = TripListViewModel(provider: store)
        await vm.load(currentUserId: "p", ownerUserId: "o", babyId: "b1")
        await vm.delete(TravelFixtures.osakaTrip(), currentUserId: "p", ownerUserId: "o", reminders: scheduler)
        XCTAssertEqual(store.deleteCount, 1)
        XCTAssertEqual(scheduler.cancelled, ["t1"])
        XCTAssertEqual(vm.trips, [])
    }

    func testToggleDoneKeepsStateWhenBookingChanges() async {
        let vm = detail()
        await vm.toggleDone("bassinet")
        var outbound = TravelFixtures.outbound()
        outbound.depart = .at(at(2027, 5, 10, 16, 40))
        await vm.upsertBooking(outbound)
        XCTAssertEqual(vm.state(for: "bassinet")?.isDone, true)
        XCTAssertEqual(vm.state(for: "bassinet")?.doneBy, "p")
        XCTAssertEqual(vm.tasks.first { $0.id == "bassinet" }?.deadlines.first?.at, at(2027, 5, 8, 16, 40))
    }

    func testEditingBookingReplacesReminders() async {
        let scheduler = MockTripReminderScheduler()
        let vm = detail(scheduler: scheduler)
        var outbound = TravelFixtures.outbound()
        outbound.depart = .at(at(2027, 5, 10, 16, 40))
        await vm.upsertBooking(outbound)
        XCTAssertEqual(scheduler.replaced.count, 1)
        XCTAssertEqual(scheduler.replaced.last?.tripId, "t1")
        let reminders = scheduler.replaced.last?.reminders ?? []
        XCTAssertTrue(reminders.allSatisfy { $0.identifier.hasPrefix("trip-t1-") })
        XCTAssertTrue(reminders.contains { $0.identifier == "trip-t1-bassinet-0-d1" && $0.fireAt == at(2027, 5, 7, 9, 0) })
    }

    // 저장이 실패하면 되돌리고 알린다(체크한 것처럼 보이면 안 된다)
    func testSaveFailureRollsBackAndShowsError() async {
        let store = MockTripFirestore()
        store.errorToThrow = NSError(domain: "test", code: 1)
        let vm = detail(store: store)
        await vm.toggleDone("bassinet")
        XCTAssertNotEqual(vm.state(for: "bassinet")?.isDone, true)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testSetAssigneeSaves() async {
        let store = MockTripFirestore()
        let vm = detail(store: store)
        await vm.setAssignee(.father, for: "bassinet")
        XCTAssertEqual(vm.state(for: "bassinet")?.assignee, .father)
        XCTAssertEqual(store.writeCount, 1)
        XCTAssertEqual(store.capturedUserIds.last, "o")
    }

    func testRemoveBookingDropsItsTasks() async {
        let vm = detail()
        await vm.removeBooking(id: "h1")
        XCTAssertNil(vm.tasks.first { $0.id == "hotel_crib-h1" })
    }

    func testLoadChildBuildsRhythmFromRecords() async {
        let childData = MockTripChildData()
        childData.activities = RhythmFixtures.week()
        childData.growth = [GrowthRecord(babyId: "b1", date: at(2027, 4, 3), height: 70.5),
                            GrowthRecord(babyId: "b1", date: at(2027, 4, 15), weight: 8.4),
                            GrowthRecord(babyId: "b1", date: at(2027, 3, 2), height: 66, weight: 7.6)]
        let vm = detail(childData: childData, now: at(2027, 5, 9, 10, 0))
        await vm.loadChild()
        XCTAssertEqual(childData.capturedFrom, at(2027, 5, 1), "창(5/2~) 하루 앞부터 받는다 — 활동 조회는 시작 시각만 묻는다")
        XCTAssertEqual(childData.capturedUserIds, ["o", "o"])
        XCTAssertEqual(vm.rhythm?.wakeMinute, 410)
        XCTAssertEqual(vm.child.heightCm, 70.5)
        XCTAssertEqual(vm.child.weightKg, 8.4)
        XCTAssertEqual(vm.child.meat, .present)
        XCTAssertNotNil(vm.tasks.first { $0.id == "solids_quarantine" })
    }
}

// MARK: - 화면 그리기 확인 — 네 칸과 홈 카드가 실제 데이터로 그려지는지(그림은 /tmp/babycare_screenshots/trip_*.png)

@MainActor
final class TripScreenRenderTests: XCTestCase {
    private let dir = "/tmp/babycare_screenshots"

    private func model() async -> TripDetailViewModel {
        let childData = MockTripChildData()
        childData.activities = RhythmFixtures.week()
        childData.growth = [GrowthRecord(babyId: "b1", date: TravelTestClock.at(2027, 4, 15), height: 70.5, weight: 8.4)]
        let trip = TravelFixtures.osakaTrip(moves: [
            TripMove(id: "m1", startAt: TravelTestClock.at(2027, 5, 10, 18, 30), minutes: 90,
                     fromLabel: "간사이공항", toLabel: "아라시야마 숙소")
        ])
        let vm = TripDetailViewModel(trip: trip, ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: TravelTestClock.at(2026, 8, 30),
                                     provider: MockTripFirestore(), childData: childData,
                                     reminders: MockTripReminderScheduler(),
                                     now: { TravelTestClock.at(2027, 5, 9, 10, 0) }, calendar: TravelTestClock.cal)
        await vm.loadChild()
        return vm
    }

    private func render<V: View>(_ view: V, height: CGFloat) throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: height)
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.isHidden = false
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1.0))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        return image
    }

    func testTripScreensRender() async throws {
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let vm = await model()
        let screens: [(String, AnyView, CGFloat)] = [
            ("plan", AnyView(TravelPlanView(vm: vm, day: .constant(nil))), 2000),
            ("bookings", AnyView(TravelBookingsView(vm: vm)), 1500),
            ("prep_tasks", AnyView(TravelPrepView(vm: vm, section: .constant(.tasks), filter: .constant(.all))), 1500),
            ("prep_rules", AnyView(TravelPrepView(vm: vm, section: .constant(.rules), filter: .constant(.all))), 1500)
        ]
        for (name, screen, height) in screens {
            let image = try render(NavigationStack { screen.navigationTitle(vm.trip.city) }, height: height)
            XCTAssertGreaterThan(image.size.height, 0)
            try image.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/trip_\(name).png"))
        }
        let card = try render(NavigationStack { ScrollView { TripHomeCard(trip: vm.trip).padding() } }, height: 300)
        try card.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/trip_home_card.png"))
    }
}

// MARK: - 마지막 검토 고침 — 덮어쓰기(Critical 1 · Important 1)

@MainActor
final class TripConcurrentEditTests: XCTestCase {
    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }

    private func detail(_ trip: Trip, store: MockTripFirestore) -> TripDetailViewModel {
        TripDetailViewModel(trip: trip, ownerUserId: "o", currentUserId: "p", babyBirthDate: at(2026, 8, 30),
                            provider: store, childData: MockTripChildData(), reminders: MockTripReminderScheduler(),
                            now: { TravelTestClock.at(2027, 5, 2, 10, 0) }, calendar: TravelTestClock.cal)
    }

    // 홈 카드가 넘긴 옛 사본으로 열어도, 고칠 때 저장소에 있는 더 새 예약을 지우지 않는다
    func testEditFromStaleCopyKeepsNewerBooking() async {
        let store = MockTripFirestore()
        store.seed([TravelFixtures.osakaTrip(bookings: [TravelFixtures.outbound()])], userId: "o", babyId: "b1")
        let vm = detail(TravelFixtures.osakaTrip(bookings: []), store: store)
        await vm.upsertBooking(TravelFixtures.hotel)
        let saved = store.stored(userId: "o", babyId: "b1", tripId: "t1")
        XCTAssertEqual(Set(saved?.bookings.map(\.id) ?? []), ["f1", "h1"])
    }

    // 두 보호자가 같은 여행을 열어 두고 각자 고쳐도 둘 다 남는다
    func testTwoCaregiversEditingTogetherKeepBoth() async {
        let store = MockTripFirestore()
        store.seed([TravelFixtures.osakaTrip()], userId: "o", babyId: "b1")
        let mom = detail(TravelFixtures.osakaTrip(), store: store)
        let dad = detail(TravelFixtures.osakaTrip(), store: store)
        await mom.toggleDone("bassinet")
        await dad.setAssignee(.father, for: "infant_meal")
        let saved = store.stored(userId: "o", babyId: "b1", tripId: "t1")
        XCTAssertEqual(saved?.taskStates.first { $0.taskId == "bassinet" }?.isDone, true, "엄마 체크가 아빠 저장에 지워졌다")
        XCTAssertEqual(saved?.taskStates.first { $0.taskId == "infant_meal" }?.assignee, .father)
    }
}

@MainActor
final class TripLiveUpdateTests: XCTestCase {
    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }

    /// 스트림이 흘린 것을 화면이 받을 때까지 잠깐 기다린다.
    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // 열려 있는 동안 다른 보호자가 바꾼 것이 바로 보이고, 알림도 그 상태로 다시 걸린다
    func testPartnerChangeArrivesWhileOpen() async {
        let store = MockTripFirestore()
        store.seed([TravelFixtures.osakaTrip()], userId: "o", babyId: "b1")
        let scheduler = MockTripReminderScheduler()
        let vm = TripDetailViewModel(trip: TravelFixtures.osakaTrip(bookings: []), ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: at(2026, 8, 30), provider: store, childData: MockTripChildData(),
                                     reminders: scheduler, now: { TravelTestClock.at(2027, 5, 2, 10, 0) },
                                     calendar: TravelTestClock.cal)
        let watching = Task { await vm.observe() }
        await eventually { vm.trip.bookings.count == 4 }
        XCTAssertEqual(vm.trip.bookings.count, 4, "열자마자 저장소의 최신 문서를 받는다(넘겨받은 빈 사본이 아니라)")

        var partner = TravelFixtures.osakaTrip()
        partner.taskStates = [TripTaskState(taskId: "bassinet", isDone: true, doneBy: "mom")]
        store.push(partner, userId: "o")
        await eventually { vm.state(for: "bassinet")?.isDone == true }
        XCTAssertEqual(vm.state(for: "bassinet")?.isDone, true)
        await eventually { scheduler.replaced.last?.reminders.contains { $0.identifier.hasPrefix("trip-t1-bassinet-") } == false }
        XCTAssertFalse(scheduler.replaced.last?.reminders.contains { $0.identifier.hasPrefix("trip-t1-bassinet-") } ?? true,
                       "끝낸 일의 알림은 다시 걸리지 않는다")
        watching.cancel()
    }

    // 넘겨받은 옛 사본으로는 알림을 다시 걸지 않는다(저장소에서 받기 전)
    func testNoReplanFromStaleCopyBeforeFirstSnapshot() async {
        let scheduler = MockTripReminderScheduler()
        let vm = TripDetailViewModel(trip: TravelFixtures.osakaTrip(bookings: []), ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: at(2026, 8, 30), provider: MockTripFirestore(), childData: MockTripChildData(),
                                     reminders: scheduler, now: { TravelTestClock.at(2027, 5, 2, 10, 0) },
                                     calendar: TravelTestClock.cal)
        await vm.loadChild()
        XCTAssertTrue(scheduler.replaced.isEmpty)
    }

    func testDeletedElsewhereIsShown() async {
        let store = MockTripFirestore()
        store.seed([TravelFixtures.osakaTrip()], userId: "o", babyId: "b1")
        let scheduler = MockTripReminderScheduler()
        let vm = TripDetailViewModel(trip: TravelFixtures.osakaTrip(), ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: at(2026, 8, 30), provider: store, childData: MockTripChildData(),
                                     reminders: scheduler, now: { TravelTestClock.at(2027, 5, 2, 10, 0) },
                                     calendar: TravelTestClock.cal)
        let watching = Task { await vm.observe() }
        await eventually { !scheduler.replaced.isEmpty }
        try? await store.deleteTrip("t1", userId: "o", babyId: "b1")
        await eventually { vm.isDeleted }
        XCTAssertTrue(vm.isDeleted)
        await eventually { scheduler.cancelled == ["t1"] }
        XCTAssertEqual(scheduler.cancelled, ["t1"])
        watching.cancel()
    }

    func testUpdateTripInfoKeepsBookings() async {
        let store = MockTripFirestore()
        store.seed([TravelFixtures.osakaTrip()], userId: "o", babyId: "b1")
        let vm = TripDetailViewModel(trip: TravelFixtures.osakaTrip(), ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: at(2026, 8, 30), provider: store, childData: MockTripChildData(),
                                     reminders: MockTripReminderScheduler(), now: { TravelTestClock.at(2027, 5, 2, 10, 0) },
                                     calendar: TravelTestClock.cal)
        await vm.updateTripInfo(city: " 교토 ", startDay: "2027-05-11", endDay: "2027-05-14")
        let saved = store.stored(userId: "o", babyId: "b1", tripId: "t1")
        XCTAssertEqual(saved?.city, "교토")
        XCTAssertEqual(saved?.startDay, "2027-05-11")
        XCTAssertEqual(saved?.bookings.count, 4)
    }
}

// MARK: - 마지막 검토 고침 — 고기 판별 · 아기 기록 못 읽음 · 일본 규칙 카드(Important 3)

final class TripMeatWordTests: XCTestCase {
    private func meat(_ food: String?) -> MeatPresence {
        BabyRhythmSummary.build(activities: RhythmFixtures.week(food: food), window: RhythmFixtures.window, calendar: TravelTestClock.cal).meat
    }

    // 흔한 이유식 이름 — 「고기」라는 말이 없어도 고기다
    func testCommonBabyFoodNamesCountAsMeat() {
        for name in ["닭죽", "한우 진밥", "소안심죽", "사골 미음", "닭가슴살 미음", "돼지 안심죽", "오리 진밥"] {
            XCTAssertEqual(meat(name), .present, name)
        }
    }

    // 고기가 아닌 말 — 「소금」의 소 · 생선 · 물고기
    func testNonMeatNamesStayAbsent() {
        for name in ["소금 안 넣은 감자죽", "생선죽", "물고기 미음", "단호박 퓌레"] {
            XCTAssertEqual(meat(name), .absent, name)
        }
    }
}

@MainActor
final class TripChildLoadTests: XCTestCase {
    private func vm(childData: MockTripChildData, trip: Trip = TravelFixtures.osakaTrip()) -> TripDetailViewModel {
        TripDetailViewModel(trip: trip, ownerUserId: "o", currentUserId: "p", babyBirthDate: TravelTestClock.at(2026, 8, 30),
                            provider: MockTripFirestore(), childData: childData, reminders: MockTripReminderScheduler(),
                            now: { TravelTestClock.at(2027, 5, 9, 10, 0) }, calendar: TravelTestClock.cal)
    }

    // 못 읽은 것을 「기록이 없다」와 구분한다
    func testChildLoadFailureIsReported() async {
        let data = MockTripChildData()
        data.errorToThrow = NSError(domain: "test", code: 1)
        let model = vm(childData: data)
        await model.loadChild()
        XCTAssertTrue(model.childLoadFailed)
    }

    // 일본 여행이면 이유식 기록이 없어도 규칙 칸에 고기 든 이유식 카드가 있다
    func testJapanTripAlwaysShowsMeatRuleCard() async {
        let model = vm(childData: MockTripChildData())
        await model.loadChild()
        XCTAssertNil(model.tasks.first { $0.key == .solidsQuarantine }, "할 일은 기록이 있을 때만(설계서)")
        XCTAssertTrue(model.ruleCards.contains { $0.key == .solidsQuarantine })
    }
}

// MARK: - 마지막 검토 고침 — 예약 입력(re-grade Important)

final class TripBookingFormTests: XCTestCase {
    private let cal = TravelTestClock.cal
    private func at(_ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(2027, m, d, h, mi) }

    // 「 KE」「icn 」처럼 넣어도 대한항공 규칙·공항 안내가 꺼지지 않는다
    func testNormalizeTrimsAndUppercasesCodes() {
        let raw = TripBooking(id: "f1", kind: .flight, airline: " ke ", flightNumber: " ke 725 ", fromAirport: "icn ", toAirport: " kix",
                              depart: .at(at(5, 10, 15, 10)), arrive: .at(at(5, 10, 17, 0)))
        let b = TripBookingForm.normalized(raw)
        XCTAssertEqual(b.airline, "KE")
        XCTAssertEqual(b.flightNumber, "KE725")
        XCTAssertEqual(b.fromAirport, "ICN")
        XCTAssertEqual(b.toAirport, "KIX")
    }

    func testFlightNeedsAirlineNumberAndArrivalAfterDeparture() {
        var f = TripBooking(id: "f1", kind: .flight, airline: "KE", flightNumber: "KE725", fromAirport: "ICN", toAirport: "KIX",
                            depart: .at(at(5, 10, 15, 10)), arrive: .at(at(5, 10, 17, 0)))
        XCTAssertNil(TripBookingForm.problem(f, calendar: TravelTestClock.cal))
        f.airline = nil
        XCTAssertEqual(TripBookingForm.problem(f, calendar: TravelTestClock.cal), "항공사 코드를 입력해 주세요")
        f.airline = "KE"
        f.arrive = .at(at(5, 10, 14, 0))
        XCTAssertEqual(TripBookingForm.problem(f, calendar: TravelTestClock.cal), "도착이 출발보다 늦어야 해요")
    }

    func testHotelAndCarTimesInOrder() {
        let hotel = TripBooking(id: "h1", kind: .hotel, name: "숙소", checkIn: .at(at(5, 12, 15)), checkOut: .at(at(5, 11, 10)))
        XCTAssertEqual(TripBookingForm.problem(hotel, calendar: TravelTestClock.cal), "체크아웃이 체크인보다 늦어야 해요")
        let car = TripBooking(id: "c1", kind: .rentalCar, pickup: .at(at(5, 10, 18)), carReturn: .at(at(5, 10, 9)))
        XCTAssertEqual(TripBookingForm.problem(car, calendar: TravelTestClock.cal), "반납이 인수보다 늦어야 해요")
    }

    // ⛔ 시각을 요구하지 않는다 — 날짜만 알면 저장한다(ADR-0001).
    func testDateOnlyBookingsCanBeSaved() {
        let cal = TravelTestClock.cal
        let hotel = TripBooking(id: "h1", kind: .hotel, name: "숙소", checkIn: .day("2027-05-10"), checkOut: .day("2027-05-12"))
        XCTAssertNil(TripBookingForm.problem(hotel, calendar: cal))
        let car = TripBooking(id: "c1", kind: .rentalCar, pickup: .day("2027-05-10"), carReturn: .day("2027-05-14"))
        XCTAssertNil(TripBookingForm.problem(car, calendar: cal))
        let flight = TripBooking(id: "f1", kind: .flight, airline: "KE", flightNumber: "KE999", depart: .day("2027-05-10"))
        XCTAssertNil(TripBookingForm.problem(flight, calendar: cal))
    }

    // 당일 렌터카 — 시각을 모르면 앞뒤를 모르므로 막지 않는다.
    func testSameDayCarWithoutTimesCanBeSaved() {
        let car = TripBooking(id: "c1", kind: .rentalCar, pickup: .day("2027-05-11"), carReturn: .day("2027-05-11"))
        XCTAssertNil(TripBookingForm.problem(car, calendar: TravelTestClock.cal))
    }

    func testDateOrderStillHoldsWithoutTimes() {
        let cal = TravelTestClock.cal
        let hotel = TripBooking(id: "h1", kind: .hotel, name: "숙소", checkIn: .day("2027-05-12"), checkOut: .day("2027-05-10"))
        XCTAssertEqual(TripBookingForm.problem(hotel, calendar: cal), "체크아웃이 체크인보다 늦어야 해요")
        XCTAssertEqual(TripBookingForm.problem(TripBooking(id: "f1", kind: .flight, airline: "KE", flightNumber: "KE999"), calendar: cal), "날짜를 골라 주세요")
        XCTAssertEqual(TripBookingForm.problem(TripBooking(id: "h2", kind: .hotel, name: "숙소"), calendar: cal), "체크인 날짜를 골라 주세요")
    }

    // 새 항공편은 항공사를 미리 채우지 않는다(다른 항공사가 대한항공 마감을 물려받지 않게)
    func testNewFlightStartsWithoutAirline() {
        let f = TripBookingForm.newBooking(.flight, tripStart: at(5, 10), calendar: cal)
        XCTAssertNil(f.airline)
        XCTAssertNil(f.flightNumber)
    }
}
