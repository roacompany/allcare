import XCTest
import SwiftUI
@testable import BabyCare

// MARK: - 예약·일정 넣기 「적기 → 고르기」(PO 2026-11-05 「일정, 예약사항 추가하는거 더 나이스하게.. 지금 개불편해.」)

private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }

private func schedule(_ items: String) -> Data {
    Data(#"{"response":{"header":{"resultCode":"00","resultMsg":"NORMAL SERVICE."},"body":{"items":\#(items),"numOfRows":9999,"pageNo":1,"totalCount":1}}}"#.utf8)
}

private let allDays = #""monday":"Y","tuesday":"Y","wednesday":"Y","thursday":"Y","friday":"Y","saturday":"Y","sunday":"Y""#

/// 가는 날 렌터카를 받아 그날 밤 교토 숙소 · 이동 하나(아라시야마).
private func entryTrip() -> Trip {
    let kyoto = TripBooking(id: "h2", kind: .hotel, name: "교토 숙소", address: "京都市", checkIn: .at(at(2027, 5, 10, 22, 0)),
                            checkOut: .at(at(2027, 5, 12, 10, 0)))
    let move = TripMove(id: "m1", startAt: at(2027, 5, 10, 18, 30), minutes: 90, fromLabel: "간사이공항", toLabel: "아라시야마")
    return TravelFixtures.osakaTrip(bookings: [TravelFixtures.outbound(), TravelFixtures.inbound(), TravelFixtures.car, kyoto, TravelFixtures.hotel],
                                    moves: [move])
}

final class FlightScheduleTests: XCTestCase {
    private let cal = TravelTestClock.cal

    // 실제 응답 모양(2026-11-05 실측) — 필드가 소문자 · 공항 이름에 「/ 」 · 요일은 Y/N
    func testParsesRowsWithWeekdaysAndPeriod() throws {
        let rows = try FlightScheduleParser.parse(schedule(#"[{"flightid":"KE725","airline":"대한항공","airport":"오사카/ 간사이","airportcode":"KIX","st":"1510","firstdate":"20270428","lastdate":"20270616","season":"W26","monday":"Y","tuesday":"Y","wednesday":"N","thursday":"Y","friday":"Y","saturday":"Y","sunday":"Y"}]"#),
                                                  direction: .departure)
        let r = try XCTUnwrap(rows.first)
        XCTAssertEqual(r.flightId, "KE725")
        XCTAssertEqual(r.airlineName, "대한항공")
        XCTAssertEqual(r.counterpartName, "오사카/간사이")
        XCTAssertEqual(r.counterpartCode, "KIX")
        XCTAssertEqual(r.hour, 15)
        XCTAssertEqual(r.minute, 10)
        XCTAssertEqual(r.firstDay, "20270428")
        XCTAssertEqual(r.lastDay, "20270616")
        XCTAssertEqual(r.weekdays, [1, 2, 3, 5, 6, 7], "수요일(4)만 빠진다 · 일=1")
        XCTAssertEqual(r.direction, .departure)
    }

    // 같은 편이 기간별로 여러 줄(실측 KE725 두 줄) — 그날을 덮는 줄
    func testMatchPicksRowWhosePeriodCoversTheDay() throws {
        let rows = try FlightScheduleParser.parse(schedule(#"[{"flightid":"KE725","airline":"대한항공","airport":"오사카/ 간사이","airportcode":"KIX","st":"1510","firstdate":"20270428","lastdate":"20270616",\#(allDays)},{"flightid":"KE725","airline":"대한항공","airport":"오사카/ 간사이","airportcode":"KIX","st":"1530","firstdate":"20270617","lastdate":"20270925",\#(allDays)}]"#),
                                                  direction: .departure)
        guard case .found(let nov) = FlightScheduleMatcher.match(rows: rows, flightNumber: "ke 725", day: at(2027, 5, 10), calendar: cal) else {
            return XCTFail("5.10 는 첫 줄")
        }
        XCTAssertEqual(nov.minute, 10)
        guard case .found(let dec) = FlightScheduleMatcher.match(rows: rows, flightNumber: "KE725", day: at(2027, 6, 20), calendar: cal) else {
            return XCTFail("6.20 은 둘째 줄")
        }
        XCTAssertEqual(dec.minute, 30)
    }

    // 편은 있는데 그날 안 다니면 「그날 없음」, 편이 아예 없으면 「없음」
    func testNotOnThatDayVsNotFound() throws {
        let rows = try FlightScheduleParser.parse(schedule(#"[{"flightid":"KE725","airline":"대한항공","airport":"오사카/ 간사이","airportcode":"KIX","st":"1510","firstdate":"20270428","lastdate":"20270616","monday":"Y","tuesday":"Y","wednesday":"N","thursday":"Y","friday":"Y","saturday":"Y","sunday":"Y"}]"#),
                                                  direction: .departure)
        XCTAssertEqual(FlightScheduleMatcher.match(rows: rows, flightNumber: "KE725", day: at(2027, 5, 12), calendar: cal), .notOnThatDay, "5.12 수요일")
        XCTAssertEqual(FlightScheduleMatcher.match(rows: rows, flightNumber: "KE725", day: at(2027, 9, 30), calendar: cal), .notOnThatDay, "기간 밖")
        XCTAssertEqual(FlightScheduleMatcher.match(rows: rows, flightNumber: "OZ999", day: at(2027, 5, 10), calendar: cal), .notFound)
        XCTAssertEqual(FlightScheduleMatcher.match(rows: rows, flightNumber: "", day: at(2027, 5, 10), calendar: cal), .notFound)
    }
}

final class TripFlightEntryTests: XCTestCase {
    private let cal = TravelTestClock.cal

    private func row(_ direction: FlightDirection, _ id: String, _ hhmm: (Int, Int)) -> FlightScheduleRow {
        FlightScheduleRow(flightId: id, airlineName: "대한항공", counterpartName: "오사카/간사이", counterpartCode: "KIX",
                          hour: hhmm.0, minute: hhmm.1, firstDay: "20270428", lastDay: "20270925", weekdays: Set(1...7), direction: direction)
    }

    // 인천에서 뜨는 편 — 항공사·공항·인천 출발 시각을 채우고, 도착 시각은 고른 것만
    func testOutboundFillsIncheonSideAndTakesOnlyChosenArrival() {
        let base = TripBooking(id: "x", kind: .flight)
        let b = TripFlightEntry.booking(from: row(.departure, "KE725", (15, 10)), day: at(2027, 5, 10), otherTime: nil, base: base, calendar: cal)
        XCTAssertEqual(b.id, "x")
        XCTAssertEqual(b.airline, "KE")
        XCTAssertEqual(b.flightNumber, "KE725")
        XCTAssertEqual(b.fromAirport, "ICN")
        XCTAssertEqual(b.toAirport, "KIX")
        XCTAssertEqual(b.depart?.time, at(2027, 5, 10, 15, 10))
        XCTAssertNil(b.arrive?.time, "도착 시각은 시간표에 없다 — 지어 넣지 않는다")
        let withArrival = TripFlightEntry.booking(from: row(.departure, "KE725", (15, 10)), day: at(2027, 5, 10),
                                                  otherTime: at(2026, 7, 2, 17, 0), base: base, calendar: cal)
        XCTAssertEqual(withArrival.arrive?.time, at(2027, 5, 10, 17, 0))
        let overnight = TripFlightEntry.booking(from: row(.departure, "KE651", (23, 0)), day: at(2027, 5, 10),
                                                otherTime: at(2026, 7, 2, 3, 0), base: base, calendar: cal)
        XCTAssertEqual(overnight.arrive?.time, at(2027, 5, 11, 3, 0), "도착이 출발보다 이르면 다음 날")
    }

    // 인천에 내리는 편 — 인천 도착 시각을 채우고, 출발 시각은 고른 것
    func testInboundFillsIncheonArrivalAndChosenDeparture() {
        let base = TripBooking(id: "y", kind: .flight)
        let b = TripFlightEntry.booking(from: row(.arrival, "KE724", (14, 0)), day: at(2027, 5, 14),
                                        otherTime: at(2026, 7, 2, 11, 55), base: base, calendar: cal)
        XCTAssertEqual(b.fromAirport, "KIX")
        XCTAssertEqual(b.toAirport, "ICN")
        XCTAssertEqual(b.arrive?.time, at(2027, 5, 14, 14, 0))
        XCTAssertEqual(b.depart?.time, at(2027, 5, 14, 11, 55))
        let late = TripFlightEntry.booking(from: row(.arrival, "KE724", (14, 0)), day: at(2027, 5, 14),
                                           otherTime: at(2026, 7, 2, 23, 0), base: base, calendar: cal)
        XCTAssertEqual(late.depart?.time, at(2027, 5, 13, 23, 0), "출발이 도착보다 늦으면 전날")
    }

    func testAirlineCodeComesFromFlightNumber() {
        XCTAssertEqual(TripFlightEntry.airlineCode("7c1301"), "7C")
        XCTAssertNil(TripFlightEntry.airlineCode("12"))
    }
}

final class TripEntryChoicesTests: XCTestCase {
    private let cal = TravelTestClock.cal

    // 고를 장소 — 그 여행의 공항(편 순서) · 숙소(체크인 순) · 렌터카 장소 · 넣은 이동 장소 · 겹치지 않게
    func testPlacesFromTripInOrderWithoutDuplicates() {
        XCTAssertEqual(TripEntryChoices.places(in: entryTrip(), calendar: cal), ["인천공항", "간사이공항", "교토 숙소", "오사카 숙소", "아라시야마"])
    }

    // 이동 출발 기본 = 그날 가장 늦게 끝나는 일 뒤(도착 17:00 · 인수 18:00 · 이동 18:30+90분 → 20:00) · 체크인 마감은 끝이 아니다
    func testMoveStartsAfterTheLatestEndThatDay() {
        XCTAssertEqual(TripEntryChoices.moveStart(in: entryTrip(), day: at(2027, 5, 10), calendar: cal), at(2027, 5, 10, 20, 0))
        XCTAssertEqual(TripEntryChoices.moveStart(in: entryTrip(), day: at(2027, 5, 12), calendar: cal), at(2027, 5, 12, 10, 0), "체크아웃 뒤")
        XCTAssertNil(TripEntryChoices.moveStart(in: entryTrip(), day: at(2027, 5, 13), calendar: cal), "그날 일이 없으면 부르는 쪽 기본")
    }

    // 일정 추가의 출발 기본이 무엇 다음인지 — 시안 「그날 렌터카 인수(18:00) 다음으로 채웠어요」
    func testMoveStartSourceNamesWhatItFollows() {
        let plain = TravelFixtures.osakaTrip()
        let source = TripEntryChoices.moveStartSource(in: plain, day: at(2027, 5, 10), calendar: cal)
        XCTAssertEqual(source?.label, "렌터카 인수")
        XCTAssertEqual(source?.end, at(2027, 5, 10, 18, 0))
        XCTAssertEqual(TripEntryChoices.moveStartSource(in: entryTrip(), day: at(2027, 5, 10), calendar: cal)?.label, "아라시야마 도착")
        XCTAssertNil(TripEntryChoices.moveStartSource(in: entryTrip(), day: at(2027, 5, 13), calendar: cal))
    }

    // 렌터카 기본 날짜 — 인수 = 가는 편이 내리는 날 · 반납 = 오는 편이 뜨는 날. 시각은 짐작하지 않는다(편이 없으면 없음)
    func testRentalDefaultsComeFromFlights() {
        XCTAssertEqual(TripEntryChoices.rentalPickup(in: entryTrip(), calendar: cal), .day("2027-05-10"))
        XCTAssertEqual(TripEntryChoices.rentalReturn(in: entryTrip(), calendar: cal), .day("2027-05-14"))
        let noFlights = TravelFixtures.osakaTrip(bookings: [TravelFixtures.car])
        XCTAssertNil(TripEntryChoices.rentalPickup(in: noFlights, calendar: cal))
        XCTAssertNil(TripEntryChoices.rentalReturn(in: noFlights, calendar: cal))
    }

    // 날짜 칩 + 시각 고르기 → 하나의 시각
    func testCombineDayAndTime() {
        XCTAssertEqual(TripEntryChoices.combine(day: at(2027, 5, 10), time: at(2026, 7, 2, 15, 10), calendar: cal), at(2027, 5, 10, 15, 10))
    }
}

private final class MockSchedule: FlightScheduleProviding, @unchecked Sendable {
    var stored: [FlightScheduleRow] = []
    var error: Error?
    var calls = 0

    func rows() async throws -> [FlightScheduleRow] {
        calls += 1
        if let error { throw error }
        return stored
    }
}

@MainActor
final class TripEntryViewModelTests: XCTestCase {
    // 편명 찾기 — 찾음 · 없음 · 시간표를 못 받으면 실패(던지지 않고 화면에 말한다)
    func testLookupFlightFindsRowAndReportsFailure() async {
        let schedule = MockSchedule()
        schedule.stored = [FlightScheduleRow(flightId: "KE725", airlineName: "대한항공", counterpartName: "오사카/간사이", counterpartCode: "KIX",
                                             hour: 15, minute: 10, firstDay: "20270428", lastDay: "20270925", weekdays: Set(1...7), direction: .departure)]
        let vm = TripDetailViewModel(trip: TravelFixtures.osakaTrip(), ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: at(2026, 8, 30), provider: MockTripFirestore(), childData: MockTripChildData(),
                                     reminders: MockTripReminderScheduler(), flightSchedule: schedule,
                                     now: { at(2027, 5, 6, 10, 0) }, calendar: TravelTestClock.cal)
        let found = await vm.lookupFlight(number: "ke 725", day: at(2027, 5, 10))
        guard case .found(let row) = found else { return XCTFail("KE725 를 찾아야 한다") }
        XCTAssertEqual(row.flightId, "KE725")
        let missing = await vm.lookupFlight(number: "OZ1", day: at(2027, 5, 10))
        XCTAssertEqual(missing, .notFound)
        schedule.error = FlightStatusError.network
        let failed = await vm.lookupFlight(number: "KE725", day: at(2027, 5, 10))
        XCTAssertEqual(failed, .failed)
    }
}

private final class EntryRouteTime: RouteTimeProviding, @unchecked Sendable {
    func drivingRoute(from: String, to: String, near area: TripRouteArea) async throws -> RouteEstimate {
        RouteEstimate(minutes: 92, fromName: nil, toName: nil, source: .google)
    }
}

// MARK: - 그림 — 바뀐 넣기 화면(「지금 → 바뀐 뒤」 비교 · /tmp/babycare_screenshots/entry_*_after.png)

@MainActor
final class TravelEntryRenderTests: XCTestCase {
    private let dir = "/tmp/babycare_screenshots"

    private func render<V: View>(_ view: V, height: CGFloat, wait: TimeInterval = 1.6) throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: height)
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.isHidden = false
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(wait))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        return image
    }

    func testEntrySheetsRender() throws {
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let schedule = MockSchedule()
        schedule.stored = [FlightScheduleRow(flightId: "KE725", airlineName: "대한항공", counterpartName: "오사카/간사이", counterpartCode: "KIX",
                                             hour: 15, minute: 10, firstDay: "20270428", lastDay: "20270925", weekdays: Set(1...7), direction: .departure)]
        let cal = TravelTestClock.cal
        let vm = TripDetailViewModel(trip: entryTrip(), ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: at(2026, 8, 30), provider: MockTripFirestore(), childData: MockTripChildData(),
                                     reminders: MockTripReminderScheduler(), routeTime: EntryRouteTime(), flightSchedule: schedule,
                                     now: { at(2027, 5, 6, 10, 0) }, calendar: cal)
        // 이미 넣은 가는 편을 고칠 때 — 편명·날짜만 보이고 시간표가 채운 줄이 뜬다.
        let flight = try render(TripFlightEntrySheet(booking: TravelFixtures.outbound(), vm: vm) { _ in }, height: 852)
        try flight.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/entry_flight_after.png"))
        let start = at(2027, 5, 10)
        let hotel = try render(TripBookingEditSheet(booking: TripBookingForm.newBooking(.hotel, tripStart: start, calendar: cal), vm: vm) { _ in }, height: 852)
        try hotel.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/entry_hotel_after.png"))
        let rental = try render(TripBookingEditSheet(booking: TripBookingForm.newBooking(.rentalCar, tripStart: start, calendar: cal), vm: vm) { _ in }, height: 852)
        try rental.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/entry_rental_after.png"))
        let move = TripMove(id: "new", startAt: vm.moveStart(on: start) ?? start, minutes: 60, fromLabel: "교토 숙소", toLabel: "아라시야마")
        let moveImage = try render(TripMoveEditSheet(move: move, vm: vm) { _ in }, height: 852)
        try moveImage.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/entry_move_after.png"))
        XCTAssertGreaterThan(flight.size.height, 0)
    }
}
