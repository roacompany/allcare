import XCTest
@testable import BabyCare

final class PregnancyJourneyTests: XCTestCase {

    // MARK: - PregnancyWeekContentStore

    private func fixtureStore() -> PregnancyWeekContentStore {
        PregnancyWeekContentStore(entries: [
            PregnancyWeekContent(week: 4, fruitSize: "양귀비 씨", milestone: "착상", tip: "엽산", disclaimerKey: nil),
            PregnancyWeekContent(week: 8, fruitSize: "라즈베리", milestone: "심장", tip: "수분", disclaimerKey: nil),
            PregnancyWeekContent(week: 24, fruitSize: "옥수수", milestone: "청각", tip: "태담", disclaimerKey: nil),
            PregnancyWeekContent(week: 40, fruitSize: "수박", milestone: "만삭", tip: "출산가방", disclaimerKey: nil)
        ])
    }

    func test_content_exactWeekMatch() {
        XCTAssertEqual(fixtureStore().content(forWeek: 8)?.fruitSize, "라즈베리")
    }

    func test_content_betweenWeeks_picksNearestBelow() {
        // 10주는 8주 항목으로 폴백(현재 주차 이하 가장 가까운 항목)
        XCTAssertEqual(fixtureStore().content(forWeek: 10)?.week, 8)
    }

    func test_content_belowFirst_picksFirst() {
        // 3주(4주 미만)는 첫 항목으로 폴백
        XCTAssertEqual(fixtureStore().content(forWeek: 3)?.week, 4)
    }

    func test_content_aboveLast_picksLast() {
        XCTAssertEqual(fixtureStore().content(forWeek: 50)?.week, 40)
    }

    func test_content_emptyStore_returnsNil() {
        XCTAssertNil(PregnancyWeekContentStore(entries: []).content(forWeek: 12))
    }

    func test_loadBundled_decodesRealJSON() {
        let store = PregnancyWeekContentStore.loadBundled()
        // pregnancy-weeks.json 은 4~40주 연속 — 비어있지 않고 4주 항목 존재
        XCTAssertFalse(store.entries.isEmpty)
        XCTAssertEqual(store.content(forWeek: 4)?.week, 4)
    }

    // MARK: - PregnancyJourneyContent

    private func visit(daysUntil: Int, hospital: String? = "행복산부인과") -> PrenatalVisit {
        let date = Calendar.current.date(byAdding: .day, value: daysUntil, to: Date())!
        return PrenatalVisit(pregnancyId: "p1", scheduledAt: date, hospitalName: hospital)
    }

    private func checklist(_ title: String, completed: Bool, order: Int?) -> PregnancyChecklistItem {
        PregnancyChecklistItem(pregnancyId: "p1", title: title, category: "test",
                               isCompleted: completed, source: "test", order: order)
    }

    func test_promotedCards_laborTimerShownAt37WeeksFirst() {
        let content = PregnancyJourneyContent(
            currentWeek: 38, checklistItems: [], prenatalVisits: [visit(daysUntil: 1)]
        )
        // 37주+ 진통 타이머가 최우선 정렬
        XCTAssertEqual(content.promotedCards.first, .laborTimer)
        XCTAssertEqual(content.promotedCards.count, 2)  // labor + visit
    }

    func test_promotedCards_noLaborBefore37() {
        let content = PregnancyJourneyContent(
            currentWeek: 30, checklistItems: [], prenatalVisits: [visit(daysUntil: 1)]
        )
        XCTAssertEqual(content.promotedCards, [.upcomingVisit(daysUntil: 1, hospitalName: "행복산부인과")])
    }

    func test_promotedCards_onlyDueSoonVisitsCount() {
        let content = PregnancyJourneyContent(
            currentWeek: 20, checklistItems: [], prenatalVisits: [visit(daysUntil: 30)]  // isDueSoon=false
        )
        XCTAssertTrue(content.promotedCards.isEmpty)
    }

    func test_promotedCards_cappedAtTwo() {
        let content = PregnancyJourneyContent(
            currentWeek: 38, checklistItems: [], prenatalVisits: [visit(daysUntil: 0), visit(daysUntil: 2)]
        )
        XCTAssertEqual(content.promotedCards.count, 2)
    }

    func test_topIncompleteChecklist_max3_sortedByOrder() {
        let items = [
            checklist("C", completed: false, order: 3),
            checklist("A", completed: false, order: 1),
            checklist("done", completed: true, order: 0),
            checklist("B", completed: false, order: 2),
            checklist("D", completed: false, order: 4)
        ]
        let content = PregnancyJourneyContent(currentWeek: 12, checklistItems: items, prenatalVisits: [])
        XCTAssertEqual(content.topIncompleteChecklist.map(\.title), ["A", "B", "C"])
    }

    func test_futureMilestones_filtersPastByUpperBound() {
        // 25주: NT(11~13)·정밀초음파(15~20) 지남, 임당(24~28)만 현재/미래
        let content = PregnancyJourneyContent(currentWeek: 25, checklistItems: [], prenatalVisits: [])
        XCTAssertEqual(content.futureMilestones.count, 1)
        XCTAssertEqual(content.futureMilestones.first?.weekRange, 24...28)
    }

    func test_futureMilestones_earlyWeekShowsAll() {
        let content = PregnancyJourneyContent(currentWeek: 9, checklistItems: [], prenatalVisits: [])
        XCTAssertEqual(content.futureMilestones.count, 3)
    }

    func test_nilWeek_noLaborNoMilestones() {
        let content = PregnancyJourneyContent(currentWeek: nil, checklistItems: [], prenatalVisits: [visit(daysUntil: 1)])
        XCTAssertFalse(content.promotedCards.contains(.laborTimer))
        XCTAssertTrue(content.futureMilestones.isEmpty)
        // 주차 미상이어도 임박 검진은 노출
        XCTAssertEqual(content.promotedCards, [.upcomingVisit(daysUntil: 1, hospitalName: "행복산부인과")])
    }
}
