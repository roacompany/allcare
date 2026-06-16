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

    // MARK: - Phase C: 산모수첩 미러 + 국민행복카드 바우처

    func test_mirror_latestPerMetric() {
        let cal = Calendar.current
        let now = Date()
        func d(_ days: Int) -> Date { cal.date(byAdding: .day, value: days, to: now)! }
        let vitals = [
            PregnancyVitalEntry(pregnancyId: "p", systolic: 110, diastolic: 70, measuredAt: d(-3)),
            PregnancyVitalEntry(pregnancyId: "p", systolic: 120, diastolic: 80, measuredAt: d(-1)),
            PregnancyVitalEntry(pregnancyId: "p", glucose: 95, glucoseContext: "fasting", measuredAt: d(-2))
        ]
        let weights = [
            PregnancyWeightEntry(pregnancyId: "p", weight: 60.0, unit: "kg", measuredAt: d(-5)),
            PregnancyWeightEntry(pregnancyId: "p", weight: 62.5, unit: "kg", measuredAt: d(-1))
        ]
        let m = MaternalRecordMirror.latestMeasurements(vitals: vitals, weights: weights)
        XCTAssertEqual(m.first { $0.id == "bp" }?.value, "120/80")
        XCTAssertEqual(m.first { $0.id == "glucose" }?.value, "95")
        XCTAssertEqual(m.first { $0.id == "glucose" }?.context, "공복")
        XCTAssertEqual(m.first { $0.id == "weight" }?.value, "62.5")
    }

    func test_mirror_emptyAndPartial() {
        XCTAssertTrue(MaternalRecordMirror.latestMeasurements(vitals: [], weights: []).isEmpty)
        let onlyGlucose = [PregnancyVitalEntry(pregnancyId: "p", glucose: 100, measuredAt: Date())]
        let m = MaternalRecordMirror.latestMeasurements(vitals: onlyGlucose, weights: [])
        XCTAssertEqual(m.count, 1)
        XCTAssertEqual(m.first?.id, "glucose")
    }

    func test_voucher_supportAmount() {
        XCTAssertEqual(HappyCardVoucher.supportAmount(fetusCount: 1), 1_000_000)
        XCTAssertEqual(HappyCardVoucher.supportAmount(fetusCount: 2), 1_400_000)
        XCTAssertEqual(HappyCardVoucher.supportAmount(fetusCount: 3), 1_400_000)
        XCTAssertEqual(HappyCardVoucher.supportAmount(fetusCount: nil), 1_000_000)
        XCTAssertEqual(HappyCardVoucher.supportAmount(fetusCount: 1, isRemoteArea: true), 1_200_000)
    }
}
