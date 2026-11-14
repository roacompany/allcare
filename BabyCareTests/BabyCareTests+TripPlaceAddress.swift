import XCTest
@testable import BabyCare

/// 같은 이름이 다른 지역에도 있다 — 찾아 고른 곳은 주소까지 지니고, 길찾기는 이름 대신 그 주소를 본다.
/// 고치기 전: 렌터카 인수·반납과 일정 출발·도착은 이름만 저장해, 길찾기가 여행 도시 근처의 같은 이름으로 잡았다
/// (숙소만 주소를 지녔다 — TripRoutePlace 가 숙소 이름을 주소로 바꾼다).
final class TripPlaceAddressTests: XCTestCase {

    private let farAway = PlaceSearchModel.Pick(name: "가상 렌터카 영업소", address: "가상현 먼 시 1-2")

    private func trip(bookings: [TripBooking] = [], moves: [TripMove] = []) -> Trip {
        var t = Trip(babyId: "b", countryCode: "JP", city: "가상 도시", startDay: "2027-05-10", endDay: "2027-05-14")
        t.bookings = bookings
        t.moves = moves
        return t
    }

    private func move(from: String = "", to: String = "") -> TripMove {
        TripMove(id: "m1", startAt: Date(timeIntervalSince1970: 1_810_000_000), minutes: 30, fromLabel: from, toLabel: to)
    }

    // MARK: - 렌터카

    func test_pickingRentalPlace_keepsNameAndAddress() {
        let empty = TripBooking(kind: .rentalCar)
        let pickedUp = TripBookingForm.pickingRentalPlace(farAway, at: .pickup, into: empty)
        XCTAssertEqual(pickedUp.pickupPlace, "가상 렌터카 영업소")
        XCTAssertEqual(pickedUp.pickupAddress, "가상현 먼 시 1-2")
        XCTAssertNil(pickedUp.returnAddress, "다른 칸은 그대로")

        let returned = TripBookingForm.pickingRentalPlace(farAway, at: .carReturn, into: empty)
        XCTAssertEqual(returned.returnPlace, "가상 렌터카 영업소")
        XCTAssertEqual(returned.returnAddress, "가상현 먼 시 1-2")
    }

    /// 칩·직접 입력으로 다른 이름이 되면 옛 주소를 비운다(옛 주소로 길을 찾으면 다른 곳으로 간다). 같은 이름이면 지킨다.
    func test_typingRentalPlace_clearsAddressOnlyWhenNameChanges() {
        let picked = TripBookingForm.pickingRentalPlace(farAway, at: .pickup, into: TripBooking(kind: .rentalCar))
        let changed = TripBookingForm.typingRentalPlace("교토역", at: .pickup, into: picked)
        XCTAssertEqual(changed.pickupPlace, "교토역")
        XCTAssertNil(changed.pickupAddress)

        let same = TripBookingForm.typingRentalPlace("가상 렌터카 영업소", at: .pickup, into: picked)
        XCTAssertEqual(same.pickupAddress, "가상현 먼 시 1-2")
    }

    /// 같은 이름을 다시 골랐는데 지도가 주소를 안 줬으면 지닌 주소를 지킨다(숙소와 같은 규칙).
    func test_pickingSameRentalNameWithoutAddress_keepsAddress() {
        let picked = TripBookingForm.pickingRentalPlace(farAway, at: .pickup, into: TripBooking(kind: .rentalCar))
        let again = TripBookingForm.pickingRentalPlace(PlaceSearchModel.Pick(name: "가상 렌터카 영업소", address: nil),
                                                       at: .pickup, into: picked)
        XCTAssertEqual(again.pickupAddress, "가상현 먼 시 1-2")
    }

    // MARK: - 일정(이동)

    func test_pickingMovePlace_keepsNameAndAddress_typingAnotherClearsIt() {
        let picked = TripBookingForm.pickingMovePlace(farAway, at: .to, into: move(from: "교토 숙소"))
        XCTAssertEqual(picked.toLabel, "가상 렌터카 영업소")
        XCTAssertEqual(picked.toAddress, "가상현 먼 시 1-2")
        XCTAssertNil(picked.fromAddress)

        let changed = TripBookingForm.typingMovePlace("간사이공항", at: .to, into: picked)
        XCTAssertNil(changed.toAddress)
    }

    /// 일정 넣는 창이 차 시간을 물을 글자 = 주소가 있으면 주소, 없으면 이름.
    func test_moveRouteText_prefersAddress() {
        let picked = TripBookingForm.pickingMovePlace(farAway, at: .from, into: move(to: "교토 숙소"))
        XCTAssertEqual(TripBookingForm.routeText(for: picked, at: .from), "가상현 먼 시 1-2")
        XCTAssertEqual(TripBookingForm.routeText(for: picked, at: .to), "교토 숙소")
    }

    // MARK: - 길찾기 물음(TripRoutePlace)

    func test_routeQuery_usesPickedRentalAddress() {
        let rental = TripBooking(kind: .rentalCar, pickupPlace: "가상 렌터카 영업소", pickupAddress: "가상현 먼 시 1-2",
                                 returnPlace: "가상 반납소", returnAddress: "가상현 다른 시 3")
        let t = trip(bookings: [rental])
        XCTAssertEqual(TripRoutePlace.query(for: "가상 렌터카 영업소", trip: t), "가상현 먼 시 1-2")
        XCTAssertEqual(TripRoutePlace.query(for: "가상 반납소", trip: t), "가상현 다른 시 3")
    }

    func test_routeQuery_usesPickedMoveAddress() {
        var m = move(from: "가상 수족관", to: "교토 숙소")
        m.fromAddress = "가상현 바닷가 9"
        let t = trip(moves: [m])
        XCTAssertEqual(TripRoutePlace.query(for: "가상 수족관", trip: t), "가상현 바닷가 9")
    }

    /// 주소가 없으면 이름 그대로(고치기 전과 같음) · 숙소는 그대로 주소.
    func test_routeQuery_withoutPickedAddress_keepsName_andHotelStillUsesItsAddress() {
        let hotel = TripBooking(kind: .hotel, name: "가상 호텔", address: "가상현 호텔 길 5")
        let rental = TripBooking(kind: .rentalCar, pickupPlace: "이름만 적은 곳")
        let t = trip(bookings: [hotel, rental])
        XCTAssertEqual(TripRoutePlace.query(for: "이름만 적은 곳", trip: t), "이름만 적은 곳")
        XCTAssertEqual(TripRoutePlace.query(for: "가상 호텔", trip: t), "가상현 호텔 길 5")
    }

    // MARK: - 저장 모양(옛 판과 함께 산다)

    /// 새 칸이 없는 옛 문서도 읽는다(2.8.13 이 쓴 예약·일정) — 주소는 nil.
    func test_oldDocumentsWithoutAddressFields_stillDecode() throws {
        let oldMove = #"{"id":"m1","startAt":0,"minutes":30,"fromLabel":"교토 숙소","toLabel":"간사이공항"}"#
        let decoded = try JSONDecoder().decode(TripMove.self, from: Data(oldMove.utf8))
        XCTAssertEqual(decoded.toLabel, "간사이공항")
        XCTAssertNil(decoded.toAddress)
    }

    func test_addressFields_roundTrip() throws {
        var m = move(from: "가상 수족관", to: "교토 숙소")
        m.fromAddress = "가상현 바닷가 9"
        let back = try JSONDecoder().decode(TripMove.self, from: try JSONEncoder().encode(m))
        XCTAssertEqual(back.fromAddress, "가상현 바닷가 9")

        let rental = TripBooking(kind: .rentalCar, pickupPlace: "가상 렌터카 영업소", pickupAddress: "가상현 먼 시 1-2")
        let rentalBack = try JSONDecoder().decode(TripBooking.self, from: try JSONEncoder().encode(rental))
        XCTAssertEqual(rentalBack.pickupAddress, "가상현 먼 시 1-2")
    }
}
