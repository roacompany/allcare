import XCTest
import SwiftUI
import UIKit
@testable import BabyCare

// MARK: - 여행 공간 모양을 Dev 시안에 맞춤(11/5 PO 「Dev와 같은 디자인인거지 지금???」) — 화면이 쓰는 순수 판정

private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }

private func task(_ id: String, _ recommended: Date) -> TripTask {
    TripTask(id: id, key: .bassinet, title: id, detail: nil, deadlines: [], recommendedOn: recommended,
             childNote: nil, childNoteIsAlert: false, bookingId: nil)
}

/// 시안 「여행: 할 일」 — 월요일 시작 주로 묶어 「이번 주 · 다음 주 · 출발 전 주」(+ 날짜 범위).
final class TripTaskWeekGroupsTests: XCTestCase {
    private let cal = TravelTestClock.cal

    func testGroupsByMondayWeekWithBoardTitles() {
        let groups = TripTaskWeekGroups.build(
            tasks: [task("a", at(2027, 4, 21)), task("b", at(2027, 4, 27)), task("c", at(2027, 5, 4)), task("d", at(2027, 5, 11))],
            today: at(2027, 4, 19, 10), tripStart: at(2027, 5, 10), calendar: cal)
        XCTAssertEqual(groups.map(\.title), ["이번 주", "다음 주", "출발 전 주", "여행 중"])
        XCTAssertEqual(groups.map(\.range), ["4.19–4.25", "4.26–5.2", "5.3–5.9", "5.10–5.16"])
        XCTAssertEqual(groups.map { $0.tasks.map(\.id) }, [["a"], ["b"], ["c"], ["d"]])
    }

    // 권장일이 지난 일은 이번 주 맨 위에 — 늦은 일이 아래로 숨지 않게
    func testOverdueGoesIntoThisWeekKeepingOrder() {
        let groups = TripTaskWeekGroups.build(tasks: [task("late", at(2027, 4, 14)), task("now", at(2027, 4, 20))],
                                              today: at(2027, 4, 19, 10), tripStart: at(2027, 5, 10), calendar: cal)
        XCTAssertEqual(groups.map(\.title), ["이번 주"])
        XCTAssertEqual(groups.first?.tasks.map(\.id), ["late", "now"])
    }

    // 다음 주와 출발 전 주 사이는 「N주 뒤」
    func testMiddleWeeksSayHowFarAhead() {
        let groups = TripTaskWeekGroups.build(tasks: [task("x", at(2027, 4, 20)), task("y", at(2027, 4, 27))],
                                              today: at(2027, 4, 5, 10), tripStart: at(2027, 5, 10), calendar: cal)
        XCTAssertEqual(groups.map(\.title), ["2주 뒤", "3주 뒤"])
    }

    // 일요일은 그 주(월요일 시작)의 끝 — 다음 날 월요일이 「다음 주」
    func testSundayClosesTheMondayWeek() {
        let groups = TripTaskWeekGroups.build(tasks: [task("sun", at(2027, 4, 25)), task("mon", at(2027, 4, 26))],
                                              today: at(2027, 4, 25, 21), tripStart: at(2027, 5, 10), calendar: cal)
        XCTAssertEqual(groups.map(\.title), ["이번 주", "다음 주"])
        XCTAssertEqual(groups.first?.range, "4.19–4.25")
    }

    // 출발이 다음 주면 그 앞 주(=이번 주)가 「출발 전 주」가 아니라 「이번 주」
    func testThisWeekWinsOverBeforeDeparture() {
        let groups = TripTaskWeekGroups.build(tasks: [task("a", at(2027, 5, 6))],
                                              today: at(2027, 5, 6, 10), tripStart: at(2027, 5, 10), calendar: cal)
        XCTAssertEqual(groups.map(\.title), ["이번 주"])
    }
}

/// 시안 칩 — 담당이 없으면 빨간 「담당 없음」.
final class TravelAssigneeChipTextTests: XCTestCase {
    func testChipTextAndTone() {
        XCTAssertEqual(TravelAssigneeChipText.text(nil), "담당 없음")
        XCTAssertTrue(TravelAssigneeChipText.isMissing(nil))
        XCTAssertTrue(TravelAssigneeChipText.isMissing(.unknown))
        XCTAssertTrue(TravelAssigneeChipText.isMissing(.unassigned))
        XCTAssertEqual(TravelAssigneeChipText.text(.mother), "엄마")
        XCTAssertFalse(TravelAssigneeChipText.isMissing(.both))
    }
}

// MARK: - 그림 — 여행 칸 네 칸 · 규칙 카드(시안과 나란히 대조용 · /tmp/babycare_screenshots)

/// 그림 테스트가 지도·공항에 실제로 묻지 않게.
private final class NoFlightStatus: FlightStatusProviding, @unchecked Sendable {
    func status(flightId: String, direction: FlightDirection, day: Date) async throws -> FlightLiveStatus? { nil }
}

private final class FixedRoute: RouteTimeProviding, @unchecked Sendable {
    func drivingRoute(from: String, to: String, near area: TripRouteArea) async throws -> RouteEstimate {
        RouteEstimate(minutes: 76, fromName: nil, toName: nil, source: .google)
    }
}

@MainActor
final class TravelLookRenderTests: XCTestCase {
    private let dir = "/tmp/babycare_screenshots"

    private func render<V: View>(_ view: V, height: CGFloat, name: String) throws {
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
        XCTAssertGreaterThan(image.size.height, 0)
        try image.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    func testTripTabsAndRuleCardRender() async throws {
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let childData = MockTripChildData()
        childData.activities = RhythmFixtures.week()
        let vm = TripDetailViewModel(trip: TravelFixtures.osakaTrip(), ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: at(2026, 8, 30), provider: MockTripFirestore(), childData: childData,
                                     reminders: MockTripReminderScheduler(), flightStatus: NoFlightStatus(), routeTime: FixedRoute(),
                                     now: { at(2027, 4, 19, 10, 0) }, calendar: TravelTestClock.cal)
        await vm.loadChild()
        if let first = vm.tasks.first { await vm.setAssignee(.mother, for: first.id) }
        try render(NavigationStack {
            TravelPrepView(vm: vm, section: .constant(.tasks), filter: .constant(.all)).navigationBarTitleDisplayMode(.inline)
        }, height: 1700, name: "look_prep_tasks")
        try render(NavigationStack { TravelPlanView(vm: vm, day: .constant(nil)).navigationBarTitleDisplayMode(.inline) },
                   height: 1700, name: "look_plan")
        try render(NavigationStack { TravelBookingsView(vm: vm).navigationBarTitleDisplayMode(.inline) }, height: 1700, name: "look_bookings")
        try render(NavigationStack {
            TravelPrepView(vm: vm, section: .constant(.rules), filter: .constant(.all)).navigationBarTitleDisplayMode(.inline)
        }, height: 1700, name: "look_prep_rules")
        try render(TripRuleCardSheet(card: TripRuleCatalog.card(.bassinet), childNote: "8개월 · 키 70.5cm — 배시넷 기준 안이에요"),
                   height: 1000, name: "look_rule_card")
    }
}

// MARK: - 그림 대조 — 캔버스 Version 84(PO 11/6 「네 시안.」) 보드 옆에 놓을 앱 화면(/tmp/babycare_screenshots/v84_app_<보드>.png · 아래 바 얹음)

/// 가는 편 1시간 30분 늦음(시안 Home-Flight) — 그림 전용.
private final class DelayedOutbound: FlightStatusProviding, @unchecked Sendable {
    func status(flightId: String, direction: FlightDirection, day: Date) async throws -> FlightLiveStatus? {
        guard direction == .departure else { return nil }
        return FlightLiveStatus(flightId: flightId, direction: direction, scheduled: at(2027, 5, 10, 15, 10),
                                estimated: at(2027, 5, 10, 16, 40), remark: "지연", gate: nil, terminal: "T2",
                                counterpart: "간사이", carousel: nil, exit: nil, fetchedAt: at(2027, 5, 10, 9, 12))
    }
}

@MainActor
final class TravelBoardCompareRenderTests: XCTestCase {
    private let dir = "/tmp/babycare_screenshots"

    private func render<V: View>(_ view: V, height: CGFloat, name: String) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: height)
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.isHidden = false
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        XCTAssertGreaterThan(image.size.height, 0)
        try image.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    /// 보드와 같은 여행 — KE725/KE724 · 렌터카 · 교토 숙소(첫날 22:00) · 오사카 숙소 · 간사이공항 → 교토 숙소 운전 18:30 90분.
    private func trip() -> Trip {
        let kyoto = TripBooking(id: "h2", kind: .hotel, name: "교토 숙소", address: "京都市", checkIn: .at(at(2027, 5, 10, 22, 0)))
        let drive = TripMove(id: "m1", startAt: at(2027, 5, 10, 18, 30), minutes: 90, fromLabel: "간사이공항", toLabel: "교토 숙소")
        return TravelFixtures.osakaTrip(bookings: [TravelFixtures.outbound(), TravelFixtures.inbound(), TravelFixtures.car, kyoto, TravelFixtures.hotel],
                                        moves: [drive])
    }

    /// 리듬 기록을 날짜만 옮긴다(최근 7일 창이 「오늘」을 따라간다).
    private func shifted(_ list: [Activity], days: Int) -> [Activity] {
        let delta = TimeInterval(days * 86_400)
        return list.map { a in
            var b = a
            b.startTime = a.startTime.addingTimeInterval(delta)
            b.endTime = a.endTime.map { $0.addingTimeInterval(delta) }
            return b
        }
    }

    private func model(now: Date, flight: FlightStatusProviding, activities: [Activity]) async -> TripDetailViewModel {
        let childData = MockTripChildData()
        childData.activities = activities
        childData.growth = [GrowthRecord(babyId: "b1", date: at(2027, 4, 3), height: 70.5),
                            GrowthRecord(babyId: "b1", date: at(2027, 4, 15), weight: 8.4)]
        let vm = TripDetailViewModel(trip: trip(), ownerUserId: "o", currentUserId: "p", babyBirthDate: at(2026, 8, 30),
                                     provider: MockTripFirestore(), childData: childData, reminders: MockTripReminderScheduler(),
                                     flightStatus: flight, routeTime: FixedRoute(), now: { now }, calendar: TravelTestClock.cal)
        await vm.loadChild()
        for task in vm.tasks.prefix(2) { await vm.setAssignee(.mother, for: task.id) }
        return vm
    }

    /// 칸 화면 + 아래 바(화면 아래에서 22 위 · 실제 여행 공간과 같은 자리).
    private func framed<V: View>(_ content: V, tab: TravelTab) -> some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                content
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
            }
            TravelBottomBar(tab: .constant(tab), onBack: {})
                .padding(.bottom, TravelBottomBar.screenBottom)
        }
        .background(TravelStyle.page)
    }

    private func home(_ vm: TripDetailViewModel) -> TravelHomeView {
        TravelHomeView(vm: vm, trips: [vm.trip], onSelect: { _ in }, onCreate: {}, onDelete: { _ in }, onDeleteTrip: {},
                       onShowSchedule: { _ in }, onShowTasks: {}, onShowChild: {})
    }

    func testScreensBesideV84Boards() async throws {
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        // 출발 3주 전(4/19 · 보드 「D-21」) — 최근 7일 = 4/12~4/18 기록
        let before = await model(now: at(2027, 4, 19, 10, 0), flight: NoFlightStatus(), activities: shifted(RhythmFixtures.week(), days: -20))
        try render(framed(home(before), tab: .home), height: 1000, name: "v84_app_Main")
        try render(framed(TravelPlanView(vm: before, day: .constant(nil)), tab: .plan), height: 1460, name: "v84_app_Day-Plan")
        try render(framed(TravelBookingsView(vm: before), tab: .bookings), height: 1528, name: "v84_app_Trip-Bookings")
        try render(framed(TravelPrepView(vm: before, section: .constant(.tasks), filter: .constant(.all)), tab: .prep),
                   height: 1560, name: "v84_app_Trip-Todo")
        try render(framed(TravelPrepView(vm: before, section: .constant(.rules), filter: .constant(.all)), tab: .prep),
                   height: 1090, name: "v84_app_Trip-Rules")
        // 아이 — 홈에서 밀어 연 모습(시스템 위 막대 「‹ 홈」)
        try render(ZStack(alignment: .bottom) {
            NavigationStack {
                Color.clear
                    .navigationTitle("홈")
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(isPresented: .constant(true)) {
                        TravelChildView(vm: before)
                            .navigationTitle("")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar(.visible, for: .navigationBar)
                    }
            }
            TravelBottomBar(tab: .constant(.home), onBack: {})
                .padding(.bottom, TravelBottomBar.screenBottom)
        }, height: 844, name: "v84_app_Child")
        // 출발일 아침(5/10 09:12) — 가는 편 1시간 30분 늦음 · 최근 7일 = 5/3~5/9 기록
        let flightDay = await model(now: at(2027, 5, 10, 9, 12), flight: DelayedOutbound(), activities: RhythmFixtures.week(days: 2...8))
        await flightDay.refreshFlightStatus()
        try render(framed(home(flightDay), tab: .home), height: 1500, name: "v84_app_Home-Flight")
    }
}
