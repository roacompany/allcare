import XCTest
import SwiftUI
@testable import BabyCare

// MARK: - 여행 연동(11/5 PO 「전부 다」) — 항공편 실시간(인천공항 공공데이터) · 이동 시간(구글 키가 있으면 구글, 없으면 애플 지도)

private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }

private func response(items: String, code: String = "00") -> Data {
    Data(#"{"response":{"header":{"resultCode":"\#(code)","resultMsg":"NORMAL SERVICE."},"body":{"items":\#(items),"numOfRows":1,"pageNo":1,"totalCount":1}}}"#.utf8)
}

/// 가는 날 렌터카를 받아 그날 밤 교토 숙소로 가는 여행(시안 Home-Flight 와 같은 모양).
private func kyotoTrip() -> Trip {
    let kyoto = TripBooking(id: "h2", kind: .hotel, name: "교토 숙소", address: "京都市下京区東塩小路町",
                            checkIn: .at(at(2027, 5, 10, 22, 0)), checkOut: .at(at(2027, 5, 12, 10, 0)))
    return TravelFixtures.osakaTrip(bookings: [TravelFixtures.outbound(), TravelFixtures.inbound(), TravelFixtures.car, kyoto, TravelFixtures.hotel])
}

private func departure(scheduled: Date?, estimated: Date?, remark: String = "지연") -> FlightLiveStatus {
    FlightLiveStatus(flightId: "KE725", direction: .departure, scheduled: scheduled, estimated: estimated, remark: remark,
                     gate: "251", terminal: "T2", counterpart: "오사카/간사이", carousel: nil, exit: nil, fetchedAt: at(2027, 5, 10, 9, 12))
}

final class FlightStatusParserTests: XCTestCase {
    private let cal = TravelTestClock.cal

    func testParsesDelayedDeparture() throws {
        let data = response(items: #"[{"flightId":"KE725","airport":"오사카/간사이","scheduleDateTime":"1510","estimatedDateTime":"1640","remark":"지연","gatenumber":"251","terminalId":"P03","chkinrange":"E01-E06"}]"#)
        let list = try FlightStatusParser.parse(data, direction: .departure, day: at(2027, 5, 10), fetchedAt: at(2027, 5, 10, 9, 12), calendar: cal)
        XCTAssertEqual(list.count, 1)
        let s = try XCTUnwrap(list.first)
        XCTAssertEqual(s.flightId, "KE725")
        XCTAssertEqual(s.scheduled, at(2027, 5, 10, 15, 10))
        XCTAssertEqual(s.estimated, at(2027, 5, 10, 16, 40))
        XCTAssertEqual(s.remark, "지연")
        XCTAssertEqual(s.gate, "251")
        XCTAssertEqual(s.terminal, "T2")
        XCTAssertEqual(s.counterpart, "오사카/간사이")
        XCTAssertEqual(s.fetchedAt, at(2027, 5, 10, 9, 12))
        XCTAssertEqual(s.delayMinutes, 90)
        XCTAssertTrue(s.isDelayed)
        XCTAssertFalse(s.isCancelled)
    }

    // 한 편만 오면 items 가 배열이 아니라 {"item": {...}} 로 올 수 있다
    func testItemsAsSingleDictionary() throws {
        let data = response(items: #"{"item":{"flightId":"KE724","airport":"오사카/간사이","scheduleDateTime":"1400","estimatedDateTime":"1400","remark":"도착","gatenumber":"","terminalId":"P01","carousel":"7","exitnumber":"B"}}"#)
        let s = try XCTUnwrap(FlightStatusParser.parse(data, direction: .arrival, day: at(2027, 5, 14), fetchedAt: at(2027, 5, 14, 13, 0), calendar: cal).first)
        XCTAssertEqual(s.terminal, "T1")
        XCTAssertNil(s.gate, "빈 칸은 없음으로")
        XCTAssertEqual(s.carousel, "7")
        XCTAssertEqual(s.exit, "B")
        XCTAssertFalse(s.isDelayed)
    }

    // 실제 응답(2026-11-05 실측): 없는 편은 빈 배열 · 공항 이름에 「/ 」 처럼 띄어쓰기가 섞인다
    func testEmptyItemsAndSpacedAirportName() throws {
        XCTAssertEqual(try FlightStatusParser.parse(response(items: "[]"), direction: .departure, day: at(2027, 5, 10), fetchedAt: at(2027, 5, 10), calendar: cal), [])
        XCTAssertEqual(try FlightStatusParser.parse(response(items: #""""#), direction: .departure, day: at(2027, 5, 10), fetchedAt: at(2027, 5, 10), calendar: cal), [])
        let data = response(items: #"[{"flightId":"KE725","airport":"오사카/ 간사이","scheduleDateTime":"1510","estimatedDateTime":"1531","remark":"출발"}]"#)
        let s = try XCTUnwrap(FlightStatusParser.parse(data, direction: .departure, day: at(2027, 5, 10), fetchedAt: at(2027, 5, 10), calendar: cal).first)
        XCTAssertEqual(s.counterpart, "오사카/간사이")
        XCTAssertEqual(s.delayMinutes, 21)
    }

    // 자정을 넘겨 늦어지면 바뀐 시각은 다음 날이다
    func testEstimatedPastMidnightRollsToNextDay() throws {
        let data = response(items: #"[{"flightId":"KE725","scheduleDateTime":"2350","estimatedDateTime":"0030","remark":"지연"}]"#)
        let s = try XCTUnwrap(FlightStatusParser.parse(data, direction: .departure, day: at(2027, 5, 10), fetchedAt: at(2027, 5, 10), calendar: cal).first)
        XCTAssertEqual(s.estimated, at(2027, 5, 11, 0, 30))
        XCTAssertEqual(s.delayMinutes, 40)
    }

    func testTwelveDigitTimes() throws {
        let data = response(items: #"[{"flightId":"KE725","scheduleDateTime":"202705101510","estimatedDateTime":"202705101640","remark":"지연"}]"#)
        let s = try XCTUnwrap(FlightStatusParser.parse(data, direction: .departure, day: at(2027, 5, 10), fetchedAt: at(2027, 5, 10), calendar: cal).first)
        XCTAssertEqual(s.scheduled, at(2027, 5, 10, 15, 10))
        XCTAssertEqual(s.estimated, at(2027, 5, 10, 16, 40))
    }

    // 공공데이터포털은 키 오류도 200 + XML 로 준다
    func testXMLErrorBodyThrows() {
        let data = Data("<OpenAPI_ServiceResponse><cmmMsgHeader><returnAuthMsg>SERVICE_KEY_IS_NOT_REGISTERED_ERROR</returnAuthMsg></cmmMsgHeader></OpenAPI_ServiceResponse>".utf8)
        XCTAssertThrowsError(try FlightStatusParser.parse(data, direction: .departure, day: at(2027, 5, 10), fetchedAt: at(2027, 5, 10), calendar: cal))
    }

    func testNonNormalResultCodeThrows() {
        XCTAssertThrowsError(try FlightStatusParser.parse(response(items: "[]", code: "99"), direction: .departure,
                                                          day: at(2027, 5, 10), fetchedAt: at(2027, 5, 10), calendar: cal))
    }

    // 15분 이상 늦거나 「지연」이면 지연 · 「결항」은 결항
    func testDelayAndCancelRules() throws {
        let late = response(items: #"[{"flightId":"KE725","scheduleDateTime":"1510","estimatedDateTime":"1525","remark":"출발"}]"#)
        XCTAssertTrue(try XCTUnwrap(FlightStatusParser.parse(late, direction: .departure, day: at(2027, 5, 10), fetchedAt: at(2027, 5, 10), calendar: cal).first).isDelayed)
        let slight = response(items: #"[{"flightId":"KE725","scheduleDateTime":"1510","estimatedDateTime":"1520","remark":"출발"}]"#)
        XCTAssertFalse(try XCTUnwrap(FlightStatusParser.parse(slight, direction: .departure, day: at(2027, 5, 10), fetchedAt: at(2027, 5, 10), calendar: cal).first).isDelayed)
        let cancelled = response(items: #"[{"flightId":"KE725","scheduleDateTime":"1510","remark":"결항"}]"#)
        XCTAssertTrue(try XCTUnwrap(FlightStatusParser.parse(cancelled, direction: .departure, day: at(2027, 5, 10), fetchedAt: at(2027, 5, 10), calendar: cal).first).isCancelled)
    }

    func testTerminalNames() {
        XCTAssertEqual(FlightStatusParser.terminal("P01"), "T1")
        XCTAssertEqual(FlightStatusParser.terminal("P02"), "탑승동")
        XCTAssertEqual(FlightStatusParser.terminal("P03"), "T2")
        XCTAssertNil(FlightStatusParser.terminal(""))
    }
}

final class FlightNumberTests: XCTestCase {
    func testNormalize() {
        XCTAssertEqual(FlightNumber.normalize("ke 725"), "KE725")
        XCTAssertEqual(FlightNumber.normalize("KE0725"), "KE725")
        XCTAssertEqual(FlightNumber.normalize("7c1301"), "7C1301")
        XCTAssertNil(FlightNumber.normalize("  "))
        XCTAssertNil(FlightNumber.normalize("KE"))
    }
}

final class TripFlightStatusPlannerTests: XCTestCase {
    private let cal = TravelTestClock.cal

    // 인천공항을 오가는 편만 · 그날(서울 시각)에만 물어본다
    func testOnlyTodaysIncheonFlightsAreAsked() {
        let plan = TripFlightStatusPlanner.plan(trip: TravelFixtures.osakaTrip(), today: at(2027, 5, 10, 10, 0), calendar: cal)
        XCTAssertEqual(plan.ask, [TripFlightQuery(bookingId: "f1", flightId: "KE725", direction: .departure, day: at(2027, 5, 10))])
        XCTAssertEqual(plan.later.map(\.bookingId), ["f2"])
        XCTAssertEqual(plan.later.first?.day, at(2027, 5, 14))
    }

    func testReturnFlightIsAskedAsArrivalOnItsDay() {
        let plan = TripFlightStatusPlanner.plan(trip: TravelFixtures.osakaTrip(), today: at(2027, 5, 14, 8, 0), calendar: cal)
        XCTAssertEqual(plan.ask, [TripFlightQuery(bookingId: "f2", flightId: "KE724", direction: .arrival, day: at(2027, 5, 14))])
    }

    func testFlightsWithoutNumberOrIncheonAreSkipped() {
        var noNumber = TravelFixtures.outbound()
        noNumber.flightNumber = nil
        var gimpo = TravelFixtures.inbound()
        gimpo.id = "f3"
        gimpo.toAirport = "GMP"
        let plan = TripFlightStatusPlanner.plan(trip: TravelFixtures.osakaTrip(bookings: [noNumber, gimpo]), today: at(2027, 5, 10, 10, 0), calendar: cal)
        XCTAssertEqual(plan.ask, [])
        XCTAssertEqual(plan.later.map(\.bookingId), [])
    }
}

/// 지도에 넘길 이름 — 한글 「간사이공항」은 애플 지도가 리무진 사무소를 잡는다(2026-11-05 실측) → 공항은 공식 이름으로.
final class TripRoutePlaceTests: XCTestCase {
    func testAirportNamesBecomeOfficialNames() {
        let trip = TravelFixtures.osakaTrip()
        XCTAssertEqual(TripRoutePlace.query(for: "간사이공항", trip: trip), "関西国際空港")
        XCTAssertEqual(TripRoutePlace.query(for: "간사이 국제공항", trip: trip), "関西国際空港")
        XCTAssertEqual(TripRoutePlace.query(for: "kix", trip: trip), "関西国際空港")
        XCTAssertEqual(TripRoutePlace.query(for: "인천공항", trip: trip), "인천국제공항")
    }

    // 「공항」만 적으면 그 여행에서 내리는 외국 공항
    func testBareAirportUsesTripsForeignAirport() {
        XCTAssertEqual(TripRoutePlace.query(for: "공항", trip: TravelFixtures.osakaTrip()), "関西国際空港")
    }

    // 숙소 이름을 적으면 그 숙소 주소로
    func testHotelNameUsesItsAddress() {
        XCTAssertEqual(TripRoutePlace.query(for: "교토 숙소", trip: kyotoTrip()), "京都市下京区東塩小路町")
    }

    func testOtherLabelsAreKeptAndBlankIsNil() {
        XCTAssertEqual(TripRoutePlace.query(for: " 교토역 ", trip: TravelFixtures.osakaTrip()), "교토역")
        XCTAssertNil(TripRoutePlace.query(for: "  ", trip: TravelFixtures.osakaTrip()))
    }

}

/// 가는 편이 늦으면 그날 뒤 일정에 무엇이 닿나(시안 Home-Flight 「늦어진 시간으로 다시 봤어요」).
final class TripDelayPlannerTests: XCTestCase {
    private let cal = TravelTestClock.cal
    private let delayed = departure(scheduled: at(2027, 5, 10, 15, 10), estimated: at(2027, 5, 10, 16, 40))
    /// 그 여행에서 지도에 물을 구간 전부에 같은 답을 준다.
    private func drive(_ minutes: Int?) -> [TripRouteKey: TripRouteAnswer] {
        guard let minutes else { return [:] }
        let route = RouteEstimate(minutes: minutes, fromName: nil, toName: nil, source: .google)
        let questions = Itinerary(trip: kyotoTrip(), rhythm: nil, calendar: cal).routeQuestions
        return Dictionary(uniqueKeysWithValues: questions.map { ($0, TripRouteAnswer.found(route)) })
    }

    func testDelayShiftsArrivalAndFlagsRentalPickup() throws {
        let o = TripDelayPlanner.outlook(trip: kyotoTrip(), flight: TravelFixtures.outbound(), status: delayed,
                                         routes: drive(nil), bedtimeMinute: nil, calendar: cal)
        XCTAssertEqual(o.arrival, at(2027, 5, 10, 18, 30))
        let rental = try XCTUnwrap(o.impacts.first { $0.kind == .rentalPickup })
        XCTAssertEqual(rental.title, "렌터카 인수 18:00")
        XCTAssertTrue(rental.detail.contains("18:30"), rental.detail)
    }

    // 숙소에 닿는 시각 = 늦어진 도착(또는 인수 시각 중 늦은 쪽) + 운전 시간 — 「빨라야」(입국·짐 찾기 시간은 모른다)
    func testHotelArrivalAddsDriveTime() throws {
        let o = TripDelayPlanner.outlook(trip: kyotoTrip(), flight: TravelFixtures.outbound(), status: delayed,
                                         routes: drive(92), bedtimeMinute: 20 * 60 + 10, calendar: cal)
        let hotel = try XCTUnwrap(o.impacts.first { $0.kind == .hotelArrival })
        XCTAssertTrue(hotel.detail.contains("1시간 32분"), hotel.detail)
        XCTAssertTrue(hotel.detail.contains("구글지도 기준"), hotel.detail)
        XCTAssertTrue(hotel.detail.contains("빨라야 20:02"), hotel.detail)
        XCTAssertFalse(o.impacts.contains { $0.kind == .bedtime }, "20:02 도착이면 20:10 밤잠 전")
    }

    func testBedtimeFlaggedWhenHotelArrivalIsAfterBedtime() throws {
        let o = TripDelayPlanner.outlook(trip: kyotoTrip(), flight: TravelFixtures.outbound(), status: delayed,
                                         routes: drive(120), bedtimeMinute: 20 * 60 + 10, calendar: cal)
        let bed = try XCTUnwrap(o.impacts.first { $0.kind == .bedtime })
        XCTAssertEqual(bed.title, "밤잠 20:10")
    }

    func testSmallDelayCancelledOrInboundHaveNoImpacts() {
        let small = departure(scheduled: at(2027, 5, 10, 15, 10), estimated: at(2027, 5, 10, 15, 20), remark: "출발")
        XCTAssertEqual(TripDelayPlanner.outlook(trip: kyotoTrip(), flight: TravelFixtures.outbound(), status: small,
                                                routes: drive(92), bedtimeMinute: nil, calendar: cal).impacts, [])
        let cancelled = departure(scheduled: at(2027, 5, 10, 15, 10), estimated: nil, remark: "결항")
        XCTAssertEqual(TripDelayPlanner.outlook(trip: kyotoTrip(), flight: TravelFixtures.outbound(), status: cancelled,
                                                routes: drive(92), bedtimeMinute: nil, calendar: cal).impacts, [])
        let inbound = FlightLiveStatus(flightId: "KE724", direction: .arrival, scheduled: at(2027, 5, 14, 14, 0),
                                       estimated: at(2027, 5, 14, 15, 30), remark: "지연", gate: nil, terminal: "T2",
                                       counterpart: nil, carousel: nil, exit: nil, fetchedAt: at(2027, 5, 14, 9, 0))
        XCTAssertEqual(TripDelayPlanner.outlook(trip: kyotoTrip(), flight: TravelFixtures.inbound(), status: inbound,
                                                routes: drive(92), bedtimeMinute: nil, calendar: cal).impacts, [])
    }

    func testDurationText() {
        XCTAssertEqual(TripDelayPlanner.durationText(92), "1시간 32분")
        XCTAssertEqual(TripDelayPlanner.durationText(60), "1시간")
        XCTAssertEqual(TripDelayPlanner.durationText(45), "45분")
    }
}

private final class MockFlightStatus: FlightStatusProviding, @unchecked Sendable {
    var result: FlightLiveStatus?
    var error: Error?
    var calls: [(String, FlightDirection)] = []

    func status(flightId: String, direction: FlightDirection, day: Date) async throws -> FlightLiveStatus? {
        calls.append((flightId, direction))
        if let error { throw error }
        return result
    }
}

private final class MockRouteTime: RouteTimeProviding, @unchecked Sendable {
    var minutes: Int? = 92
    var calls: [(from: String, to: String)] = []

    func drivingRoute(from: String, to: String, near area: TripRouteArea) async throws -> RouteEstimate {
        calls.append((from, to))
        guard let minutes else { throw RouteTimeError.notFound }
        return RouteEstimate(minutes: minutes, fromName: "关西国际机场", toName: "京都駅", source: .apple)
    }
}

@MainActor
final class TripLiveViewModelTests: XCTestCase {
    private func vm(trip: Trip = TravelFixtures.osakaTrip(), flight: MockFlightStatus = MockFlightStatus(),
                    route: MockRouteTime = MockRouteTime(), now: Date = at(2027, 5, 10, 9, 12)) -> TripDetailViewModel {
        TripDetailViewModel(trip: trip, ownerUserId: "o", currentUserId: "p",
                            babyBirthDate: at(2026, 8, 30), provider: MockTripFirestore(), childData: MockTripChildData(),
                            reminders: MockTripReminderScheduler(), flightStatus: flight, routeTime: route,
                            now: { now }, calendar: TravelTestClock.cal)
    }

    // 오늘 편은 물어보고, 다른 날 편은 「그날 보여요」로 둔다
    func testRefreshLoadsTodaysFlightAndMarksOthersLater() async {
        let flight = MockFlightStatus()
        flight.result = departure(scheduled: at(2027, 5, 10, 15, 10), estimated: at(2027, 5, 10, 16, 40))
        let model = vm(flight: flight)
        await model.refreshFlightStatus()
        XCTAssertEqual(flight.calls.map(\.0), ["KE725"])
        XCTAssertEqual(model.flightLive["f1"], .loaded(flight.result!))
        XCTAssertEqual(model.flightLive["f2"], .later(at(2027, 5, 14)))
        XCTAssertTrue(model.hasFlightToday)
    }

    func testRefreshFailureIsShownNotThrown() async {
        let flight = MockFlightStatus()
        flight.error = FlightStatusError.network
        let model = vm(flight: flight)
        await model.refreshFlightStatus()
        XCTAssertEqual(model.flightLive["f1"], .failed)
    }

    // 한 번 받은 정보는 다음 확인이 실패해도 지우지 않는다(지하·기내 모드에서 화면이 비지 않게)
    func testLaterFailureKeepsLastLoadedStatus() async {
        let flight = MockFlightStatus()
        flight.result = departure(scheduled: at(2027, 5, 10, 15, 10), estimated: at(2027, 5, 10, 16, 40))
        let model = vm(flight: flight)
        await model.refreshFlightStatus()
        flight.error = FlightStatusError.network
        await model.refreshFlightStatus()
        XCTAssertEqual(model.flightLive["f1"], .loaded(flight.result!))
    }

    func testFlightNotInTodaysListIsNotFound() async {
        let model = vm(flight: MockFlightStatus())
        await model.refreshFlightStatus()
        XCTAssertEqual(model.flightLive["f1"], .notFound)
    }

    // 같은 두 곳은 한 번만 계산한다 · 지도에는 고친 이름(공항 공식 이름)을 넘긴다
    func testDrivingRouteIsCachedPerPairAndUsesResolvedPlaces() async {
        let route = MockRouteTime()
        let model = vm(route: route)
        let first = await model.drivingRoute(from: "간사이공항", to: "교토역")
        let second = await model.drivingRoute(from: "간사이공항", to: "교토역")
        XCTAssertEqual(first?.minutes, 92)
        XCTAssertEqual(second?.minutes, 92)
        XCTAssertEqual(route.calls.count, 1)
        XCTAssertEqual(route.calls.first?.from, "関西国際空港")
        XCTAssertEqual(model.knownDrivingRoute(from: "간사이공항", to: "교토역")?.minutes, 92)
    }

    func testDrivingRouteNilWhenPlaceNotFound() async {
        let route = MockRouteTime()
        route.minutes = nil
        let model = vm(route: route)
        let result = await model.drivingRoute(from: "어딘가", to: "모르는 곳")
        XCTAssertNil(result)
    }

    // 늦어진 편을 받으면 일정표가 물어 둔 운전 시간으로 「빨라야 몇 시」를 낸다
    func testDelayedFlightUsesTheItinerarysDriveForTheOutlook() async throws {
        let flight = MockFlightStatus()
        flight.result = departure(scheduled: at(2027, 5, 10, 15, 10), estimated: at(2027, 5, 10, 16, 40))
        let route = MockRouteTime()
        let model = vm(trip: kyotoTrip(), flight: flight, route: route)
        await model.loadRoutes()
        await model.refreshFlightStatus()
        XCTAssertTrue(route.calls.contains { $0.to == "京都市下京区東塩小路町" })
        let outlook = try XCTUnwrap(model.delayOutlook(for: TravelFixtures.outbound()))
        let hotel = try XCTUnwrap(outlook.impacts.first { $0.kind == .hotelArrival })
        XCTAssertTrue(hotel.detail.contains("빨라야 20:02"), hotel.detail)
    }
}

// MARK: - 그림 확인 — 가는 날 아침, 가는 편이 1시간 30분 늦었다(시안 Home-Flight)

@MainActor
final class TravelLiveRenderTests: XCTestCase {
    private let dir = "/tmp/babycare_screenshots"

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

    func testDelayedFlightHomeAndBookingsRender() async throws {
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let flight = MockFlightStatus()
        flight.result = departure(scheduled: at(2027, 5, 10, 15, 10), estimated: at(2027, 5, 10, 16, 40))
        let childData = MockTripChildData()
        childData.activities = RhythmFixtures.week()
        let vm = TripDetailViewModel(trip: kyotoTrip(), ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: at(2026, 8, 30), provider: MockTripFirestore(), childData: childData,
                                     reminders: MockTripReminderScheduler(), flightStatus: flight, routeTime: MockRouteTime(),
                                     now: { at(2027, 5, 10, 9, 12) }, calendar: TravelTestClock.cal)
        await vm.loadChild()
        await vm.refreshFlightStatus()
        let home = try render(NavigationStack {
            TravelHomeView(vm: vm, trips: [vm.trip], onSelect: { _ in }, onCreate: {}, onDelete: { _ in },
                           onShowSchedule: { _ in }, onShowTasks: {}, onShowChild: {})
                .navigationBarTitleDisplayMode(.inline)
        }, height: 1700)
        try home.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/travel_home_flight.png"))
        let bookings = try render(NavigationStack {
            TravelList { TripBookingsSection(vm: vm, onEdit: { _ in }, onEditMove: { _ in }) }
                .navigationBarTitleDisplayMode(.inline)
        }, height: 1300)
        try bookings.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/travel_bookings_live.png"))
        XCTAssertGreaterThan(home.size.height, 0)
    }
}

// MARK: - 여행 중계 서버(v2.8.13 · PO 2026-11-08 「다 추가해서 여행기능 오픈」) — 지도·공항 키는 서버에만, 앱은 로그인 토큰만 보낸다

private struct NoLogin: Error {}

private final class StubRoute: RouteTimeProviding, @unchecked Sendable {
    let result: Result<RouteEstimate, Error>
    private(set) var calls = 0
    init(_ result: Result<RouteEstimate, Error>) { self.result = result }
    func drivingRoute(from: String, to: String, near area: TripRouteArea) async throws -> RouteEstimate {
        calls += 1
        return try result.get()
    }
}

final class TravelServerTests: XCTestCase {
    private let area = TripRouteArea(city: "교토", countryCode: "JP")

    // 앱 안에 키 파일이 실리면 누구나 꺼낸다 — 손님 판에는 없어야 한다
    func testAppShipsNoTravelKeyFile() {
        XCTAssertNil(Bundle.main.url(forResource: "TravelKeys", withExtension: "plist"))
    }

    func testFlightScheduleAsksOurServerWithLoginTokenAndNoKey() throws {
        let request = try XCTUnwrap(IncheonFlightScheduleService.request("getPaxFltSchedDepartures", token: "tok-1"))
        XCTAssertEqual(request.url?.absoluteString,
                       "https://babycare-travel.roafinance.workers.dev/airport/PaxFltSched/getPaxFltSchedDepartures?type=json&numOfRows=9999&pageNo=1")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok-1")
    }

    func testFlightStatusAsksOurServerByFlightNumber() throws {
        let request = try XCTUnwrap(IncheonFlightStatusService.request(path: "getPassengerArrivalsOdp", flightId: "KE999", token: "tok-1"))
        XCTAssertEqual(request.url?.absoluteString,
                       "https://babycare-travel.roafinance.workers.dev/airport/StatusOfPassengerFlightsOdp/getPassengerArrivalsOdp?type=json&flight_id=KE999")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok-1")
    }

    func testRouteTimeAsksOurServerWithSameBodyAndNoGoogleKey() throws {
        let request = try GoogleRoutesTimeService.request(from: "関西国際空港", to: "京都駅", area: area, token: "tok-1")
        XCTAssertEqual(request.url?.absoluteString, "https://babycare-travel.roafinance.workers.dev/routes")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok-1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Goog-Api-Key"))
        let body = try XCTUnwrap(try request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        XCTAssertEqual((body["origin"] as? [String: String])?["address"], "関西国際空港")
        XCTAssertEqual((body["destination"] as? [String: String])?["address"], "京都駅")
        XCTAssertEqual(body["travelMode"] as? String, "DRIVE")
        XCTAssertEqual(body["regionCode"] as? String, "jp")
    }

    // 로그인 토큰을 못 받으면 서버에 묻지 않고 그 자리에서 멈춘다(네트워크 오류로 보이지 않게)
    func testFlightScheduleWithoutLoginStopsBeforeAsking() async {
        do {
            _ = try await IncheonFlightScheduleService(token: { throw NoLogin() }).rows()
            XCTFail("로그인 없이 시간표를 받으면 안 된다")
        } catch {
            XCTAssertEqual(error as? FlightStatusError, .notSignedIn)
        }
    }

    func testFlightStatusWithoutLoginStopsBeforeAsking() async {
        do {
            _ = try await IncheonFlightStatusService(token: { throw NoLogin() })
                .status(flightId: "KE999", direction: .departure, day: TravelTestClock.at(2027, 5, 10))
            XCTFail("로그인 없이 운항 현황을 받으면 안 된다")
        } catch {
            XCTAssertEqual(error as? FlightStatusError, .notSignedIn)
        }
    }

    func testRouteTimeWithoutLoginFails() async {
        do {
            _ = try await GoogleRoutesTimeService(token: { throw NoLogin() }).drivingRoute(from: "A", to: "B", near: area)
            XCTFail("로그인 없이 이동 시간을 받으면 안 된다")
        } catch {
            XCTAssertEqual(error as? RouteTimeError, .failed("로그인"))
        }
    }

    // 서버가 안 되면 애플 지도로 — 이동 시간이 통째로 비지 않게. 길이 없다는 답(notFound)은 그대로 둔다.
    func testRouteFallsBackToAppleMapsWhenServerFails() async throws {
        let google = StubRoute(.failure(RouteTimeError.failed("HTTP 503")))
        let apple = StubRoute(.success(RouteEstimate(minutes: 70, fromName: "A", toName: "B", source: .apple)))
        let route = try await FallbackRouteTimeService(primary: google, fallback: apple).drivingRoute(from: "A", to: "B", near: area)
        XCTAssertEqual(route.source, .apple)
        XCTAssertEqual(route.minutes, 70)
        XCTAssertEqual(apple.calls, 1)
    }

    func testRouteNotFoundIsNotRetriedOnAppleMaps() async {
        let google = StubRoute(.failure(RouteTimeError.notFound))
        let apple = StubRoute(.success(RouteEstimate(minutes: 70, fromName: nil, toName: nil, source: .apple)))
        do {
            _ = try await FallbackRouteTimeService(primary: google, fallback: apple).drivingRoute(from: "A", to: "B", near: area)
            XCTFail("길이 없다는 답은 그대로 와야 한다")
        } catch {
            XCTAssertEqual(error as? RouteTimeError, .notFound)
            XCTAssertEqual(apple.calls, 0)
        }
    }

    func testRouteUsesGoogleWhenServerAnswers() async throws {
        let google = StubRoute(.success(RouteEstimate(minutes: 81, fromName: nil, toName: nil, source: .google)))
        let apple = StubRoute(.success(RouteEstimate(minutes: 70, fromName: nil, toName: nil, source: .apple)))
        let route = try await FallbackRouteTimeService(primary: google, fallback: apple).drivingRoute(from: "A", to: "B", near: area)
        XCTAssertEqual(route.source, .google)
        XCTAssertEqual(route.minutes, 81)
        XCTAssertEqual(apple.calls, 0)
    }
}
