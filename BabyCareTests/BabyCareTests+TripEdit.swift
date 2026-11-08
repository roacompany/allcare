import XCTest
import SwiftUI
@testable import BabyCare

// MARK: - 여행 수정·만들기 — 여행 일정 앱처럼(PO 2026-11-06 「여행일정 앱처럼... 제발....」)

private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }

// MARK: - 그림 — 「지금 → 바뀐 뒤」(/tmp/babycare_screenshots/tripedit_*_<tag>.png)

@MainActor
final class TripEditRenderTests: XCTestCase {
    private let dir = "/tmp/babycare_screenshots"
    private let tag = "after"

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

    func testTripEditScreensRender() throws {
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let vm = TripDetailViewModel(trip: TravelFixtures.osakaTrip(), ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: at(2026, 8, 30), provider: MockTripFirestore(), childData: MockTripChildData(),
                                     reminders: MockTripReminderScheduler(), now: { at(2027, 5, 6, 10, 0) }, calendar: TravelTestClock.cal)
        let header = try render(NavigationStack {
            TravelHomeView(vm: vm, trips: [vm.trip], onSelect: { _ in }, onCreate: {}, onDelete: { _ in }, onDeleteTrip: {},
                           onShowSchedule: { _ in }, onShowTasks: {}, onShowChild: {})
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
        }, height: 500)
        try header.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/tripedit_header_\(tag).png"))
        let edit = try render(TripCreateSheet(editing: vm.trip, calendar: TravelTestClock.cal, onDelete: {}) { _, _, _ in }, height: 852)
        try edit.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/tripedit_edit_\(tag).png"))
        let create = try render(TripCreateSheet(calendar: TravelTestClock.cal) { _, _, _ in }, height: 852)
        try create.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/tripedit_create_\(tag).png"))
        XCTAssertGreaterThan(edit.size.height, 0)
    }
}

// MARK: - 기간 고르기 — 첫 탭 = 시작 · 둘째 탭 = 끝(앞이면 새 시작) · 셋째 탭 = 다시 시작

final class TripDateRangeSelectionTests: XCTestCase {
    private let cal = TravelTestClock.cal

    func testFirstTapStartsSecondTapEndsThirdTapRestarts() {
        var s = TripDateRangeSelection()
        s.tap(at(2027, 5, 10, 15), calendar: cal)
        XCTAssertEqual(s.start, at(2027, 5, 10), "시각은 버리고 그날 0시")
        XCTAssertNil(s.end)
        XCTAssertFalse(s.isComplete)
        s.tap(at(2027, 5, 14), calendar: cal)
        XCTAssertEqual(s.start, at(2027, 5, 10))
        XCTAssertEqual(s.end, at(2027, 5, 14))
        XCTAssertTrue(s.isComplete)
        s.tap(at(2027, 5, 21), calendar: cal)
        XCTAssertEqual(s.start, at(2027, 5, 21))
        XCTAssertNil(s.end)
    }

    func testSecondTapBeforeStartBecomesNewStart() {
        var s = TripDateRangeSelection(start: at(2027, 5, 10), end: nil)
        s.tap(at(2027, 5, 6), calendar: cal)
        XCTAssertEqual(s.start, at(2027, 5, 6))
        XCTAssertNil(s.end)
    }

    func testSameDayTwiceIsDayTrip() {
        var s = TripDateRangeSelection()
        s.tap(at(2027, 5, 10), calendar: cal)
        s.tap(at(2027, 5, 10), calendar: cal)
        XCTAssertEqual(s.end, at(2027, 5, 10))
        XCTAssertTrue(s.isComplete)
    }

    func testRoleOfEachDay() {
        let s = TripDateRangeSelection(start: at(2027, 5, 10), end: at(2027, 5, 14))
        XCTAssertEqual(s.role(of: at(2027, 5, 10), calendar: cal), .start)
        XCTAssertEqual(s.role(of: at(2027, 5, 12), calendar: cal), .inside)
        XCTAssertEqual(s.role(of: at(2027, 5, 14), calendar: cal), .end)
        XCTAssertEqual(s.role(of: at(2027, 5, 15), calendar: cal), .none)
        XCTAssertEqual(TripDateRangeSelection(start: at(2027, 5, 10), end: at(2027, 5, 10)).role(of: at(2027, 5, 10), calendar: cal), .single)
        XCTAssertEqual(TripDateRangeSelection(start: at(2027, 5, 10), end: nil).role(of: at(2027, 5, 10), calendar: cal), .single)
    }
}

final class TripDateRangeTextTests: XCTestCase {
    private let cal = TravelTestClock.cal

    func testNightsAndDays() {
        XCTAssertEqual(TripDateRangeText.nightsDays(start: at(2027, 5, 10), end: at(2027, 5, 14), calendar: cal), "4박 5일")
        XCTAssertEqual(TripDateRangeText.nightsDays(start: at(2027, 5, 10), end: at(2027, 5, 11), calendar: cal), "1박 2일")
        XCTAssertEqual(TripDateRangeText.nightsDays(start: at(2027, 5, 10), end: at(2027, 5, 10), calendar: cal), "당일")
    }

    func testSpan() {
        XCTAssertEqual(TripDateRangeText.span(start: at(2027, 5, 10), end: at(2027, 5, 14), calendar: cal), "5.10(월) – 5.14(금)")
    }
}

// MARK: - 여행지 — Trip.city 는 「·」로 이은 글자 그대로(저장 모양 안 바꿈)

final class TripCityListTests: XCTestCase {
    func testSplitTrimsDropsBlanksAndDuplicates() {
        XCTAssertEqual(TripCityList.split(" 오사카 · 교토 ·· 오사카 "), ["오사카", "교토"])
        XCTAssertEqual(TripCityList.split(""), [])
        XCTAssertEqual(TripCityList.split("오사카, 교토"), ["오사카", "교토"])
    }

    func testJoin() {
        XCTAssertEqual(TripCityList.join(["오사카", " 교토 ", "", "오사카"]), "오사카·교토")
    }

    func testAdding() {
        XCTAssertEqual(TripCityList.adding(" 교토 ", to: ["오사카"]), ["오사카", "교토"])
        XCTAssertEqual(TripCityList.adding("오사카", to: ["오사카"]), ["오사카"])
        XCTAssertEqual(TripCityList.adding("  ", to: ["오사카"]), ["오사카"])
    }

    func testSuggestionsSkipChosen() {
        let s = TripCityList.suggestions(excluding: ["오사카", "교토"])
        XCTAssertEqual(s.first, "도쿄")
        XCTAssertFalse(s.contains("오사카"))
        XCTAssertEqual(TripCityList.suggestions(excluding: []).count, 10)
    }
}

// MARK: - 달력 한 달 — 일요일 시작 · 1일 앞 빈칸

final class TripMonthGridTests: XCTestCase {
    private let cal = TravelTestClock.cal

    func testNovember2026StartsOnSunday() {
        let cells = TripMonthGrid.cells(month: at(2026, 11, 20), calendar: cal)
        XCTAssertEqual(cells.count, 30)
        XCTAssertEqual(cells.first ?? nil, at(2026, 11, 1))
        XCTAssertEqual(cells.last ?? nil, at(2026, 11, 30))
    }

    func testDecember2026HasTwoLeadingBlanks() {
        let cells = TripMonthGrid.cells(month: at(2026, 12, 1), calendar: cal)
        XCTAssertEqual(cells.prefix(2).filter { $0 == nil }.count, 2)
        XCTAssertEqual(cells[2], at(2026, 12, 1))
        XCTAssertEqual(cells.count, 33)
    }

    func testTitleAndShift() {
        XCTAssertEqual(TripMonthGrid.title(at(2026, 11, 20), calendar: cal), "2026년 11월")
        XCTAssertEqual(TripMonthGrid.shift(at(2026, 11, 20), by: 1, calendar: cal), at(2026, 12, 1))
        XCTAssertEqual(TripMonthGrid.shift(at(2026, 1, 15), by: -1, calendar: cal), at(2025, 12, 1))
    }
}

final class TripEditFormTests: XCTestCase {
    func testCanSaveNeedsCityAndBothDates() {
        let full = TripDateRangeSelection(start: at(2027, 5, 10), end: at(2027, 5, 14))
        XCTAssertTrue(TripEditForm.canSave(cities: ["오사카"], selection: full))
        XCTAssertFalse(TripEditForm.canSave(cities: [], selection: full))
        XCTAssertFalse(TripEditForm.canSave(cities: ["오사카"], selection: TripDateRangeSelection(start: at(2027, 5, 10), end: nil)))
        XCTAssertFalse(TripEditForm.canSave(cities: ["오사카"], selection: TripDateRangeSelection()))
    }
}
