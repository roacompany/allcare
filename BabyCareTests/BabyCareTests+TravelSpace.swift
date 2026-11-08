import XCTest
import SwiftUI
import UIKit
@testable import BabyCare

// MARK: - 여행 공간(빌드 110 · 설계 2026-11-05) — 홈 요약 · 담당 · 아이 문구 · 알림 켜고 끄기

private enum TS {
    static let cal = TravelTestClock.cal
    static func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date { TravelTestClock.at(y, m, d, h, mi) }

    static func task(_ id: String, key: TripRuleKey = .bassinet, recommended: Date, deadlines: [Date] = []) -> TripTask {
        TripTask(id: id, key: key, title: id, detail: nil,
                 deadlines: deadlines.enumerated().map { TripDeadline(label: "마감\($0.offset)", at: $0.element) },
                 recommendedOn: recommended, childNote: nil, childNoteIsAlert: false, bookingId: nil)
    }

    static func done(_ id: String, _ assignee: TripAssignee? = nil) -> TripTaskState {
        TripTaskState(taskId: id, isDone: true, assignee: assignee)
    }

    static func assigned(_ id: String, _ assignee: TripAssignee) -> TripTaskState {
        TripTaskState(taskId: id, isDone: false, assignee: assignee)
    }
}

final class TravelHomeSummaryTests: XCTestCase {
    private let today = TS.at(2027, 5, 6, 10, 0)

    private func summary(_ tasks: [TripTask], _ states: [TripTaskState] = []) -> TravelHomeSummary {
        TravelHomeSummary.build(tasks: TripTaskOrdering.ordered(tasks, states: states), states: states, today: today, calendar: TS.cal)
    }

    // 다음 할 일 = 안 끝난 일 중 마감이 가장 가까운 것(권장일 순서가 아니라)
    func testNextIsTheOpenTaskWithTheNearestUpcomingDeadline() {
        let s = summary([
            TS.task("a", recommended: TS.at(2027, 5, 6), deadlines: [TS.at(2027, 5, 9, 15, 10)]),
            TS.task("b", recommended: TS.at(2027, 5, 7), deadlines: [TS.at(2027, 5, 8, 15, 10)]),
            TS.task("c", recommended: TS.at(2027, 5, 5))
        ])
        XCTAssertEqual(s.next?.id, "b")
    }

    // 끝난 일과 이미 지난 마감은 「다음」이 아니다
    func testNextSkipsDoneTasksAndPassedDeadlines() {
        let s = summary([
            TS.task("a", recommended: TS.at(2027, 5, 2), deadlines: [TS.at(2027, 5, 5, 9, 0)]),
            TS.task("b", recommended: TS.at(2027, 5, 3), deadlines: [TS.at(2027, 5, 7, 9, 0)]),
            TS.task("d", recommended: TS.at(2027, 5, 4), deadlines: [TS.at(2027, 5, 11, 9, 0)])
        ], [TS.done("b")])
        XCTAssertEqual(s.next?.id, "d")
    }

    // 다가오는 마감이 하나도 없으면 권장일 순 첫째
    func testNextFallsBackToFirstOpenTaskWithoutUpcomingDeadline() {
        let s = summary([
            TS.task("late", recommended: TS.at(2027, 5, 8)),
            TS.task("early", recommended: TS.at(2027, 5, 5))
        ])
        XCTAssertEqual(s.next?.id, "early")
    }

    // 이번 주 할 일 = 다음 할 일을 뺀 안 끝난 일 · 순서 그대로 · 3개까지
    func testWeekExcludesNextKeepsOrderAndLimitsToThree() {
        let s = summary([
            TS.task("n", recommended: TS.at(2027, 5, 9), deadlines: [TS.at(2027, 5, 7, 9, 0)]),
            TS.task("w1", recommended: TS.at(2027, 5, 5)),
            TS.task("w2", recommended: TS.at(2027, 5, 6)),
            TS.task("w3", recommended: TS.at(2027, 5, 7)),
            TS.task("w4", recommended: TS.at(2027, 5, 8))
        ])
        XCTAssertEqual(s.next?.id, "n")
        XCTAssertEqual(s.week.map(\.id), ["w1", "w2", "w3"])
        XCTAssertEqual(s.openCount, 5)
    }

    // 7일 안에 할 일만 — 권장일이 멀어도 마감이 7일 안이면 넣는다
    func testWeekIncludesOnlyTasksDueWithinSevenDays() {
        let s = summary([
            TS.task("n", recommended: TS.at(2027, 5, 6), deadlines: [TS.at(2027, 5, 7, 9, 0)]),
            TS.task("far", recommended: TS.at(2027, 5, 21)),
            TS.task("dueSoon", recommended: TS.at(2027, 5, 21), deadlines: [TS.at(2027, 5, 12, 23, 0)]),
            TS.task("edge", recommended: TS.at(2027, 5, 13))
        ])
        XCTAssertEqual(s.week.map(\.id), ["dueSoon"])
    }

    // 남은 수는 끝난 일을 뺀다 · 다 끝나면 다음 할 일이 없다
    func testAllDoneLeavesNothing() {
        let s = summary([TS.task("a", recommended: TS.at(2027, 5, 6))], [TS.done("a")])
        XCTAssertNil(s.next)
        XCTAssertEqual(s.week, [])
        XCTAssertEqual(s.openCount, 0)
    }
}

final class TravelAssigneeTests: XCTestCase {
    private let tasks = ["a", "b", "c", "d", "e", "f"].map { TS.task($0, recommended: TS.at(2027, 5, 6)) }
    private let states = [TS.assigned("a", .mother), TS.assigned("b", .father), TS.assigned("c", .both),
                          TS.assigned("d", .unknown), TS.done("f", .mother)]

    // 안 끝난 일만 센다 · 정하지 않았거나 모르는 담당은 「담당 없음」
    func testCountsOpenTasksByAssigneeWithMissingAsUnassigned() {
        let counts = TravelAssigneeSplit.counts(tasks: tasks, states: states)
        XCTAssertEqual(counts[.mother], 1)
        XCTAssertEqual(counts[.father], 1)
        XCTAssertEqual(counts[.both], 1)
        XCTAssertEqual(counts[.unassigned], 2)
        XCTAssertNil(counts[.unknown])
    }

    func testUnassignedOpenTasksKeepOrder() {
        XCTAssertEqual(TravelAssigneeSplit.unassignedOpen(tasks: tasks, states: states).map(\.id), ["d", "e"])
    }

    // 거르기는 끝난 일도 담당대로 남긴다(할 일 칸은 끝난 일을 아래에 보여 준다)
    func testFilterKeepsTasksOfThatAssigneeIncludingDone() {
        XCTAssertEqual(TripAssigneeFilter.mother.apply(tasks, states: states).map(\.id), ["a", "f"])
        XCTAssertEqual(TripAssigneeFilter.unassigned.apply(tasks, states: states).map(\.id), ["d", "e"])
        XCTAssertEqual(TripAssigneeFilter.all.apply(tasks, states: states).map(\.id), ["a", "b", "c", "d", "e", "f"])
    }

    func testFilterLabelsMatchDesign() {
        XCTAssertEqual(TripAssigneeFilter.allCases.map(\.label), ["전체", "엄마", "아빠", "함께", "담당 없음"])
    }
}

final class TravelChildTextTests: XCTestCase {
    // 출발일 월령 = 그날까지 꽉 채운 달 수
    func testMonthsAtDeparture() {
        XCTAssertEqual(TravelChildText.months(at: TS.at(2027, 5, 10), birthDate: TS.at(2026, 8, 30), calendar: TS.cal), 8)
        // 출발일(10일) 다음 날이 생일 — 여덟째 달을 아직 다 못 채웠다
        XCTAssertEqual(TravelChildText.months(at: TS.at(2027, 5, 10), birthDate: TS.at(2026, 9, 11), calendar: TS.cal), 7)
    }

    func testClock() {
        XCTAssertEqual(TravelChildText.clock(580), "09:40")
        XCTAssertEqual(TravelChildText.clock(0), "00:00")
        XCTAssertEqual(TravelChildText.clock(1230), "20:30")
    }

    func testNaps() {
        let blocks = [BabyRhythm.Block(startMinute: 580, minutes: 70, share: 1.0),
                      BabyRhythm.Block(startMinute: 850, minutes: 80, share: 0.86)]
        XCTAssertEqual(TravelChildText.naps(blocks), "09:40부터 70분, 14:10부터 80분")
        XCTAssertNil(TravelChildText.naps([]))
    }

    func testSleep() {
        XCTAssertEqual(TravelChildText.sleep(bedtime: 1210, wake: 410), "20:10에 자고 06:50에 깨요")
        XCTAssertEqual(TravelChildText.sleep(bedtime: 1210, wake: nil), "20:10에 자요")
        XCTAssertEqual(TravelChildText.sleep(bedtime: nil, wake: 410), "06:50에 깨요")
        XCTAssertNil(TravelChildText.sleep(bedtime: nil, wake: nil))
    }

    func testFeedInterval() {
        XCTAssertEqual(TravelChildText.feedInterval(230), "낮 수유 약 3시간 50분마다")
        XCTAssertEqual(TravelChildText.feedInterval(180), "낮 수유 약 3시간마다")
        XCTAssertEqual(TravelChildText.feedInterval(45), "낮 수유 약 45분마다")
        XCTAssertNil(TravelChildText.feedInterval(nil))
    }

    func testCoverage() {
        XCTAssertEqual(TravelChildText.coverage(daysWithRecords: 7), "7일 모두 기록이 있어요")
        XCTAssertEqual(TravelChildText.coverage(daysWithRecords: 3), "7일 중 3일 기록이 있어요")
        XCTAssertEqual(TravelChildText.coverage(daysWithRecords: 0), "최근 7일 기록이 없어요")
    }
}

final class TripReminderOptionsTests: XCTestCase {
    private func reminders(_ options: TripReminderOptions) -> [TripReminder] {
        let now = TS.at(2027, 5, 2, 10, 0)
        let trip = TravelFixtures.osakaTrip()
        let child = TripChildContext(birthDate: TS.at(2026, 8, 30), heightCm: 70.5, weightKg: 8.4, meat: .present, hasSolids: true)
        let tasks = TripTaskEngine.tasks(trip: trip, child: child, now: now, calendar: TS.cal)
        return TripReminderPlanner.reminders(trip: trip, tasks: tasks, states: [], now: now, calendar: TS.cal, options: options)
    }

    func testThreeDaysBeforeOffKeepsOnlyDayBefore() {
        let list = reminders(TripReminderOptions(threeDaysBefore: false, dayBefore: true))
        XCTAssertFalse(list.isEmpty)
        XCTAssertTrue(list.allSatisfy { $0.identifier.hasSuffix("-d1") })
    }

    func testDayBeforeOffKeepsOnlyThreeDaysBefore() {
        let list = reminders(TripReminderOptions(threeDaysBefore: true, dayBefore: false))
        XCTAssertFalse(list.isEmpty)
        XCTAssertTrue(list.allSatisfy { $0.identifier.hasSuffix("-d3") })
    }

    func testBothOffGivesNoReminders() {
        XCTAssertEqual(reminders(TripReminderOptions(threeDaysBefore: false, dayBefore: false)), [])
    }

    func testDefaultKeepsBoth() {
        let ids = reminders(.all).map(\.identifier)
        XCTAssertTrue(ids.contains { $0.hasSuffix("-d3") })
        XCTAssertTrue(ids.contains { $0.hasSuffix("-d1") })
    }

    // 이 폰에만 저장 · 처음엔 둘 다 켜짐 · 다시 열어도 그대로
    @MainActor
    func testPreferencesDefaultOnAndPersist() {
        let suite = "travel-reminder-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = TripReminderPreferences(defaults: defaults)
        XCTAssertEqual(first.options, .all)
        first.options = TripReminderOptions(threeDaysBefore: false, dayBefore: true)
        XCTAssertEqual(TripReminderPreferences(defaults: defaults).options, TripReminderOptions(threeDaysBefore: false, dayBefore: true))
    }
}

@MainActor
final class TravelSpaceViewModelTests: XCTestCase {
    private func detail(scheduler: MockTripReminderScheduler, childData: MockTripChildData = MockTripChildData(),
                        preferences: TripReminderPreferencesStoring) -> TripDetailViewModel {
        TripDetailViewModel(trip: TravelFixtures.osakaTrip(), ownerUserId: "o", currentUserId: "p",
                            babyBirthDate: TS.at(2026, 8, 30), provider: MockTripFirestore(), childData: childData,
                            reminders: scheduler, reminderPreferences: preferences,
                            now: { TS.at(2027, 5, 2, 10, 0) }, calendar: TS.cal)
    }

    private final class MemoryPreferences: TripReminderPreferencesStoring {
        var options: TripReminderOptions = .all
    }

    // 키·체중은 잰 날과 함께 — 아이 칸이 「키 70.5cm, 4.3 측정」을 쓴다
    func testLatestGrowthKeepsMeasurementDates() async {
        let childData = MockTripChildData()
        childData.growth = [GrowthRecord(babyId: "b1", date: TS.at(2027, 4, 3), height: 70.5),
                            GrowthRecord(babyId: "b1", date: TS.at(2027, 4, 15), weight: 8.4),
                            GrowthRecord(babyId: "b1", date: TS.at(2027, 3, 2), height: 66, weight: 7.6)]
        let vm = detail(scheduler: MockTripReminderScheduler(), childData: childData, preferences: MemoryPreferences())
        await vm.loadChild()
        XCTAssertEqual(vm.latestHeight, TripGrowthReading(value: 70.5, measuredOn: TS.at(2027, 4, 3)))
        XCTAssertEqual(vm.latestWeight, TripGrowthReading(value: 8.4, measuredOn: TS.at(2027, 4, 15)))
    }

    // 알림을 끄면 바로 다시 걸고, 끈 종류는 빠진다 · 설정은 이 폰에 남는다
    func testTurningOffThreeDaysBeforeReplansWithoutIt() async {
        let scheduler = MockTripReminderScheduler()
        let prefs = MemoryPreferences()
        let vm = detail(scheduler: scheduler, preferences: prefs)
        await vm.setReminderOptions(TripReminderOptions(threeDaysBefore: false, dayBefore: true))
        XCTAssertEqual(prefs.options, TripReminderOptions(threeDaysBefore: false, dayBefore: true))
        XCTAssertEqual(vm.reminderOptions, TripReminderOptions(threeDaysBefore: false, dayBefore: true))
        let last = scheduler.replaced.last?.reminders ?? []
        XCTAssertFalse(last.isEmpty)
        XCTAssertTrue(last.allSatisfy { $0.identifier.hasSuffix("-d1") })
    }
}

// MARK: - 그려 보기 — 여행 공간 칸들(로그인 없이 목으로 · /tmp/babycare_screenshots/travel_*.png)

@MainActor
final class TravelSpaceRenderTests: XCTestCase {
    private let dir = "/tmp/babycare_screenshots"

    private func model() async -> TripDetailViewModel {
        let childData = MockTripChildData()
        childData.activities = RhythmFixtures.week()
        childData.growth = [GrowthRecord(babyId: "b1", date: TravelTestClock.at(2027, 4, 3), height: 70.5),
                            GrowthRecord(babyId: "b1", date: TravelTestClock.at(2027, 4, 15), weight: 8.4)]
        let vm = TripDetailViewModel(trip: TravelFixtures.osakaTrip(), ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: TravelTestClock.at(2026, 8, 30),
                                     provider: MockTripFirestore(), childData: childData,
                                     reminders: MockTripReminderScheduler(),
                                     now: { TravelTestClock.at(2027, 5, 6, 10, 0) }, calendar: TravelTestClock.cal)
        await vm.loadChild()
        if let first = vm.tasks.first { await vm.setAssignee(.mother, for: first.id) }
        if vm.tasks.count > 1 { await vm.setAssignee(.father, for: vm.tasks[1].id) }
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

    private func save(_ image: UIImage, _ name: String) throws {
        XCTAssertGreaterThan(image.size.height, 0)
        try image.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    func testTravelSpaceScreensRender() async throws {
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let vm = await model()
        try save(render(NavigationStack {
            TravelHomeView(vm: vm, trips: [vm.trip], onSelect: { _ in }, onCreate: {}, onDelete: { _ in },
                           onShowSchedule: { _ in }, onShowTasks: {}, onShowChild: {})
                .navigationBarTitleDisplayMode(.inline)
        }, height: 1500), "travel_home")
        try save(render(NavigationStack { TravelChildView(vm: vm).navigationBarTitleDisplayMode(.inline) }, height: 1300), "travel_child")
        try save(render(NavigationStack {
            TravelPrepView(vm: vm, section: .constant(.tasks), filter: .constant(.all)).navigationBarTitleDisplayMode(.inline)
        }, height: 1700), "travel_prep_tasks")
        try save(render(NavigationStack { TravelEmptyView(canCreate: true, onCreate: {}).navigationTitle("") }, height: 844), "travel_empty")
        try save(render(MoreTabView(selection: .constant(nil)), height: 844), "more_list")
    }
}

// MARK: - 새 눈 검토 고침(11/5) — 알림 끄기는 모든 여행에 · 지운 여행 알림을 다시 걸지 않는다

@MainActor
final class TravelReviewFixTests: XCTestCase {
    private final class MemoryPreferences: TripReminderPreferencesStoring {
        var options: TripReminderOptions = .all
    }

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // 「이 폰에만」 설정이라 끈 종류는 열지 않은 다른 여행에서도 빠져야 한다 → 그 종류를 한꺼번에 지운다
    func testTurningOffAKindClearsItFromEveryTrip() async {
        let scheduler = MockTripReminderScheduler()
        let vm = TripDetailViewModel(trip: TravelFixtures.osakaTrip(), ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: TS.at(2026, 8, 30), provider: MockTripFirestore(), childData: MockTripChildData(),
                                     reminders: scheduler, reminderPreferences: MemoryPreferences(),
                                     now: { TS.at(2027, 5, 2, 10, 0) }, calendar: TS.cal)
        await vm.setReminderOptions(TripReminderOptions(threeDaysBefore: false, dayBefore: true))
        XCTAssertEqual(scheduler.cancelledKinds, ["d3"])
        await vm.setReminderOptions(TripReminderOptions(threeDaysBefore: true, dayBefore: true))
        XCTAssertEqual(scheduler.cancelledKinds, ["d3"], "켤 때는 지우지 않는다")
        await vm.setReminderOptions(TripReminderOptions(threeDaysBefore: true, dayBefore: false))
        XCTAssertEqual(scheduler.cancelledKinds, ["d3", "d1"])
    }

    // 아이 기록 읽기가 지우기보다 늦게 끝나도 지운 여행의 알림을 다시 걸지 않는다
    func testLateChildLoadAfterDeletionDoesNotRearmReminders() async {
        let store = MockTripFirestore()
        store.seed([TravelFixtures.osakaTrip()], userId: "o", babyId: "b1")
        let scheduler = MockTripReminderScheduler()
        let vm = TripDetailViewModel(trip: TravelFixtures.osakaTrip(), ownerUserId: "o", currentUserId: "p",
                                     babyBirthDate: TS.at(2026, 8, 30), provider: store, childData: MockTripChildData(),
                                     reminders: scheduler, reminderPreferences: MemoryPreferences(),
                                     now: { TS.at(2027, 5, 2, 10, 0) }, calendar: TS.cal)
        let watching = Task { await vm.observe() }
        await eventually { !scheduler.replaced.isEmpty }
        try? await store.deleteTrip("t1", userId: "o", babyId: "b1")
        await eventually { vm.isDeleted }
        let armedBefore = scheduler.replaced.count
        await vm.loadChild()
        XCTAssertEqual(scheduler.replaced.count, armedBefore, "지운 여행의 알림을 다시 걸면 지울 길이 없다")
        watching.cancel()
    }
}

// MARK: - 짜임 바꿈(캔버스 Version 84 · PO 11/6 「네 시안.」) — 아래 바 홈·일정·예약·준비 · 홈 「다음 일정」

final class TravelTabStructureTests: XCTestCase {
    func testBottomBarIsHomePlanBookingsPrep() {
        XCTAssertEqual(TravelTab.allCases, [.home, .plan, .bookings, .prep])
        XCTAssertEqual(TravelTab.allCases.map(\.title), ["홈", "일정", "예약", "준비"])
        XCTAssertEqual(TravelTab.allCases.map(\.rawValue), ["home", "plan", "bookings", "prep"], "UI 테스트 식별자 travel.tab.<rawValue>")
    }

    // 없는 기호 이름이면 빈칸으로 그려진다 — 이름이 실제로 있는지 잰다
    func testEveryTabIconExists() {
        for tab in TravelTab.allCases {
            XCTAssertNotNil(UIImage(systemName: tab.icon), tab.icon)
        }
    }

    func testPrepHasTasksThenRules() {
        XCTAssertEqual(TravelPrepSection.allCases.map(\.title), ["할 일", "규칙"])
    }
}

final class TripHeaderTextTests: XCTestCase {
    private let trip = TravelFixtures.osakaTrip()

    func testBadgeBeforeOnDuringAfter() {
        XCTAssertEqual(TripHeaderText.badge(trip, today: TS.at(2027, 4, 19, 10), calendar: TS.cal), "D-21")
        XCTAssertEqual(TripHeaderText.badge(trip, today: TS.at(2027, 5, 9, 23, 59), calendar: TS.cal), "D-1")
        XCTAssertEqual(TripHeaderText.badge(trip, today: TS.at(2027, 5, 10, 9, 12), calendar: TS.cal), "오늘 출발")
        XCTAssertEqual(TripHeaderText.badge(trip, today: TS.at(2027, 5, 12, 10), calendar: TS.cal), "여행 3일째")
        XCTAssertEqual(TripHeaderText.badge(trip, today: TS.at(2027, 5, 14, 20), calendar: TS.cal), "여행 5일째")
        XCTAssertEqual(TripHeaderText.badge(trip, today: TS.at(2027, 5, 15, 8), calendar: TS.cal), "다녀왔어요")
    }

    func testHomeDatesAndTabSubtitle() {
        XCTAssertEqual(TripHeaderText.homeDates(trip, calendar: TS.cal), "5.10(월)–5.14(금) · 4박 5일")
        XCTAssertEqual(TripHeaderText.subtitle(trip, calendar: TS.cal), "오사카·교토 · 5.10(월)–5.14(금)")
    }
}

final class TravelHomeScheduleTests: XCTestCase {
    private let cal = TS.cal
    private let kyoto = TripBooking(id: "h2", kind: .hotel, name: "교토 숙소", address: "京都市", checkIn: .at(TS.at(2027, 5, 10, 22, 0)))

    private func move(_ id: String, _ from: String, _ to: String, _ start: Date, _ minutes: Int) -> TripMove {
        TripMove(id: id, startAt: start, minutes: minutes, fromLabel: from, toLabel: to)
    }

    /// 낮잠 09:40 70분 · 14:10 80분 · 밤잠 20:10(RhythmFixtures 와 같은 리듬).
    private func rhythm(naps: [(Int, Int)] = [(580, 70), (850, 80)], bedtime: Int? = 1210) -> BabyRhythm {
        BabyRhythm(naps: naps.map { BabyRhythm.Block(startMinute: $0.0, minutes: $0.1, share: 1) },
                   bedtimeMinute: bedtime, wakeMinute: 410, dayFeedIntervalMin: 230,
                   solids: [], carSeatNaps: 0, daysWithRecords: 7, meat: .absent, hasSolids: false)
    }

    private func firstDay(_ bookings: [TripBooking], moves: [TripMove] = [], rhythm: BabyRhythm? = nil, day: Date = TS.at(2027, 5, 10)) -> [Itinerary.HomeLine] {
        let plan = Itinerary(trip: TravelFixtures.osakaTrip(bookings: bookings, moves: moves), rhythm: rhythm, calendar: cal)
        return plan.days.first { $0.date == day }?.homeLines ?? []
    }

    func testFocusDayIsFirstDayBeforeTodayDuringNoneAfter() {
        let days = TravelFixtures.osakaTrip().days(calendar: cal)
        XCTAssertEqual(TravelHomeSchedule.focusDay(days: days, today: TS.at(2027, 4, 19, 10), calendar: cal), TS.at(2027, 5, 10))
        XCTAssertEqual(TravelHomeSchedule.focusDay(days: days, today: TS.at(2027, 5, 12, 10), calendar: cal), TS.at(2027, 5, 12))
        XCTAssertNil(TravelHomeSchedule.focusDay(days: days, today: TS.at(2027, 5, 15, 8), calendar: cal))
    }

    func testTitleSaysNextOrTodayWithDayNumber() {
        let days = TravelFixtures.osakaTrip().days(calendar: cal)
        XCTAssertEqual(TravelHomeSchedule.title(day: TS.at(2027, 5, 10), days: days, today: TS.at(2027, 4, 19, 10), calendar: cal),
                       "다음 일정 · 1일차 5.10(월)")
        XCTAssertEqual(TravelHomeSchedule.title(day: TS.at(2027, 5, 12), days: days, today: TS.at(2027, 5, 12, 10), calendar: cal),
                       "오늘 일정 · 3일차 5.12(수)")
    }

    func testTaskTitleBeforeAndFromDeparture() {
        let days = TravelFixtures.osakaTrip().days(calendar: cal)
        XCTAssertEqual(TravelHomeSchedule.taskTitle(days: days, today: TS.at(2027, 5, 9, 23), calendar: cal), "출발 전 할 일")
        XCTAssertEqual(TravelHomeSchedule.taskTitle(days: days, today: TS.at(2027, 5, 10, 6), calendar: cal), "남은 할 일")
    }

    // 아기 리듬(낮잠·수유·이유식) 줄은 일정 칸에만 — 홈은 예약·이동만
    func testRowsAreBookingsAndMovesOnly() {
        let rows = firstDay([TravelFixtures.outbound(), TravelFixtures.inbound(), TravelFixtures.car, kyoto, TravelFixtures.hotel],
                            moves: [move("m1", "간사이공항", "교토 숙소", TS.at(2027, 5, 10, 18, 30), 90)], rhythm: rhythm())
        XCTAssertEqual(rows.map(\.title), ["KE725 인천 → 간사이", "렌터카 인수", "간사이공항 → 교토 숙소", "교토 숙소 도착"])
        XCTAssertEqual(rows.map(\.detail), ["가는 편 · 17:00 도착", "간사이공항", "약 1시간 30분", "체크인 22:00부터"])
        XCTAssertEqual(rows.map(\.clock), ["15:10", "18:00", "18:30", "20:00"])
    }

    // 체크아웃은 시간대라 반납 앞에 온다(그 숙소를 나서야 차를 돌려준다)
    func testReturnDayShowsCheckoutReturnAndInboundFlight() {
        let rows = firstDay([TravelFixtures.inbound(), TravelFixtures.car, TravelFixtures.hotel], day: TS.at(2027, 5, 14))
        XCTAssertEqual(rows.map(\.title), ["오사카 숙소 체크아웃", "렌터카 반납", "KE724 간사이 → 인천"])
        XCTAssertEqual(rows.map(\.detail), [nil, "간사이공항", "오는 편 · 14:00 도착"])
    }

    // 전날 밤 떠나 이날 내리는 편 — 도착 줄 하나
    func testOvernightFlightShowsArrivalOnNextDay() {
        let late = TripBooking(id: "f9", kind: .flight, airline: "KE", flightNumber: "KE999", fromAirport: "ICN", toAirport: "KIX",
                               depart: .at(TS.at(2027, 5, 10, 23, 0)), arrive: .at(TS.at(2027, 5, 11, 1, 30)))
        XCTAssertEqual(firstDay([late]).map(\.title), ["KE999 인천 → 간사이"])
        let next = firstDay([late], day: TS.at(2027, 5, 11))
        XCTAssertEqual(next.map(\.title), ["KE999 간사이 도착"])
        XCTAssertEqual(next.map(\.detail), ["가는 편"])
    }

    func testChipNapOverlapsBoarding() {
        let rows = firstDay([TravelFixtures.outbound()], rhythm: rhythm())
        XCTAssertEqual(rows.first?.childNote, "낮잠 14:10과 탑승이 겹쳐요")
    }

    func testChipNapOverlapsMove() {
        let rows = firstDay([], moves: [move("m1", "숙소", "공원", TS.at(2027, 5, 10, 13, 30), 60)], rhythm: rhythm())
        XCTAssertEqual(rows.first?.childNote, "낮잠 14:10과 이동이 겹쳐요")
    }

    func testChipBedtimeDuringMoveOrFlight() {
        let drive = firstDay([], moves: [move("m1", "간사이공항", "교토 숙소", TS.at(2027, 5, 10, 19, 30), 60)], rhythm: rhythm())
        XCTAssertEqual(drive.first?.childNote, "밤잠 20:10 — 이동 중이에요")
        let evening = TripBooking(id: "f8", kind: .flight, airline: "KE", flightNumber: "KE723", fromAirport: "ICN", toAirport: "KIX",
                                  depart: .at(TS.at(2027, 5, 10, 19, 30)), arrive: .at(TS.at(2027, 5, 10, 21, 30)))
        XCTAssertEqual(firstDay([evening], rhythm: rhythm()).first?.childNote, "밤잠 20:10 — 비행 중이에요")
    }

    func testChipPickupOrMoveNearBedtime() {
        let car = TripBooking(id: "c2", kind: .rentalCar, pickupPlace: "간사이공항", pickup: .at(TS.at(2027, 5, 10, 19, 50)))
        XCTAssertEqual(firstDay([car], rhythm: rhythm()).first?.childNote, "밤잠 20:10 무렵이에요")
        // 18:30에 떠나 20:00에 닿는 운전 — 밤잠 20:10 앞뒤에 걸친다
        let drive = firstDay([], moves: [move("m1", "간사이공항", "교토 숙소", TS.at(2027, 5, 10, 18, 30), 90)], rhythm: rhythm())
        XCTAssertEqual(drive.first?.childNote, "밤잠 20:10 무렵이에요")
    }

    func testNoChipWhenNothingTouchesSleep() {
        let rows = firstDay([TravelFixtures.car, kyoto], rhythm: rhythm())
        XCTAssertEqual(rows.map(\.childNote), [nil, nil], "18:00 인수 · 22:00 체크인은 밤잠 20:10 앞뒤(20분·60분) 밖")
        XCTAssertEqual(firstDay([TravelFixtures.outbound()], rhythm: nil).first?.childNote, nil, "아이 기록이 없으면 칩도 없다")
    }

    func testAtMostFiveRows() {
        let moves = (0..<7).map { move("m\($0)", "가", "나", TS.at(2027, 5, 10, 9 + $0, 0), 30) }
        XCTAssertEqual(firstDay([], moves: moves).count, 5)
    }

    func testTodayFlightIsOnlyTheFlightDepartingToday() {
        let trip = TravelFixtures.osakaTrip()
        XCTAssertNil(TravelHomeSchedule.todayFlight(in: trip, today: TS.at(2027, 4, 19, 10), calendar: cal))
        XCTAssertEqual(TravelHomeSchedule.todayFlight(in: trip, today: TS.at(2027, 5, 10, 9, 12), calendar: cal)?.id, "f1")
        XCTAssertNil(TravelHomeSchedule.todayFlight(in: trip, today: TS.at(2027, 5, 12, 9), calendar: cal))
        XCTAssertEqual(TravelHomeSchedule.todayFlight(in: trip, today: TS.at(2027, 5, 14, 8), calendar: cal)?.id, "f2")
    }

    // 홈 할 일 = 다음 할 일 + 이번 주, 앞 3개
    func testHomeTaskRowsAreNextThenWeekUpToThree() {
        let day = TS.at(2027, 5, 6, 10)
        let tasks = (1...5).map { TS.task("t\($0)", recommended: TS.at(2027, 5, 6 + $0), deadlines: [TS.at(2027, 5, 7 + $0)]) }
        let summary = TravelHomeSummary.build(tasks: tasks, states: [], today: day, calendar: cal)
        XCTAssertEqual(summary.homeRows.map(\.id), ["t1", "t2", "t3"])
        XCTAssertEqual(TravelHomeSummary.build(tasks: [], states: [], today: day, calendar: cal).homeRows, [])
    }

    // 출발 3주 전 — 이번 주 일이 없어도 3개를 채운다(가장 가까운 마감 → 준비 칸과 같은 화면 순서) · 끝난 일은 빼고
    func testHomeTaskRowsFillFromScreenOrderWhenWeekIsEmpty() {
        let day = TS.at(2027, 4, 19, 10)
        let tasks = [
            TS.task("a", recommended: TS.at(2027, 4, 27), deadlines: [TS.at(2027, 5, 8, 15, 10)]),
            TS.task("b", recommended: TS.at(2027, 4, 28), deadlines: [TS.at(2027, 5, 7, 18)]),
            TS.task("c", recommended: TS.at(2027, 4, 29), deadlines: [TS.at(2027, 5, 9, 15, 10)]),
            TS.task("d", recommended: TS.at(2027, 5, 4))
        ]
        let summary = TravelHomeSummary.build(tasks: tasks, states: [], today: day, calendar: cal)
        XCTAssertTrue(summary.week.isEmpty)
        XCTAssertEqual(summary.homeRows.map(\.id), ["b", "a", "c"])
        let afterA = TravelHomeSummary.build(tasks: tasks, states: [TS.done("a")], today: day, calendar: cal)
        XCTAssertEqual(afterA.homeRows.map(\.id), ["b", "c", "d"])
    }
}
