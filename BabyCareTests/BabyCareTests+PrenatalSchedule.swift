import XCTest
@testable import BabyCare

/// `KoreanPrenatalSchedule` 주차 자동매핑 순수 로직 테스트 (③검진 Phase A).
final class PrenatalScheduleTests: XCTestCase {

    private func item(_ id: String) -> KoreanPrenatalScheduleItem {
        KoreanPrenatalSchedule.standardItems.first { $0.id == id }!
    }

    func test_standardItems_nonEmpty_validRanges() {
        let items = KoreanPrenatalSchedule.standardItems
        XCTAssertFalse(items.isEmpty)
        for it in items {
            XCTAssertLessThanOrEqual(it.weekStart, it.weekEnd, "\(it.id) week range invalid")
        }
    }

    func test_status_pastCurrentFuture() {
        let nt = item("nt-first") // 11~13
        XCTAssertEqual(KoreanPrenatalSchedule.status(for: nt, currentWeek: 12), .current)
        XCTAssertEqual(KoreanPrenatalSchedule.status(for: nt, currentWeek: 14), .past)
        XCTAssertEqual(KoreanPrenatalSchedule.status(for: nt, currentWeek: 9), .future)
    }

    func test_status_boundaryInclusive() {
        let nt = item("nt-first") // 11~13 inclusive both ends
        XCTAssertEqual(KoreanPrenatalSchedule.status(for: nt, currentWeek: 11), .current)
        XCTAssertEqual(KoreanPrenatalSchedule.status(for: nt, currentWeek: 13), .current)
    }

    func test_status_nilWeek_isFuture() {
        XCTAssertEqual(KoreanPrenatalSchedule.status(for: item("nt-first"), currentWeek: nil), .future)
    }

    func test_timeline_sortedAndStatusMapped() {
        let t = KoreanPrenatalSchedule.timeline(currentWeek: 26)
        XCTAssertEqual(t.count, KoreanPrenatalSchedule.standardItems.count)
        XCTAssertEqual(t.map { $0.item.weekStart }, t.map { $0.item.weekStart }.sorted())
        XCTAssertEqual(t.first { $0.id == "gdm-screening" }?.status, .current)    // 24~28
        XCTAssertEqual(t.first { $0.id == "detailed-ultrasound" }?.status, .past)  // 18~24
        XCTAssertEqual(t.first { $0.id == "gbs-screening" }?.status, .future)     // 35~37
    }

    func test_currentItem() {
        XCTAssertEqual(KoreanPrenatalSchedule.currentItem(currentWeek: 26)?.id, "gdm-screening")
        XCTAssertNil(KoreanPrenatalSchedule.currentItem(currentWeek: 100))
        XCTAssertNil(KoreanPrenatalSchedule.currentItem(currentWeek: nil))
    }

    // MARK: - Phase B: 검진객체 연동 (PrenatalVisitPlanner)

    func test_items_haveVisitTypeHint() {
        XCTAssertEqual(item("gdm-screening").visitTypeHint, "gtt")
        XCTAssertEqual(item("nt-first").visitTypeHint, "ultrasound")
        XCTAssertEqual(item("early-basic").visitTypeHint, "bloodTest")
    }

    private func visit(daysFromNow days: Int, completed: Bool = false, now: Date) -> PrenatalVisit {
        let date = Calendar.current.date(byAdding: .day, value: days, to: now)!
        return PrenatalVisit(pregnancyId: "p1", scheduledAt: date, isCompleted: completed)
    }

    func test_nextRelevantVisit_prefersNearestUpcoming() {
        let now = Date()
        let near = visit(daysFromNow: 5, now: now)
        let visits = [visit(daysFromNow: 20, now: now), near,
                      visit(daysFromNow: -3, now: now), visit(daysFromNow: 1, completed: true, now: now)]
        XCTAssertEqual(PrenatalVisitPlanner.nextRelevantVisit(in: visits, asOf: now)?.id, near.id)
    }

    func test_nextRelevantVisit_fallsBackToMostRecentOverdue() {
        let now = Date()
        let recentOverdue = visit(daysFromNow: -3, now: now)
        let visits = [visit(daysFromNow: -10, now: now), recentOverdue,
                      visit(daysFromNow: -1, completed: true, now: now)]
        XCTAssertEqual(PrenatalVisitPlanner.nextRelevantVisit(in: visits, asOf: now)?.id, recentOverdue.id)
    }

    func test_nextRelevantVisit_nilWhenAllCompletedOrEmpty() {
        let now = Date()
        XCTAssertNil(PrenatalVisitPlanner.nextRelevantVisit(in: [visit(daysFromNow: 5, completed: true, now: now)], asOf: now))
        XCTAssertNil(PrenatalVisitPlanner.nextRelevantVisit(in: [], asOf: now))
    }

    func test_suggestedDate_midWeekFromLMP() {
        let lmp = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let nt = item("nt-first") // 11~13 → mid 12 → LMP + 84일
        let expected = Calendar.current.date(byAdding: .day, value: 84, to: lmp)
        XCTAssertEqual(PrenatalVisitPlanner.suggestedDate(for: nt, lmpDate: lmp), expected)
    }

    func test_suggestedDate_nilWithoutLMP() {
        XCTAssertNil(PrenatalVisitPlanner.suggestedDate(for: item("nt-first"), lmpDate: nil))
    }
}
