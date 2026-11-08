import XCTest
@testable import BabyCare

// MARK: - 장소 검색(캔버스 Search-Move · Search-Hotel · PO 2026-11-06 「네.」)

private func mapRows(_ items: (String, String)...) -> [PlaceSearchModel.Suggestion] {
    items.enumerated().map { PlaceSearchModel.Suggestion(id: $0.offset, title: $0.element.0, subtitle: $0.element.1) }
}

final class TripPlaceSearchRowsTests: XCTestCase {
    private func titles(_ text: String, _ map: [PlaceSearchModel.Suggestion] = [], airports: Bool = true) -> [String] {
        TripPlaceSearchRows.rows(text: text, suggestions: map, includesAirports: airports).map(\.title)
    }

    // 깨지는 경우: 첫 줄이 사라지면 지도가 못 찾는 곳(친척 집 등)을 넣을 길이 없다.
    func testTypedTextIsFirstRowSoAPlaceTheMapCannotFindStillGoesIn() {
        let rows = TripPlaceSearchRows.rows(text: "  우리 친척 집 ", suggestions: [], includesAirports: true)
        XCTAssertEqual(rows.map(\.title), ["우리 친척 집"])
        XCTAssertEqual(rows.first?.subtitle, "직접 입력")
        XCTAssertEqual(rows.first?.pick, PlaceSearchModel.Pick(name: "우리 친척 집", address: nil))
    }

    func testBlankTextHasNoRows() {
        XCTAssertEqual(titles(""), [])
        XCTAssertEqual(titles("   "), [])
    }

    /// 🩸 2026-11-06 실측: 「간사이」에 애플 지도가 대학·병원만 내고 공항이 없었다.
    func testKansaiFindsTheAirportEvenWhenTheMapOffersOnlyOtherPlaces() {
        let map = mapRows(("간사이대학", "일본 오사카부 스이타시"), ("간사이 의과대학 병원", "일본 오사카부 히라카타시"))
        XCTAssertEqual(titles("간사이", map), ["간사이", "간사이공항", "간사이대학", "간사이 의과대학 병원"])
    }

    func testAirportRowCarriesTheNameTheRouteLookupUnderstands() {
        let rows = TripPlaceSearchRows.rows(text: "간사이", suggestions: [], includesAirports: true)
        XCTAssertEqual(rows.last?.subtitle, "関西国際空港")
        XCTAssertEqual(rows.last?.pick, PlaceSearchModel.Pick(name: "간사이공항", address: nil))
        XCTAssertEqual(TripRoutePlace.query(for: "간사이공항", trip: TravelFixtures.osakaTrip()), "関西国際空港")
    }

    func testAirportIsFoundByFullNameAndByOtherSpelling() {
        XCTAssertEqual(titles("간사이공항"), ["간사이공항", "간사이공항"])
        XCTAssertEqual(titles("칸사이"), ["칸사이", "간사이공항"])
    }

    func testOneLetterDoesNotPullAnAirportIn() {
        XCTAssertEqual(titles("간"), ["간"])
    }

    func testAirportTheMapAlsoNamesIsNotShownTwiceButItsStationStays() {
        let map = mapRows(("간사이 국제공항", "일본 오사카부 이즈미사노시"), ("간사이공항역", "일본 오사카부 다지리초"))
        XCTAssertEqual(titles("간사이", map), ["간사이", "간사이공항", "간사이공항역"])
    }

    func testHotelSearchLeavesAirportsOut() {
        let map = mapRows(("간사이대학", "일본 오사카부 스이타시"))
        XCTAssertEqual(titles("간사이", map, airports: false), ["간사이", "간사이대학"])
    }

    /// 2026-11-06 시뮬레이터 실측 순서 · 같은 이름의 지도 후보는 직접 입력과 나란히 남는다(시안 Search-Move).
    func testMapOrderIsKeptAndSameNamedPlaceStaysBesideTheTypedRow() {
        let map = mapRows(("후시미마치", "일본 오사카부 오사카시 주오구"), ("후시미구", "일본 교토부 교토시"), ("후시미", "일본 나라현 고세시"))
        XCTAssertEqual(titles("후시미", map), ["후시미", "후시미마치", "후시미구", "후시미"])
    }

    // 깨지는 경우: 지도 후보를 글자만으로 끝내면 주소를 못 받아 숙소 길찾기가 이름으로만 간다.
    func testMapRowHasNoDirectPickBecauseItsAddressComesFromTheMap() {
        let rows = TripPlaceSearchRows.rows(text: "후시미", suggestions: mapRows(("후시미구", "일본 교토부 교토시")), includesAirports: true)
        XCTAssertNil(rows.last?.pick)
        XCTAssertEqual(rows.last?.suggestion?.title, "후시미구")
    }
}

final class TripPlaceChipsTests: XCTestCase {
    private let trip = ["간사이공항", "교토 숙소"]

    /// 시안: 찾아서 고른 곳은 칩으로 들어간다(입력 칸이 없어서 칩이 아니면 고른 곳이 안 보인다).
    func testPickedPlaceOutsideTheTripBecomesTheLastChip() {
        XCTAssertEqual(TripEntryChoices.chips(choices: trip, value: "후시미 이나리 다이샤"),
                       ["간사이공항", "교토 숙소", "후시미 이나리 다이샤"])
    }

    func testPlaceAlreadyInTheTripIsNotRepeated() {
        XCTAssertEqual(TripEntryChoices.chips(choices: trip, value: "교토 숙소"), ["간사이공항", "교토 숙소"])
    }

    func testEmptyValueAddsNoChip() {
        XCTAssertEqual(TripEntryChoices.chips(choices: trip, value: ""), ["간사이공항", "교토 숙소"])
        XCTAssertEqual(TripEntryChoices.chips(choices: trip, value: "  "), ["간사이공항", "교토 숙소"])
    }

    /// 렌터카 장소는 안 넣어도 되는 칸이다 — 글자 칸이 없어 비울 길이 이것뿐이다.
    func testTappingTheSelectedPlaceClearsIt() {
        XCTAssertEqual(TripEntryChoices.tapping("교토 숙소", value: "교토 숙소"), "")
        XCTAssertEqual(TripEntryChoices.tapping("교토 숙소", value: " 교토 숙소 "), "")
    }

    func testTappingAnotherPlaceSwitchesToIt() {
        XCTAssertEqual(TripEntryChoices.tapping("간사이공항", value: "교토 숙소"), "간사이공항")
        XCTAssertEqual(TripEntryChoices.tapping("간사이공항", value: ""), "간사이공항")
    }
}

final class TripHotelPickTests: XCTestCase {
    private let hotel = TripBooking(id: "h1", kind: .hotel, name: "옛 숙소", address: "京都市 옛 주소")

    func testPickingFromTheMapFillsNameAndAddress() {
        let after = TripBookingForm.pickingHotel(.init(name: "새 숙소", address: "大阪市 새 주소"), into: hotel)
        XCTAssertEqual(after.name, "새 숙소")
        XCTAssertEqual(after.address, "大阪市 새 주소")
    }

    /// 🔴 주소 칸이 없어져서 고칠 길이 없다 — 옛 주소가 남으면 길찾기가 옛 숙소로 간다(지도는 주소를 먼저 본다).
    func testTypingANameClearsTheOldAddressSoDirectionsDoNotGoToTheOldHotel() {
        let after = TripBookingForm.pickingHotel(.init(name: "친척 집", address: nil), into: hotel)
        XCTAssertEqual(after.name, "친척 집")
        XCTAssertNil(after.address)
        XCTAssertEqual(TripRoutePlace.query(for: "친척 집", trip: TravelFixtures.osakaTrip(bookings: [after])), "친척 집")
    }

    // 깨지는 경우: 숙소를 다시 열어 같은 이름을 또 누르면 멀쩡한 주소가 날아가 길찾기가 이름으로만 간다.
    func testReconfirmingTheSameNameKeepsTheAddress() {
        let after = TripBookingForm.pickingHotel(.init(name: "옛 숙소", address: nil), into: hotel)
        XCTAssertEqual(after.address, "京都市 옛 주소")
    }
}

final class PlaceSearchPickTests: XCTestCase {
    /// 주소 칸이 없어 안 보인다 — 우편번호나 시 이름을 주소로 넣으면 길찾기가 이름보다 그 값을 먼저 쓴다.
    func testNameOnlyPickNeverTurnsTheSubtitleIntoAnAddress() {
        let suggestion = PlaceSearchModel.Suggestion(id: 0, title: "교토역빌딩", subtitle: "〒600-8216")
        XCTAssertEqual(PlaceSearchModel.nameOnlyPick(suggestion), PlaceSearchModel.Pick(name: "교토역빌딩", address: nil))
    }
}

/// 🩸 2026-11-06 PO 「기본도 안되어 있는 듯」: 앱이 묻는 대로 넣으면 1일차가 「체크인 → 렌터카 → 출발」이었다.
final class TripEnteredAsAskedTests: XCTestCase {
    private let cal = TravelTestClock.cal

    /// 사람이 시각을 건드리지 않은 새 예약 그대로의 여행.
    private func tripAsAsked() -> Trip {
        let first = TravelTestClock.at(2027, 5, 10)
        var hotel = TripBookingForm.newBooking(.hotel, tripStart: first, calendar: cal)
        hotel.name = "교토 숙소"
        var car = TripBookingForm.newBooking(.rentalCar, tripStart: first, calendar: cal)
        car.pickupPlace = "간사이공항"
        let out = TripBooking(id: "f1", kind: .flight, airline: "KE", flightNumber: "KE725", fromAirport: "ICN", toAirport: "KIX",
                              depart: .at(TravelTestClock.at(2027, 5, 10, 15, 10)))
        return TravelFixtures.osakaTrip(bookings: [out, hotel, car])
    }

    func testNothingInJapanComesBeforeTheFlightLeavesKorea() {
        let plan = Itinerary(trip: tripAsAsked(), rhythm: nil, calendar: cal)
        XCTAssertEqual(plan.days[0].lines.first?.title, "인천 출발 KE725", "첫 일이 출발이 아니다: \(plan.days[0].lines.map(\.title))")
    }

    // 사람이 시각을 안 건드린 새 예약에는 시각이 없다.
    func testNewBookingsCarryNoInventedTime() {
        let first = TravelTestClock.at(2027, 5, 10)
        let hotel = TripBookingForm.newBooking(.hotel, tripStart: first, calendar: cal)
        XCTAssertEqual(hotel.checkIn, .day("2027-05-10"))
        XCTAssertEqual(hotel.checkOut, .day("2027-05-11"))
        let car = TripBookingForm.newBooking(.rentalCar, tripStart: first, calendar: cal)
        XCTAssertEqual(car.pickup, .day("2027-05-10"))
        XCTAssertNil(TripBookingForm.newBooking(.flight, tripStart: first, calendar: cal).depart)
    }
}
