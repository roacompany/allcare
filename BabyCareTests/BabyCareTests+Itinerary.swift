import XCTest
@testable import BabyCare

/// 일시 저장 — 옛 문서가 그대로 읽히고, 시각 미정이 시각으로 둔갑하지 않는다.
final class TripWhenStorageTests: XCTestCase {
    /// 옛 빌드가 아는 칸만 가진 모양.
    private struct OldBuildBooking: Decodable {
        let id: String
        let departAt: Date?
        let arriveAt: Date?
    }

    func testOldDocumentTimeIsKnownTime() throws {
        let json = #"{"id":"f1","kind":"flight","departAt":815000000}"#
        let booking = try JSONDecoder().decode(TripBooking.self, from: Data(json.utf8))
        XCTAssertEqual(booking.depart, .at(Date(timeIntervalSinceReferenceDate: 815_000_000)))
        XCTAssertNil(booking.arrive)
    }

    func testDateOnlyRoundTripsWithoutATime() throws {
        var booking = TripBooking(id: "h1", kind: .hotel)
        booking.checkOut = .day("2027-05-14")
        let data = try JSONEncoder().encode(booking)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["checkOutAt"], "시각 칸에 아무것도 안 쓴다")
        XCTAssertEqual(try JSONDecoder().decode(TripBooking.self, from: data).checkOut, .day("2027-05-14"))
    }

    func testSettingATimeClearsTheDateOnlyValue() {
        var booking = TripBooking(id: "c1", kind: .rentalCar)
        booking.pickup = .day("2027-05-10")
        let time = TravelTestClock.at(2027, 5, 10, 18, 0)
        booking.pickup = .at(time)
        XCTAssertEqual(booking.pickup, .at(time))
        booking.pickup = nil
        XCTAssertNil(booking.pickup)
    }

    // 옛 빌드가 새 문서를 읽어도 여행 문서가 버려지면 안 된다.
    func testOldBuildCanStillReadDateOnlyBooking() throws {
        var booking = TripBooking(id: "f2", kind: .flight, depart: .at(TravelTestClock.at(2027, 5, 14, 11, 55)))
        booking.arrive = .day("2027-05-14")
        let old = try JSONDecoder().decode(OldBuildBooking.self, from: JSONEncoder().encode(booking))
        XCTAssertNotNil(old.departAt)
        XCTAssertNil(old.arriveAt)
    }

    // 날짜 글자가 깨져도 예약이 사라지지 않는다(decodeKeyed 는 예약 하나가 실패하면 여행 전체를 잃는다).
    func testBrokenDayTextReadsAsMissing() throws {
        let json = #"{"id":"h1","kind":"hotel","checkInDay":"언젠가"}"#
        let booking = try JSONDecoder().decode(TripBooking.self, from: Data(json.utf8))
        XCTAssertNil(booking.checkIn)
    }

    // 무료 취소 「3일 전」 — 기준이 날짜만이면 기한도 날짜만이다(00:00 으로 둔갑하면 안 된다).
    func testDaysBeforeKeepsTheSameKnowledge() {
        let cal = TravelTestClock.cal
        XCTAssertEqual(TripWhen.day("2027-05-10").daysBefore(3, calendar: cal), .day("2027-05-07"))
        XCTAssertEqual(TripWhen.at(TravelTestClock.at(2027, 5, 10, 15, 0)).daysBefore(3, calendar: cal), .at(TravelTestClock.at(2027, 5, 7, 15, 0)))
    }

    func testChangingTheDayKeepsTheTimeOrItsAbsence() {
        let cal = TravelTestClock.cal
        let day = TravelTestClock.at(2027, 5, 12)
        XCTAssertEqual(TripWhen.day("2027-05-10").movedTo(day, calendar: cal), .day("2027-05-12"))
        XCTAssertEqual(TripWhen.at(TravelTestClock.at(2027, 5, 10, 15, 30)).movedTo(day, calendar: cal), .at(TravelTestClock.at(2027, 5, 12, 15, 30)))
    }

    func testDayKeyComesFromEitherForm() {
        let cal = TravelTestClock.cal
        XCTAssertEqual(TripWhen.at(TravelTestClock.at(2027, 5, 10, 15, 10)).dayKey(cal), "2027-05-10")
        XCTAssertEqual(TripWhen.day("2027-05-14").dayKey(cal), "2027-05-14")
    }
}

/// 시험 여행 — 편명·숙소 이름은 지어낸 값(저장소가 공개다).
enum ItineraryFixture {
    static func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> TripWhen {
        .at(TravelTestClock.at(2027, 5, day, hour, minute))
    }

    static func on(_ day: Int) -> TripWhen {
        .day(String(format: "2027-05-%02d", day))
    }

    static var outbound: TripBooking {
        var b = TripBooking(id: "f1", kind: .flight, airline: "KE", flightNumber: "KE999", fromAirport: "ICN", toAirport: "KIX")
        b.depart = at(10, 15, 10)
        b.arrive = at(10, 17)
        return b
    }

    static var inbound: TripBooking {
        var b = TripBooking(id: "f2", kind: .flight, airline: "KE", flightNumber: "KE998", fromAirport: "KIX", toAirport: "ICN")
        b.depart = at(14, 11, 55)
        b.arrive = at(14, 14)
        return b
    }

    static var car: TripBooking {
        var b = TripBooking(id: "c1", kind: .rentalCar, company: "시험 렌터카", pickupPlace: "간사이공항", returnPlace: "간사이공항")
        b.pickup = at(10, 18)
        b.carReturn = at(14, 10)
        return b
    }

    static var kyoto: TripBooking {
        var b = TripBooking(id: "h1", kind: .hotel, name: "교토 숙소", checkInUntilMinute: 22 * 60)
        b.checkIn = at(10, 15)
        b.checkOut = at(12, 10)
        return b
    }

    static var osaka: TripBooking {
        var b = TripBooking(id: "h2", kind: .hotel, name: "오사카 숙소")
        b.checkIn = at(12, 15)
        b.checkOut = on(14)
        return b
    }

    static func trip(_ bookings: [TripBooking]? = nil, moves: [TripMove] = []) -> Trip {
        Trip(id: "t1", babyId: "b1", countryCode: "JP", city: "오사카·교토", startDay: "2027-05-10", endDay: "2027-05-14",
             bookings: bookings ?? [osaka, inbound, kyoto, car, outbound], moves: moves)
    }

    /// 구글 경로로 잰 값(11/6).
    static func routes(in trip: Trip) -> [TripRouteKey: TripRouteAnswer] {
        func key(_ from: String, _ to: String) -> TripRouteKey {
            TripRouteKey(from: TripRoutePlace.query(for: from, trip: trip) ?? from, to: TripRoutePlace.query(for: to, trip: trip) ?? to)
        }
        func found(_ minutes: Int) -> TripRouteAnswer {
            .found(RouteEstimate(minutes: minutes, fromName: nil, toName: nil, source: .google))
        }
        return [key("간사이공항", "교토 숙소"): found(96), key("교토 숙소", "오사카 숙소"): found(66), key("오사카 숙소", "간사이공항"): found(44)]
    }

    static func plan(_ trip: Trip = trip(), rhythm: BabyRhythm? = nil, routes: [TripRouteKey: TripRouteAnswer]? = nil) -> Itinerary {
        Itinerary(trip: trip, rhythm: rhythm, routes: routes ?? ItineraryFixture.routes(in: trip), calendar: TravelTestClock.cal)
    }

    /// 손님이 읽는 차례대로 — 「19:36 빨라야 교토 숙소 도착」.
    static func text(_ plan: Itinerary, day number: Int) -> [String] {
        plan.days[number - 1].lines.map { line in
            [line.clock, line.clockNote ?? "", line.title].filter { !$0.isEmpty }.joined(separator: " ")
        }
    }
}

/// 일정표 — 실제로 넣은 여행이 사람이 움직이는 순서로 나오나.
final class ItineraryDayTests: XCTestCase {
    private typealias F = ItineraryFixture

    func testFirstDayFollowsTheWayPeopleTravel() {
        XCTAssertEqual(F.text(F.plan(), day: 1), [
            "15:10 인천 출발 KE999",
            "17:00 간사이 도착, 입국",
            "18:00 렌터카 인수",
            "교토 숙소까지 차로 약 1시간 36분, 구글지도 기준",
            "19:36 빨라야 교토 숙소 도착"
        ])
    }

    func testCheckInStartNeverComesBeforeTheFlight() {
        var hotel = F.kyoto
        hotel.checkIn = F.at(10, 14)
        let lines = F.text(F.plan(F.trip([F.outbound, F.car, hotel])), day: 1)
        XCTAssertEqual(lines.first, "15:10 인천 출발 KE999")
        XCTAssertEqual(lines.last, "19:36 빨라야 교토 숙소 도착")
    }

    func testDayBetweenStaysShowsWhereWeSleep() {
        let plan = F.plan()
        XCTAssertEqual(plan.days.map(\.tonight), ["교토 숙소", "교토 숙소", "오사카 숙소", "오사카 숙소", nil])
        XCTAssertEqual(F.text(plan, day: 2), [])
    }

    func testMovingDayGoesCheckOutThenDriveThenCheckIn() {
        XCTAssertEqual(F.text(F.plan(), day: 3), [
            "10:00 까지 교토 숙소 체크아웃",
            "오사카 숙소까지 차로 약 1시간 6분, 구글지도 기준",
            "15:00 부터 오사카 숙소 체크인"
        ])
    }

    func testReturnDayWorksBackFromTheCarReturn() {
        XCTAssertEqual(F.text(F.plan(), day: 5), [
            "미정 오사카 숙소 체크아웃",
            "09:16 늦어도 간사이공항까지 차로 약 44분, 구글지도 기준",
            "10:00 렌터카 반납",
            "11:55 간사이 출발 KE998",
            "14:00 인천 도착"
        ])
    }
}

/// 일정표 — 모르는 시각은 비워 두고, 앞뒤가 안 맞으면 그 줄에서 말한다.
final class ItineraryOpenTimeTests: XCTestCase {
    private typealias F = ItineraryFixture

    private func line(_ plan: Itinerary, day: Int, _ title: String) -> Itinerary.Line? {
        plan.days[day - 1].lines.first { $0.title.contains(title) }
    }

    // 🩸 오는 편 출발이 00:00 으로 나왔다(빌드 113).
    func testUnknownDepartureStaysInItsPlaceWithoutATime() {
        var back = F.inbound
        back.depart = F.on(14)
        let plan = F.plan(F.trip([F.outbound, back, F.car, F.kyoto, F.osaka]))
        XCTAssertEqual(F.text(plan, day: 5), [
            "미정 오사카 숙소 체크아웃",
            "09:16 늦어도 간사이공항까지 차로 약 44분, 구글지도 기준",
            "10:00 렌터카 반납",
            "미정 간사이 출발 KE998",
            "14:00 인천 도착"
        ])
        XCTAssertEqual(line(plan, day: 5, "간사이 출발")?.needsTime, true)
        XCTAssertEqual(line(plan, day: 5, "간사이 출발")?.target, .booking("f2"))
    }

    // 🩸 도착을 비우면 간사이 도착 줄이 사라지고 가는 편이 「다른 날 예약」으로 빠졌다(빌드 113).
    func testUnknownArrivalKeepsTheFlightOnItsDay() {
        var out = F.outbound
        out.arrive = nil
        let plan = F.plan(F.trip([out, F.car, F.kyoto]))
        XCTAssertEqual(F.text(plan, day: 1), [
            "15:10 인천 출발 KE999",
            "미정 간사이 도착, 입국",
            "18:00 렌터카 인수",
            "교토 숙소까지 차로 약 1시간 36분, 구글지도 기준",
            "19:36 빨라야 교토 숙소 도착"
        ])
        XCTAssertEqual(line(plan, day: 1, "인천 출발")?.detail, "간사이 도착 시각 미정")
    }

    func testArrivalTimeAloneStillShowsTheDeparture() {
        var back = F.inbound
        back.depart = nil
        XCTAssertEqual(F.text(F.plan(F.trip([back])), day: 5), ["미정 간사이 출발 KE998", "14:00 인천 도착"])
    }

    func testOpenLinesFollowTheOrderOfTheDay() {
        var car = F.car
        car.pickup = F.on(10)
        var hotel = F.kyoto
        hotel.checkIn = F.on(10)
        hotel.checkInUntilMinute = nil
        var out = F.outbound
        out.arrive = nil
        let plan = F.plan(F.trip([hotel, car, out]))
        XCTAssertEqual(F.text(plan, day: 1), [
            "15:10 인천 출발 KE999",
            "미정 간사이 도착, 입국",
            "미정 렌터카 인수",
            "교토 숙소까지 차로 약 1시간 36분, 구글지도 기준",
            "교토 숙소 체크인"
        ])
    }

    func testDetailsNameWhatPeopleNeed() {
        let plan = F.plan()
        XCTAssertEqual(line(plan, day: 1, "인천 출발")?.detail, "17:00 간사이 도착")
        XCTAssertEqual(line(plan, day: 1, "간사이 도착")?.detail, "고기 든 음식이 남았으면 자진폐기함에")
        XCTAssertEqual(line(plan, day: 1, "렌터카 인수")?.detail, "간사이공항, 카시트 확인")
        XCTAssertEqual(line(plan, day: 1, "교토 숙소 도착")?.detail, "체크인 15:00~22:00")
        XCTAssertEqual(line(plan, day: 5, "인천 도착")?.detail, "KE998")
    }

    // 지도 답이 없어도 일정은 나온다 · 줄 수는 그대로다.
    func testWaitingForTheMapKeepsEveryLine() {
        let waiting = F.plan(routes: [:])
        XCTAssertEqual(F.text(waiting, day: 1), [
            "15:10 인천 출발 KE999",
            "17:00 간사이 도착, 입국",
            "18:00 렌터카 인수",
            "교토 숙소까지 이동",
            "교토 숙소 체크인"
        ])
        XCTAssertEqual(line(waiting, day: 1, "까지 이동")?.detail, "소요 시간 계산 중")
        XCTAssertEqual(line(waiting, day: 1, "교토 숙소 체크인")?.detail, "체크인 15:00~22:00")
    }

    func testMapThatCannotFindTheRouteSaysSo() {
        let trip = F.trip()
        let answers = F.routes(in: trip).mapValues { _ in TripRouteAnswer.notFound }
        XCTAssertEqual(line(F.plan(trip, routes: answers), day: 1, "까지 이동")?.detail, "지도에서 길을 찾지 못했어요")
    }

    func testArrivingAfterTheCheckInDeadlineIsMarkedOnTheStay() {
        var hotel = F.kyoto
        hotel.checkInUntilMinute = 19 * 60
        let plan = F.plan(F.trip([F.outbound, F.car, hotel]))
        XCTAssertEqual(line(plan, day: 1, "교토 숙소 도착")?.alert, "체크인 마감 19:00을 넘겨요")
        XCTAssertTrue(plan.days[0].needsAttention)
    }

    func testDeadlineAfterMidnightIsTheNextDay() {
        var hotel = F.kyoto
        hotel.checkInUntilMinute = 60
        XCTAssertNil(line(F.plan(F.trip([F.outbound, F.car, hotel])), day: 1, "교토 숙소 도착")?.alert)
    }

    // 🩸 옛 빌드가 넣은 렌터카 14:00 은 지어낸 값인지 모른다 — 있는 대로 믿되 그 줄에서 말한다.
    func testPickupBeforeLandingIsMarked() {
        var car = F.car
        car.pickup = F.at(10, 14)
        XCTAssertEqual(line(F.plan(F.trip([F.outbound, car])), day: 1, "렌터카 인수")?.alert, "비행기 도착 17:00보다 빨라요")
    }

    // 🩸 옛 빌드의 오는 편 00:00.
    func testReturnAfterTakeoffIsMarked() {
        var back = F.inbound
        back.depart = F.at(14, 0)
        XCTAssertEqual(line(F.plan(F.trip([back, F.car])), day: 5, "렌터카 반납")?.alert, "비행기 출발 00:00보다 늦어요")
    }

    func testDriveThatCannotReachTheNextAppointmentIsMarked() {
        var car = F.car
        car.pickupPlace = "교토 숙소"
        let plan = F.plan(F.trip([F.outbound, car]))
        XCTAssertEqual(line(plan, day: 1, "렌터카 인수")?.alert, "이동하면 빨라야 18:36에 닿아요")
    }

    func testPersonsOwnMoveReplacesTheFoundDrive() {
        let move = TripMove(id: "m1", startAt: TravelTestClock.at(2027, 5, 10, 18, 30), minutes: 90, fromLabel: "간사이공항", toLabel: "교토 숙소")
        let plan = F.plan(F.trip(moves: [move]))
        XCTAssertEqual(F.text(plan, day: 1), [
            "15:10 인천 출발 KE999",
            "17:00 간사이 도착, 입국",
            "18:00 렌터카 인수",
            "18:30 간사이공항 → 교토 숙소",
            "20:00 빨라야 교토 숙소 도착"
        ])
        XCTAssertEqual(line(plan, day: 1, "간사이공항 → 교토 숙소")?.target, .move("m1"))
    }

    // 🩸 도착이 비어 있으면 옛 렌터카 14:00 이 출발보다 앞에 말없이 놓였다.
    func testPickupBeforeTakeoffIsMarkedEvenWithoutAnArrivalTime() {
        var out = F.outbound
        out.arrive = nil
        var car = F.car
        car.pickup = F.at(10, 14)
        XCTAssertEqual(line(F.plan(F.trip([out, car])), day: 1, "렌터카 인수")?.alert, "비행기 출발 15:10보다 빨라요")
    }

    // 영문 숙소 이름이 대문자로 둔갑하면 안 된다(공항 이름 찾기가 모르는 값을 대문자로 돌려준다).
    func testPlaceNamesStayAsPeopleWroteThem() {
        var hotel = F.kyoto
        hotel.name = "Hotel Kyoto"
        let plan = F.plan(F.trip([F.outbound, F.car, hotel]), routes: [:])
        XCTAssertEqual(line(plan, day: 1, "까지 이동")?.title, "Hotel Kyoto까지 이동")
    }

    func testAirportLinesCarryTheNursingRoomCode() {
        let plan = F.plan()
        XCTAssertEqual(line(plan, day: 1, "인천 출발")?.airportCode, "ICN")
        XCTAssertEqual(line(plan, day: 5, "인천 도착")?.airportCode, "ICN")
        XCTAssertEqual(line(plan, day: 1, "간사이 도착")?.rule, .solidsQuarantine)
    }

    func testRouteLineKnowsWhereToOpenTheMap() {
        XCTAssertEqual(line(F.plan(), day: 1, "까지 차로")?.route?.to, "교토 숙소")
    }

    // 🩸 리뷰(11/6): 도착이 미정이면 자기 출발보다 앞에 놓일 수 있었다 — 시각 없는 편은 짝 옆에 둔다.
    func testOpenArrivalStaysRightAfterItsOwnDeparture() {
        var out = F.outbound
        out.arrive = nil
        var car = F.car
        car.pickup = F.at(10, 14)
        let lines = F.text(F.plan(F.trip([out, car])), day: 1)
        XCTAssertEqual(lines, ["14:00 렌터카 인수", "15:10 인천 출발 KE999", "미정 간사이 도착, 입국"])
    }

    func testOpenDepartureStaysRightBeforeItsOwnArrivalAroundAPersonsMove() {
        var back = F.inbound
        back.depart = F.on(14)
        let move = TripMove(id: "m1", startAt: TravelTestClock.at(2027, 5, 14, 8), minutes: 30, fromLabel: "오사카 숙소", toLabel: "간사이공항")
        XCTAssertEqual(F.text(F.plan(F.trip([back], moves: [move])), day: 5), ["08:00 오사카 숙소 → 간사이공항", "미정 간사이 출발 KE998", "14:00 인천 도착"])
    }

    // 한국 공항으로 차로 가는 길은 없다 — 옛 렌터카 14:00 이 만들던 유령 이동.
    func testNoDriveIsFoundToAHomeAirport() {
        var car = F.car
        car.pickup = F.at(10, 14)
        XCTAssertFalse(F.text(F.plan(F.trip([F.outbound, car]), routes: [:]), day: 1).contains { $0.contains("인천") && $0.contains("까지") })
    }

    // 🩸 옛 빌드의 오는 편 00:00 — 앞뒤 비교로 안 드러나는 경우(반납도 00:00 · 렌터카 없음)도 그 줄에서 묻는다.
    func testMidnightFlightAsksIfThatIsRight() {
        var back = F.inbound
        back.depart = F.at(14, 0)
        let plan = F.plan(F.trip([back]))
        XCTAssertEqual(line(plan, day: 5, "간사이 출발")?.alert, "00:00 출발이 맞나요?")
        XCTAssertTrue(plan.days[4].needsAttention)
    }

    func testMidnightCarReturnAsksToo() {
        var car = F.car
        car.carReturn = F.at(14, 0)
        XCTAssertEqual(line(F.plan(F.trip([car])), day: 5, "렌터카 반납")?.alert, "00:00 반납이 맞나요?")
    }

    // 밤 비행 — 비행 중에 숙소에 닿을 수는 없다.
    func testOvernightFlightCountsFromLanding() {
        var out = F.outbound
        out.depart = F.at(10, 23)
        out.arrive = F.at(11, 1, 30)
        var hotel = F.kyoto
        hotel.checkIn = F.at(10, 15)
        let lines = F.text(F.plan(F.trip([out, hotel])), day: 1)
        XCTAssertEqual(lines.last, "03:06 빨라야 교토 숙소 도착")
    }

    func testOvernightFlightStaysOnTheGoingDay() {
        var out = F.outbound
        out.depart = F.at(10, 23)
        out.arrive = F.at(11, 1, 30)
        let plan = F.plan(F.trip([out, F.inbound]))
        XCTAssertEqual(plan.bookings.dayOne.map(\.title), ["인천공항 출발"])
        XCTAssertEqual(plan.bookings.dayOne.first?.details, ["가는 편 KE999, 5.11(화) 01:30 간사이 도착"])
        XCTAssertEqual(plan.bookings.otherDays.map(\.booking.id), ["f2"])
    }

    // 지도 답이 없어도 이미 늦은 것은 말한다.
    func testLandingAfterTheCheckInDeadlineIsMarkedWithoutTheMap() {
        var out = F.outbound
        out.depart = F.at(10, 21)
        out.arrive = F.at(10, 23, 30)
        let plan = F.plan(F.trip([out, F.kyoto]), routes: [:])
        XCTAssertEqual(line(plan, day: 1, "교토 숙소 체크인")?.alert, "체크인 마감 22:00을 넘겨요")
    }

    func testEarlyMorningDeadlineIsTheNextDayEvenWithoutAStartTime() {
        var hotel = F.kyoto
        hotel.checkIn = F.on(10)
        hotel.checkInUntilMinute = 60
        XCTAssertNil(line(F.plan(F.trip([F.outbound, F.car, hotel])), day: 1, "교토 숙소 도착")?.alert)
    }

    func testFlightWithoutAirportsStillReads() {
        var flight = TripBooking(id: "f9", kind: .flight, airline: "KE", flightNumber: "KE123")
        flight.depart = F.at(11, 9)
        let plan = F.plan(F.trip([flight]))
        XCTAssertEqual(F.text(plan, day: 2), ["09:00 KE123 출발", "미정 KE123 도착"])
        XCTAssertEqual(plan.days[1].homeLines.first?.title, "KE123")
    }

    // 「그 줄에서 바로 넣는다」 — 앞 약속이 있는 날의 체크인도.
    func testStayWithoutAnyCheckInTimeOffersToFillIt() {
        var hotel = F.kyoto
        hotel.checkIn = F.on(10)
        hotel.checkInUntilMinute = nil
        let plan = F.plan(F.trip([F.outbound, F.car, hotel]))
        XCTAssertEqual(line(plan, day: 1, "교토 숙소 도착")?.needsTime, true)
        XCTAssertEqual(line(plan, day: 1, "교토 숙소 도착")?.detail, "체크인 시각 미정")
    }

    // 애플 지도가 어디를 찾았는지 보여 준다(맞게 찾았나 사람이 본다).
    func testMapShowsWhatItFoundWhenItTells() {
        let trip = F.trip()
        var routes = F.routes(in: trip)
        let key = TripRouteKey(from: "関西国際空港", to: "교토 숙소")
        routes[key] = .found(RouteEstimate(minutes: 96, fromName: "간사이공항", toName: "교토역", source: .apple))
        XCTAssertEqual(line(F.plan(trip, routes: routes), day: 1, "까지 차로")?.detail, "지도가 찾은 곳: 간사이공항 → 교토역")
    }

    func testDaysNameThemselves() {
        XCTAssertEqual(F.plan().days.map(\.title), ["출발하는 날", "여행 2일째", "여행 3일째", "여행 4일째", "돌아오는 날"])
    }

    func testOpenTimesAreMarkedForEveryScreen() {
        var out = F.outbound
        out.arrive = nil
        let plan = F.plan(F.trip([out, F.inbound, F.car, F.kyoto, F.osaka]))
        XCTAssertEqual(plan.bookings.dayOne.first?.isOpen, true)
        XCTAssertEqual(plan.days[4].homeLines.first?.isOpen, true)
        XCTAssertEqual(plan.days[0].homeLines.first?.isOpen, false)
    }

    func testOnlyDaysWithSomethingToFixNeedAttention() {
        XCTAssertEqual(F.plan().days.map(\.needsAttention), [false, false, false, false, true])
    }
}

/// 일정표 — 아기 리듬 위에 비행과 운전을 놓는다(시안 일정 판).
final class ItineraryBabyTests: XCTestCase {
    private typealias F = ItineraryFixture

    private static func block(_ start: Int, _ minutes: Int, _ days: Double) -> BabyRhythm.Block {
        BabyRhythm.Block(startMinute: start, minutes: minutes, share: days / 7)
    }

    private let rhythm = BabyRhythm(naps: [block(9 * 60 + 40, 70, 7), block(14 * 60 + 10, 80, 6)],
                                    bedtimeMinute: 20 * 60 + 10, wakeMinute: 6 * 60 + 50, dayFeedIntervalMin: 230,
                                    solids: [block(8 * 60 + 10, 0, 7), block(17 * 60 + 40, 0, 7)],
                                    carSeatNaps: 2, daysWithRecords: 7, meat: .absent, hasSolids: true)

    private func line(_ plan: Itinerary, day: Int, clock: String) -> Itinerary.Line? {
        plan.days[day - 1].lines.first { $0.clock == clock }
    }

    func testFirstDayPutsTheBabyBetweenTheTravel() {
        XCTAssertEqual(F.text(F.plan(rhythm: rhythm), day: 1), [
            "06:50 수유",
            "08:10 이유식",
            "09:40 낮잠 약 70분",
            "10:50 수유",
            "14:10 낮잠 약 80분",
            "15:10 인천 출발 KE999",
            "15:30 수유",
            "17:00 간사이 도착, 입국",
            "17:40 이유식",
            "18:00 렌터카 인수",
            "교토 숙소까지 차로 약 1시간 36분, 구글지도 기준",
            "19:20 수유",
            "19:36 빨라야 교토 숙소 도착",
            "20:10 밤잠"
        ])
    }

    func testBabyLinesSayWhyTheyAreThere() {
        let plan = F.plan(rhythm: rhythm)
        XCTAssertEqual(line(plan, day: 1, clock: "06:50")?.detail, "깬 뒤 바로, 이후 약 3시간 50분마다")
        XCTAssertEqual(line(plan, day: 1, clock: "08:10")?.detail, "7일 모두 이 시간쯤 먹었어요")
        XCTAssertEqual(line(plan, day: 1, clock: "09:40")?.detail, "최근 7일 동안 매일 이 시간쯤 잤어요")
        XCTAssertEqual(line(plan, day: 1, clock: "10:50")?.detail, "낮잠에서 깬 뒤로 잡았어요")
        XCTAssertEqual(line(plan, day: 2, clock: "14:10")?.detail, "7일 중 6일 이 시간쯤 잤어요")
    }

    func testTravelThatTouchesTheBabyIsSaid() {
        let plan = F.plan(rhythm: rhythm)
        XCTAssertEqual(line(plan, day: 1, clock: "14:10")?.detail, "7일 중 6일, 탑승 시간과 겹쳐요")
        XCTAssertEqual(line(plan, day: 1, clock: "15:30")?.detail, "비행 중이에요")
        XCTAssertEqual(line(plan, day: 1, clock: "19:20")?.detail, "운전 중이에요", "앱이 찾은 운전도 구간에 든다")
        XCTAssertEqual(line(plan, day: 5, clock: "09:40")?.detail, "최근 7일 동안 매일, 운전 시간과 겹쳐요", "반납 앞 운전도 구간에 든다")
    }

    func testFeedingAtTheAirportLinksItsNursingRoom() {
        let plan = F.plan(rhythm: rhythm)
        XCTAssertEqual(line(plan, day: 1, clock: "17:40")?.detail, "7일 모두 이 시간쯤, 간사이공항에 있을 때예요")
        XCTAssertEqual(line(plan, day: 1, clock: "17:40")?.airportCode, "KIX")
        XCTAssertEqual(line(plan, day: 5, clock: "10:50")?.airportCode, "KIX")
        XCTAssertNil(line(plan, day: 2, clock: "17:40")?.airportCode)
    }

    func testBedtimeSaysTheStayComesFirst() {
        XCTAssertEqual(line(F.plan(rhythm: rhythm), day: 1, clock: "20:10")?.detail, "숙소 도착 뒤")
    }

    func testArrivingCloseToBedtimeWarnsOnTheStay() {
        let stay = line(F.plan(rhythm: rhythm), day: 1, clock: "19:36")
        XCTAssertEqual(stay?.caution?.title, "밤잠 시간과 맞닿아요")
        XCTAssertEqual(stay?.caution?.body, "카시트에서 잔 기록이 2번 있어요. 차에서 잠들면 숙소에서 바로 눕힐 수 있게 아기침대 요청을 먼저 확인하세요.")
        XCTAssertEqual(stay?.caution?.timing, "빨라야 19:36에 닿고, 밤잠은 20:10이에요.")
    }

    func testArrivingWellBeforeBedtimeDoesNotWarn() {
        var car = F.car
        car.pickup = F.at(10, 16)
        XCTAssertNil(F.plan(F.trip([F.kyoto, car]), rhythm: rhythm).days[0].lines.first { $0.title.contains("교토 숙소") && $0.lane == .travel }?.caution)
    }

    func testOpenLineWaitsForTheNextTimedLine() {
        XCTAssertEqual(F.text(F.plan(rhythm: rhythm), day: 5).prefix(5), [
            "06:50 수유",
            "08:10 이유식",
            "미정 오사카 숙소 체크아웃",
            "09:16 늦어도 간사이공항까지 차로 약 44분, 구글지도 기준",
            "09:40 낮잠 약 70분"
        ])
    }

    // 🩸 기상을 모르는데 06:00 부터 「깬 뒤 바로」라고 적었다 — 기준이 없으면 수유 줄을 지어내지 않는다.
    func testFeedingLinesNeedAKnownWakeTime() {
        let noWake = BabyRhythm(naps: rhythm.naps, bedtimeMinute: rhythm.bedtimeMinute, wakeMinute: nil, dayFeedIntervalMin: 230, solids: rhythm.solids,
                                carSeatNaps: 0, daysWithRecords: 7, meat: .absent, hasSolids: true)
        XCTAssertFalse(F.text(F.plan(rhythm: noWake), day: 2).contains { $0.contains("수유") })
    }

    func testDayWithoutBookingsStillHasTheBabysDay() {
        let plan = F.plan(rhythm: rhythm)
        XCTAssertEqual(F.text(plan, day: 2).count, 9)
        XCTAssertEqual(plan.days[1].lines.map(\.lane), Array(repeating: .baby, count: 9))
    }

    func testLanesNameEachKindOfLine() {
        let lines = F.plan(rhythm: rhythm).days[0].lines
        XCTAssertEqual(lines.first { $0.title == "인천 출발 KE999" }?.lane, .travel)
        XCTAssertEqual(lines.first { $0.title == "교토 숙소까지 차로 약 1시간 36분, 구글지도 기준" }?.lane, .route)
    }
}

/// 일정표 — 세 화면이 같은 계산을 읽는다.
final class ItineraryScreensTests: XCTestCase {
    private typealias F = ItineraryFixture

    private let rhythm = BabyRhythm(naps: [BabyRhythm.Block(startMinute: 14 * 60 + 10, minutes: 80, share: 1)],
                                    bedtimeMinute: 20 * 60 + 10, wakeMinute: nil, dayFeedIntervalMin: nil, solids: [],
                                    carSeatNaps: 0, daysWithRecords: 7, meat: .absent, hasSolids: false)

    private func home(_ plan: Itinerary, day: Int) -> [String] {
        plan.days[day - 1].homeLines.map { [$0.clock, $0.clockNote ?? "", $0.title].filter { !$0.isEmpty }.joined(separator: " ") }
    }

    func testAsksTheMapOnlyWhatItDoesNotKnow() {
        XCTAssertEqual(F.plan(routes: [:]).routeQuestions.count, 3)
        XCTAssertEqual(F.plan().routeQuestions, [])
    }

    // 여행 줄의 개수·순서는 지도 답에 좌우되지 않는다(아기 줄은 시각에 맞춰 사이로 들어간다).
    func testMapAnswersNeverMoveATravelLine() {
        func travel(_ plan: Itinerary) -> [String] { plan.days.flatMap { $0.lines.filter { $0.lane != .baby }.map(\.id) } }
        XCTAssertEqual(travel(F.plan(rhythm: rhythm, routes: [:])), travel(F.plan(rhythm: rhythm)))
    }

    func testPeopleCoveringTheLegMeansNoQuestion() {
        let move = TripMove(id: "m1", startAt: TravelTestClock.at(2027, 5, 10, 18, 30), minutes: 90, fromLabel: "간사이공항", toLabel: "교토 숙소")
        XCTAssertEqual(F.plan(F.trip(moves: [move]), routes: [:]).routeQuestions.count, 2)
    }

    func testHomeFoldsTheFlightIntoOneLine() {
        let plan = F.plan(rhythm: rhythm)
        XCTAssertEqual(home(plan, day: 1), ["15:10 KE999 인천 → 간사이", "18:00 렌터카 인수", "19:36 빨라야 교토 숙소 도착"])
        XCTAssertEqual(plan.days[0].homeLines.map(\.detail), ["가는 편 · 17:00 도착", "간사이공항", "차로 약 1시간 36분 · 구글지도 기준"])
    }

    func testHomeChipsUseTheSameJudgementAsTheSchedule() {
        let chips = F.plan(rhythm: rhythm).days[0].homeLines.map(\.childNote)
        XCTAssertEqual(chips, ["낮잠 14:10과 탑승이 겹쳐요", nil, "밤잠 20:10과 맞닿아요"])
    }

    func testHomeShowsOpenTimesToo() {
        XCTAssertEqual(home(F.plan(), day: 5), ["미정 오사카 숙소 체크아웃", "10:00 렌터카 반납", "11:55 KE998 간사이 → 인천"])
    }

    func testHomeNeverShowsMoreThanFiveLines() {
        let moves = (0..<8).map { TripMove(id: "m\($0)", startAt: TravelTestClock.at(2027, 5, 11, 9 + $0), minutes: 30, fromLabel: "가", toLabel: "나") }
        XCTAssertEqual(F.plan(F.trip(moves: moves)).days[1].homeLines.count, 5)
    }

    // 🩸 도착을 비우면 가는 편이 「다른 날 예약」으로 빠졌다(빌드 113).
    func testGoingDayKeepsTheFlightEvenWithoutAnArrivalTime() {
        var out = F.outbound
        out.arrive = nil
        let plan = F.plan(F.trip([out, F.inbound, F.car, F.kyoto, F.osaka]))
        XCTAssertEqual(plan.bookings.dayOne.map(\.title), ["간사이공항 도착", "렌터카 인수", "교토 숙소 도착"])
        XCTAssertEqual(plan.bookings.dayOne.first?.clock, "미정")
    }

    func testGoingDayReadsLikeTheSchedule() {
        let plan = F.plan(rhythm: rhythm)
        let stops = plan.bookings.dayOne
        XCTAssertEqual(stops.map(\.clock), ["17:00", "18:00", "19:36"])
        XCTAssertEqual(stops.last?.clockNote, "빨라야")
        XCTAssertEqual(stops[0].details, ["가는 편 KE999, 인천 15:10 출발"])
        XCTAssertEqual(stops[1].details, ["시험 렌터카, 간사이공항"])
        XCTAssertEqual(stops[2].details, ["체크인 15:00~22:00"])
        XCTAssertEqual(stops[1].legAfter?.title, "교토 숙소까지 차로 약 1시간 36분, 구글지도 기준")
        XCTAssertEqual(stops[1].caution?.timing, "빨라야 19:36에 닿고, 밤잠은 20:10이에요.")
        XCTAssertEqual(plan.bookings.sourceLabel, "구글지도 기준")
    }

    func testOtherDaysListEverythingElse() {
        let others = F.plan().bookings.otherDays
        XCTAssertEqual(others.map(\.title), ["오사카 숙소", "렌터카 반납", "오는 편 KE998, 간사이 → 인천"])
        XCTAssertEqual(others[0].details, ["5.12(수) 15:00 체크인, 5.14(금) 체크아웃"])
        XCTAssertEqual(others[1].details, ["5.14(금) 10:00, 간사이공항"])
        XCTAssertEqual(others[2].details, ["5.14(금) 11:55 출발, 14:00 도착"])
    }

    func testOpenTimesReadAsOpenInTheList() {
        var back = F.inbound
        back.depart = F.on(14)
        XCTAssertEqual(F.plan(F.trip([back])).bookings.otherDays.first?.details, ["5.14(금) 출발 시각 미정, 14:00 도착"])
    }

    func testEveryBookingCanBeReachedFromTheList() {
        var loose = F.osaka
        loose.checkIn = nil
        loose.checkOut = nil
        let trip = F.trip([F.outbound, F.inbound, F.car, F.kyoto, loose, TripBooking(id: "x", kind: .unknown)])
        let plan = F.plan(trip)
        let listed = Set((plan.bookings.dayOne + plan.bookings.otherDays).map(\.booking.id))
        XCTAssertEqual(listed, ["f1", "f2", "c1", "h1", "h2"])
    }

    func testCarPickedUpLaterIsOneLine() {
        var car = F.car
        car.pickup = F.at(11, 9)
        let stops = F.plan(F.trip([F.outbound, car])).bookings
        XCTAssertEqual(stops.otherDays.map(\.kind), [.carRental])
        XCTAssertEqual(stops.otherDays.first?.details, ["5.11(화) 09:00 인수, 간사이공항", "5.14(금) 10:00 반납, 간사이공항"])
    }
}

/// 보기 모델 — 네 사건에서만 다시 계산하고, 지도에는 모르는 구간만 묻는다.
@MainActor
final class ItineraryViewModelTests: XCTestCase {
    private typealias F = ItineraryFixture

    private final class CountingRoutes: RouteTimeProviding, @unchecked Sendable {
        private let lock = NSLock()
        private var asked: [String] = []
        var outcome: (String, String) throws -> RouteEstimate = { _, _ in
            RouteEstimate(minutes: 96, fromName: nil, toName: nil, source: .google)
        }
        var count: Int { lock.withLock { asked.count } }

        func drivingRoute(from: String, to: String, near area: TripRouteArea) async throws -> RouteEstimate {
            lock.withLock { asked.append("\(from)→\(to)") }
            return try outcome(from, to)
        }
    }

    private func model(routes: CountingRoutes) -> TripDetailViewModel {
        TripDetailViewModel(trip: F.trip(), ownerUserId: "u1", currentUserId: "u1", babyBirthDate: TravelTestClock.at(2026, 8, 30),
                            provider: MockTripFirestore(), routeTime: routes, calendar: TravelTestClock.cal)
    }

    func testMapAnswersReachTheItinerary() async {
        let routes = CountingRoutes()
        let vm = model(routes: routes)
        XCTAssertEqual(vm.itinerary.routeQuestions.count, 3)
        await vm.loadRoutes()
        XCTAssertEqual(vm.itinerary.routeQuestions, [])
        XCTAssertEqual(F.text(vm.itinerary, day: 1).last, "19:36 빨라야 교토 숙소 도착")
    }

    func testEachLegIsAskedOnce() async {
        let routes = CountingRoutes()
        let vm = model(routes: routes)
        await vm.loadRoutes()
        await vm.loadRoutes()
        XCTAssertEqual(routes.count, 3)
    }

    func testPlaceTheMapCannotFindIsNotAskedAgain() async {
        let routes = CountingRoutes()
        routes.outcome = { _, _ in throw RouteTimeError.notFound }
        let vm = model(routes: routes)
        await vm.loadRoutes()
        await vm.loadRoutes()
        XCTAssertEqual(routes.count, 3)
        XCTAssertEqual(vm.itinerary.routeQuestions, [])
        XCTAssertTrue(vm.itinerary.days[0].lines.contains { $0.detail == "지도에서 길을 찾지 못했어요" })
    }

    // 망이 끊겨 실패한 구간은 다시 물을 수 있게 남긴다.
    func testNetworkFailureStaysAsAQuestion() async {
        let routes = CountingRoutes()
        routes.outcome = { _, _ in throw URLError(.notConnectedToInternet) }
        let vm = model(routes: routes)
        await vm.loadRoutes()
        XCTAssertEqual(vm.itinerary.routeQuestions.count, 3)
    }

    func testSavedBookingMovesTheItineraryAtOnce() async {
        let vm = model(routes: CountingRoutes())
        var back = F.inbound
        back.depart = F.on(14)
        await vm.upsertBooking(back)
        XCTAssertTrue(F.text(vm.itinerary, day: 5).contains("미정 간사이 출발 KE998"))
    }
}
