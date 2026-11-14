import XCTest
import CoreGraphics
import SwiftUI
@testable import BabyCare

// MARK: - 캡처로 추가(PO 2026-11-05 「캡처본을 이미지로 올리면 그걸 분석해줄 수는 없나?」) — 전부 폰 안에서 읽는다

private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }
private let cal = TravelTestClock.cal
private let tripDays = (10...14).map { at(2027, 5, $0) }

/// 한국 항공사 확인 메일을 캡처해 글자로 읽은 모양(예약번호·이름 없음).
private let airlineMailText = """
항공권 예약 확인
여정 1
2027년 5월 10일 (월)
KE725 대한항공
인천 (ICN) 15:10 → 오사카/간사이 (KIX) 17:00
여정 2
2027년 5월 14일 (금)
KE724 대한항공
오사카/간사이 (KIX) 11:55 → 인천 (ICN) 14:00
수하물 23kg 1개
"""

/// 일본 숙소 확인 화면(영문 날짜).
private let hotelMailText = """
Reservation confirmed
Check-in Mon, May 10, 2027 15:00
Check-out Wed, May 12, 2027 10:00
京都府京都市下京区東塩小路町
"""

final class CaptureDateParserTests: XCTestCase {
    private func day(_ s: String, days: [Date] = tripDays) -> Date? { CaptureDateParser.day(in: s, tripDays: days, calendar: cal) }

    func testFullDates() {
        XCTAssertEqual(day("2027.05.10"), at(2027, 5, 10))
        XCTAssertEqual(day("2027-05-10"), at(2027, 5, 10))
        XCTAssertEqual(day("2027/5/10 (월)"), at(2027, 5, 10))
        XCTAssertEqual(day("2027년 5월 10일 (월)"), at(2027, 5, 10))
        XCTAssertEqual(day("2027年5月12日(水)"), at(2027, 5, 12))
    }

    // 연도가 없으면 여행 기간으로
    func testDatesWithoutYear() {
        XCTAssertEqual(day("5월 10일"), at(2027, 5, 10))
        XCTAssertEqual(day("5/10(월)"), at(2027, 5, 10))
        XCTAssertEqual(day("5.14(금) 11:55"), at(2027, 5, 14))
        XCTAssertEqual(day("5月12日"), at(2027, 5, 12))
    }

    func testEnglishDates() {
        XCTAssertEqual(day("May 10"), at(2027, 5, 10))
        XCTAssertEqual(day("MAY 10, 2027"), at(2027, 5, 10))
        XCTAssertEqual(day("10 MAY 2027"), at(2027, 5, 10))
        XCTAssertEqual(day("KE725 10MAY ICN KIX"), at(2027, 5, 10))
        XCTAssertEqual(day("Mon, May 10, 2027 15:00"), at(2027, 5, 10))
    }

    // 연말 여행 — 「1월 2일」은 다음 해
    func testYearCrossesWithTrip() {
        let days = [at(2026, 12, 30), at(2026, 12, 31), at(2027, 1, 1), at(2027, 1, 2)]
        XCTAssertEqual(day("1월 2일", days: days), at(2027, 1, 2))
    }

    // 날짜가 아닌 것
    func testNotDates() {
        XCTAssertNil(day("15:10"))
        XCTAssertNil(day("KE725"))
        XCTAssertNil(day("수하물 1.5kg"))
        XCTAssertNil(day("1,500원"))
    }

    func testTimes() {
        XCTAssertEqual(CaptureDateParser.times(in: "인천 15:10 → 간사이 17:00").map(\.hour), [15, 17])
        XCTAssertEqual(CaptureDateParser.times(in: "오후 3:10 출발").first?.hour, 15)
        XCTAssertEqual(CaptureDateParser.times(in: "15시 10분").first?.minute, 10)
        XCTAssertEqual(CaptureDateParser.times(in: "15時10分").first?.hour, 15)
        XCTAssertEqual(CaptureDateParser.times(in: "12:10 AM").first?.hour, 0)
        XCTAssertEqual(CaptureDateParser.times(in: "9:30 PM").first?.hour, 21)
        XCTAssertEqual(CaptureDateParser.times(in: "2027.05.10 1,500원"), [])
        XCTAssertEqual(CaptureDateParser.time("09:30"), CaptureClock(hour: 9, minute: 30))
    }
}

final class CaptureTextLayoutTests: XCTestCase {
    // 글자 조각(Vision 좌표 = 왼쪽 아래가 0) → 위에서 아래로 줄, 줄 안은 왼쪽부터
    func testGroupsPiecesIntoLinesTopToBottom() {
        let pieces: [(CGRect, String)] = [
            (CGRect(x: 0.55, y: 0.80, width: 0.2, height: 0.03), "17:00"),
            (CGRect(x: 0.05, y: 0.90, width: 0.4, height: 0.03), "KE725 대한항공"),
            (CGRect(x: 0.05, y: 0.805, width: 0.4, height: 0.03), "인천 15:10 →"),
        ]
        XCTAssertEqual(CaptureTextLayout.lines(pieces), "KE725 대한항공\n인천 15:10 → 17:00")
    }
}

final class RuleCaptureExtractorTests: XCTestCase {
    // 항공사 메일 → 편 둘(편명 · 날짜 · 시각 · 공항)
    func testFindsBothFlightsInAirlineMail() {
        let x = RuleCaptureExtractor.flights(in: airlineMailText)
        XCTAssertEqual(x.map(\.flightNumber), ["KE725", "KE724"])
        XCTAssertEqual(x.first?.departTime, "15:10")
        XCTAssertEqual(x.first?.arriveTime, "17:00")
        XCTAssertEqual(x.first?.fromAirport, "ICN")
        XCTAssertEqual(x.first?.toAirport, "KIX")
        XCTAssertEqual(CaptureDateParser.day(in: x.first?.date ?? "", tripDays: tripDays, calendar: cal), at(2027, 5, 10))
        XCTAssertEqual(x.last?.fromAirport, "KIX")
        XCTAssertEqual(CaptureDateParser.day(in: x.last?.date ?? "", tripDays: tripDays, calendar: cal), at(2027, 5, 14))
    }

    // 「KE」 혼자 · 수하물 무게 · 금액은 편명이 아니다
    func testIgnoresThingsThatAreNotFlightNumbers() {
        XCTAssertEqual(RuleCaptureExtractor.flights(in: "KE 마일리지 1,500 적립\n수하물 23kg").count, 0)
        XCTAssertEqual(RuleCaptureExtractor.flights(in: "아시아나 OZ 112 편 2027.05.10 07:20").map(\.flightNumber), ["OZ112"])
    }
}

final class CaptureBookingBuilderTests: XCTestCase {
    private func flightX(_ n: String, _ date: String, _ dep: String?, _ arr: String?, _ from: String?, _ to: String?) -> CaptureExtraction.Flight {
        CaptureExtraction.Flight(flightNumber: n, date: date, departTime: dep, arriveTime: arr, fromAirport: from, toAirport: to)
    }

    func testFlightsBecomeBookingsWithTitles() throws {
        let x = CaptureExtraction(flights: [flightX("KE725", "2027.05.10", "15:10", "17:00", "ICN", "KIX"),
                                            flightX("KE724", "5/14(금)", "11:55", "14:00", "간사이", "인천")])
        let items = CaptureBookingBuilder.build(x, trip: TravelFixtures.osakaTrip(bookings: []), calendar: cal)
        XCTAssertEqual(items.count, 2)
        let out = try XCTUnwrap(items.first)
        XCTAssertEqual(out.booking.kind, .flight)
        XCTAssertEqual(out.booking.flightNumber, "KE725")
        XCTAssertEqual(out.booking.airline, "KE")
        XCTAssertEqual(out.booking.depart?.time, at(2027, 5, 10, 15, 10))
        XCTAssertEqual(out.booking.arrive?.time, at(2027, 5, 10, 17, 0))
        XCTAssertEqual(out.needs, [])
        XCTAssertTrue(out.selected)
        XCTAssertEqual(CaptureBookingText.title(out.booking), "KE725 가는 편")
        XCTAssertEqual(CaptureBookingText.detail(out.booking, calendar: cal), "5.10(월) 인천 15:10 → 간사이 17:00")
        XCTAssertEqual(items.last?.booking.fromAirport, "KIX")
        XCTAssertEqual(CaptureBookingText.title(items.last!.booking), "KE724 오는 편")
    }

    // 이미 넣어 둔 편은 「이미 있음」으로 끈다 · 캡처 두 장에 같은 편이 있으면 하나로
    func testDuplicatesAgainstTripAndWithinCaptures() {
        let x = CaptureExtraction(flights: [flightX("KE725", "2027.05.10", "15:10", "17:00", "ICN", "KIX"),
                                            flightX("KE725", "5월 10일", "15:10", nil, "ICN", "KIX"),
                                            flightX("KE724", "2027.05.14", "11:55", "14:00", "KIX", "ICN")])
        let trip = TravelFixtures.osakaTrip(bookings: [TravelFixtures.outbound()])
        let items = CaptureBookingBuilder.build(x, trip: trip, calendar: cal)
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items[0].isDuplicate)
        XCTAssertFalse(items[0].selected)
        XCTAssertFalse(items[1].isDuplicate)
    }

    // 모르는 칸은 지어 넣지 않고 「확인 필요」
    func testMissingFieldsAreFlaggedNotInvented() throws {
        let x = CaptureExtraction(flights: [flightX("KE725", "2027.05.10", "15:10", nil, "ICN", "KIX")])
        let item = try XCTUnwrap(CaptureBookingBuilder.build(x, trip: TravelFixtures.osakaTrip(bookings: []), calendar: cal).first)
        XCTAssertNil(item.booking.arrive?.time)
        XCTAssertEqual(item.needs, [.arriveTime])
        XCTAssertEqual(CaptureBookingText.needs(item.needs), "도착 시각 확인 필요")
    }

    func testHotelAndRental() throws {
        let hotel = CaptureExtraction.Hotel(name: "교토 숙소", address: "京都府京都市下京区東塩小路町", checkInDate: "May 10, 2027", checkInTime: "15:00",
                                            checkOutDate: "May 12, 2027", checkOutTime: "10:00", freeCancelDate: nil, freeCancelTime: nil)
        let rental = CaptureExtraction.Rental(company: "렌터카", pickupPlace: "간사이공항", pickupDate: "2027.05.10", pickupTime: "18:00",
                                              returnPlace: "간사이공항", returnDate: "2027.05.14", returnTime: "09:30",
                                              freeCancelDate: "2027.05.07", freeCancelTime: "18:00")
        let items = CaptureBookingBuilder.build(CaptureExtraction(hotels: [hotel], rentals: [rental]),
                                                trip: TravelFixtures.osakaTrip(bookings: []), calendar: cal)
        let h = try XCTUnwrap(items.first { $0.booking.kind == .hotel })
        XCTAssertEqual(h.booking.checkIn?.time, at(2027, 5, 10, 15, 0))
        XCTAssertEqual(h.booking.checkOut?.time, at(2027, 5, 12, 10, 0))
        XCTAssertEqual(h.needs, [.freeCancel])
        XCTAssertEqual(CaptureBookingText.needs(h.needs), "무료 취소 기한 확인 필요")
        XCTAssertEqual(CaptureBookingText.detail(h.booking, calendar: cal), "5.10(월)–5.12(수) · 京都府京都市下京区東塩小路町")
        let r = try XCTUnwrap(items.first { $0.booking.kind == .rentalCar })
        XCTAssertEqual(r.booking.freeCancel?.time, at(2027, 5, 7, 18, 0))
        XCTAssertEqual(r.needs, [])
        XCTAssertEqual(CaptureBookingText.title(r.booking), "간사이공항 인수")
        XCTAssertEqual(CaptureBookingText.detail(r.booking, calendar: cal), "인수 5.10(월) 18:00 · 반납 5.14(금) 09:30")
    }

    // 시간표 한 줄로 비는 칸만 채운다(캡처에 적힌 값은 그대로)
    func testScheduleFillsOnlyMissing() throws {
        let x = CaptureExtraction(flights: [flightX("KE725", "5월 10일", nil, "17:05", nil, nil)])
        var item = try XCTUnwrap(CaptureBookingBuilder.build(x, trip: TravelFixtures.osakaTrip(bookings: []), calendar: cal).first)
        XCTAssertEqual(Set(item.needs), [.departTime, .airports])
        let row = FlightScheduleRow(flightId: "KE725", airlineName: "대한항공", counterpartName: "오사카/간사이", counterpartCode: "KIX",
                                    hour: 15, minute: 10, firstDay: "20270428", lastDay: "20270925", weekdays: Set(1...7), direction: .departure)
        item = CaptureBookingBuilder.fill(item, with: row, calendar: cal)
        XCTAssertEqual(item.booking.depart?.time, at(2027, 5, 10, 15, 10))
        XCTAssertEqual(item.booking.arrive?.time, at(2027, 5, 10, 17, 5))
        XCTAssertEqual(item.booking.fromAirport, "ICN")
        XCTAssertEqual(item.booking.toAirport, "KIX")
        XCTAssertEqual(item.needs, [])
    }
}

private final class FakeCaptureText: CaptureTextReading, @unchecked Sendable {
    var texts: [String] = []
    func texts(from images: [Data]) async throws -> [String] { texts }
}

private final class FakeExtractor: CaptureExtracting, @unchecked Sendable {
    var result = CaptureExtraction()
    var error: Error?
    var reader: CaptureReader { .appleIntelligence }
    func extract(from text: String) async throws -> CaptureExtraction {
        if let error { throw error }
        return result
    }
}

private final class FakeAddress: PlaceAddressLooking, @unchecked Sendable {
    var calls: [String] = []
    func address(for name: String, near area: TripRouteArea) async -> String? {
        calls.append(name)
        return "京都府京都市下京区"
    }
}

private final class FakeSchedule: FlightScheduleProviding, @unchecked Sendable {
    func rows() async throws -> [FlightScheduleRow] {
        [FlightScheduleRow(flightId: "KE725", airlineName: "대한항공", counterpartName: "오사카/간사이", counterpartCode: "KIX",
                           hour: 15, minute: 10, firstDay: "20270428", lastDay: "20270925", weekdays: Set(1...7), direction: .departure)]
    }
}

@MainActor
final class CaptureViewModelTests: XCTestCase {
    private func vm(text: FakeCaptureText, extractor: FakeExtractor, address: FakeAddress = FakeAddress(),
                    provider: MockTripFirestore = MockTripFirestore(), trip: Trip = TravelFixtures.osakaTrip(bookings: [])) -> TripDetailViewModel {
        TripDetailViewModel(trip: trip, ownerUserId: "o", currentUserId: "p", babyBirthDate: at(2026, 8, 30),
                            provider: provider, childData: MockTripChildData(), reminders: MockTripReminderScheduler(),
                            flightSchedule: FakeSchedule(), captureText: text, captureExtractor: extractor, placeAddress: address,
                            now: { at(2027, 5, 6, 10, 0) }, calendar: cal)
    }

    // 캡처 → 예약 · 시간표로 비는 칸 채움 · 숙소 주소는 지도 찾기 한 번
    func testReadCapturesBuildsAndEnriches() async throws {
        let text = FakeCaptureText()
        text.texts = ["캡처 하나"]
        let extractor = FakeExtractor()
        extractor.result = CaptureExtraction(
            flights: [CaptureExtraction.Flight(flightNumber: "KE725", date: "5월 10일", departTime: nil, arriveTime: "17:00", fromAirport: nil, toAirport: nil)],
            hotels: [CaptureExtraction.Hotel(name: "교토 숙소", address: nil, checkInDate: "2027.05.10", checkInTime: "15:00",
                                             checkOutDate: "2027.05.12", checkOutTime: "10:00", freeCancelDate: "2027.05.07", freeCancelTime: "15:00")])
        let address = FakeAddress()
        let model = vm(text: text, extractor: extractor, address: address)
        let outcome = await model.readCaptures([Data([1])])
        XCTAssertEqual(outcome.reader, .appleIntelligence)
        XCTAssertEqual(outcome.imageCount, 1)
        XCTAssertEqual(outcome.items.count, 2)
        let flight = try XCTUnwrap(outcome.items.first { $0.booking.kind == .flight })
        XCTAssertEqual(flight.booking.depart?.time, at(2027, 5, 10, 15, 10))
        XCTAssertEqual(flight.booking.toAirport, "KIX")
        XCTAssertEqual(flight.needs, [])
        let hotel = try XCTUnwrap(outcome.items.first { $0.booking.kind == .hotel })
        XCTAssertEqual(hotel.booking.address, "京都府京都市下京区")
        XCTAssertEqual(address.calls, ["교토 숙소"])
    }

    // 기기 모델이 실패하면 규칙으로(항공편만)
    func testFallsBackToRulesWhenModelFails() async {
        let text = FakeCaptureText()
        text.texts = [airlineMailText]
        let extractor = FakeExtractor()
        extractor.error = CaptureError.modelUnavailable
        let outcome = await vm(text: text, extractor: extractor).readCaptures([Data([1])])
        XCTAssertEqual(outcome.reader, .rulesFlightsOnly)
        XCTAssertEqual(outcome.items.map(\.booking.flightNumber), ["KE725", "KE724"])
    }

    // 고른 것만 저장한다
    func testAddCapturedSavesOnlySelected() async {
        let provider = MockTripFirestore()
        let model = vm(text: FakeCaptureText(), extractor: FakeExtractor(), provider: provider)
        let x = CaptureExtraction(flights: [CaptureExtraction.Flight(flightNumber: "KE725", date: "2027.05.10", departTime: "15:10", arriveTime: "17:00", fromAirport: "ICN", toAirport: "KIX"),
                                            CaptureExtraction.Flight(flightNumber: "KE724", date: "2027.05.14", departTime: "11:55", arriveTime: "14:00", fromAirport: "KIX", toAirport: "ICN")])
        var items = CaptureBookingBuilder.build(x, trip: model.trip, calendar: cal)
        items[1].selected = false
        let added = await model.addCaptured(items)
        XCTAssertEqual(added, 1)
        XCTAssertEqual(model.trip.bookings.map(\.flightNumber), ["KE725"])
    }

    func testNothingFoundIsEmptyNotAnError() async {
        let text = FakeCaptureText()
        text.texts = ["영수증 1,500원"]
        let extractor = FakeExtractor()
        extractor.error = CaptureError.modelUnavailable
        let outcome = await vm(text: text, extractor: extractor).readCaptures([Data([1])])
        XCTAssertEqual(outcome.items, [])
        XCTAssertFalse(outcome.failed)
    }
}

// MARK: - 그림 — Babycare AI 확인 시트(시안 Entry-Capture · /tmp/babycare_screenshots/entry_capture_after.png)

@MainActor
final class TravelCaptureRenderTests: XCTestCase {
    func testCaptureSheetRenders() throws {
        let text = FakeCaptureText()
        text.texts = ["이미지"]
        let extractor = FakeExtractor()
        extractor.result = CaptureExtraction(
            flights: [CaptureExtraction.Flight(flightNumber: "KE725", date: "2027.05.10", departTime: "15:10", arriveTime: "17:00", fromAirport: "ICN", toAirport: "KIX"),
                      CaptureExtraction.Flight(flightNumber: "KE724", date: "2027.05.14", departTime: "11:55", arriveTime: "14:00", fromAirport: "KIX", toAirport: "ICN")],
            hotels: [CaptureExtraction.Hotel(name: "교토 숙소", address: "京都府京都市下京区", checkInDate: "2027.05.10", checkInTime: "15:00",
                                             checkOutDate: "2027.05.12", checkOutTime: "10:00", freeCancelDate: "2027.05.07", freeCancelTime: "15:00"),
                     CaptureExtraction.Hotel(name: "오사카 숙소", address: "大阪府大阪市北区", checkInDate: "2027.05.12", checkInTime: "15:00",
                                             checkOutDate: "2027.05.14", checkOutTime: "10:00", freeCancelDate: nil, freeCancelTime: nil)],
            rentals: [CaptureExtraction.Rental(company: "렌터카", pickupPlace: "간사이공항", pickupDate: "2027.05.10", pickupTime: "18:00",
                                               returnPlace: "간사이공항", returnDate: "2027.05.14", returnTime: "09:30",
                                               freeCancelDate: "2027.05.07", freeCancelTime: "18:00")])
        let vm = TripDetailViewModel(trip: TravelFixtures.osakaTrip(bookings: []), ownerUserId: "o", currentUserId: "p", babyBirthDate: at(2026, 8, 30),
                                     provider: MockTripFirestore(), childData: MockTripChildData(), reminders: MockTripReminderScheduler(),
                                     flightSchedule: FakeSchedule(), captureText: text, captureExtractor: extractor, placeAddress: FakeAddress(),
                                     now: { at(2027, 5, 6, 10, 0) }, calendar: cal)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 980)
        let host = UIHostingController(rootView: TripCaptureSheet(vm: vm, picks: []))
        window.rootViewController = host
        window.isHidden = false
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(2.0))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        try FileManager.default.createDirectory(atPath: "/tmp/babycare_screenshots", withIntermediateDirectories: true)
        try image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/babycare_screenshots/entry_capture_after.png"))
        XCTAssertGreaterThan(image.size.height, 0)
    }
}

// MARK: - 「이미 있음」 줄을 넣으면 있던 예약을 고친다(두 번 들어가지 않는다 · 2026-11-14)
// 고치기 전: 「이미 있음」 줄을 「수정」하면 다시 켜지고, 「N건 추가」가 새 예약으로 더해 같은 편이 두 번 들어갔다.

extension CaptureBookingBuilderTests {
    func test_duplicateRemembersWhichBookingItMatches() {
        let x = CaptureExtraction(flights: [flightX("KE725", "2027.05.10", "15:10", "17:00", "ICN", "KIX"),
                                            flightX("KE724", "2027.05.14", "11:55", "14:00", "KIX", "ICN")])
        let trip = TravelFixtures.osakaTrip(bookings: [TravelFixtures.outbound()])
        let items = CaptureBookingBuilder.build(x, trip: trip, calendar: cal)
        XCTAssertEqual(items[0].existingBookingId, "f1")
        XCTAssertNil(items[1].existingBookingId)
    }

    /// 있던 예약을 고칠 때: 이름표(id)는 있던 것 · 캡처(사람이 고친 값)가 있는 칸은 캡처 · 캡처가 빈 칸은 있던 값.
    func test_mergedDuplicate_keepsExistingIdAndFillsGapsFromExisting() {
        let existing = TravelFixtures.outbound() // KE · 15:10 → 17:00
        let captured = TripBooking(id: "new", kind: .flight, flightNumber: "KE725", fromAirport: "ICN", toAirport: "KIX",
                                   depart: .at(at(2027, 5, 10, 15, 10)), arrive: .at(at(2027, 5, 10, 17, 30)))
        let merged = CaptureBookingBuilder.merged(captured, into: existing, calendar: cal)
        XCTAssertEqual(merged.id, "f1")
        XCTAssertEqual(merged.arrive?.time, at(2027, 5, 10, 17, 30), "사람이 고친 도착 시각")
        XCTAssertEqual(merged.airline, "KE", "캡처에 없는 칸은 있던 값")
    }

    /// 캡처가 날짜만 알고 있던 예약이 같은 날의 시각을 알면 시각을 지킨다(덜 아는 값으로 덮지 않는다).
    func test_mergedDuplicate_keepsExistingTimeWhenCaptureKnowsOnlyTheDay() {
        let existing = TravelFixtures.outbound()
        let captured = TripBooking(id: "new", kind: .flight, flightNumber: "KE725", fromAirport: "ICN", toAirport: "KIX",
                                   depart: .day("2027-05-10"), arrive: nil)
        let merged = CaptureBookingBuilder.merged(captured, into: existing, calendar: cal)
        XCTAssertEqual(merged.depart?.time, at(2027, 5, 10, 15, 10))
        XCTAssertEqual(merged.arrive?.time, at(2027, 5, 10, 17, 0))
    }
}

extension CaptureViewModelTests {
    /// 「이미 있음」 줄을 고쳐서 넣으면 같은 편이 하나뿐이고, 고친 값이 들어간다.
    func test_addingEditedDuplicate_updatesTheExistingBookingInsteadOfAddingAnother() async {
        let provider = MockTripFirestore()
        let model = vm(text: FakeCaptureText(), extractor: FakeExtractor(), provider: provider,
                       trip: TravelFixtures.osakaTrip(bookings: [TravelFixtures.outbound()]))
        let x = CaptureExtraction(flights: [CaptureExtraction.Flight(flightNumber: "KE725", date: "2027.05.10", departTime: "15:10",
                                                                     arriveTime: "17:00", fromAirport: "ICN", toAirport: "KIX")])
        var items = CaptureBookingBuilder.build(x, trip: model.trip, calendar: cal)
        XCTAssertTrue(items[0].isDuplicate)
        var edited = items[0].booking
        edited.arrive = .at(at(2027, 5, 10, 17, 30))
        items[0] = CaptureBookingBuilder.edited(items[0], booking: edited, calendar: cal) // 「수정」
        items[0].selected = true

        _ = await model.addCaptured(items)

        let ke725 = model.trip.bookings.filter { $0.flightNumber == "KE725" }
        XCTAssertEqual(ke725.count, 1, "같은 편이 두 번 들어갔다")
        XCTAssertEqual(ke725.first?.id, "f1")
        XCTAssertEqual(ke725.first?.arrive?.time, at(2027, 5, 10, 17, 30))
    }
}
