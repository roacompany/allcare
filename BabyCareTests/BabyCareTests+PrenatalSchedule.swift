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

    // MARK: - Phase D: 체크리스트 플래너 + 진료준비 질문 + 음식 안전

    private func checklistItem(cat: String, done: Bool, order: Int = 0, title: String = "t") -> PregnancyChecklistItem {
        PregnancyChecklistItem(pregnancyId: "p", title: title, category: cat,
                               isCompleted: done, source: "bundle", order: order)
    }

    // --- PregnancyChecklistPlanner (주차→삼분기 / 완료율 / 이번 주 요약) ---

    func test_checklistPlanner_currentTrimesterCategory() {
        XCTAssertEqual(PregnancyChecklistPlanner.currentTrimesterCategory(forWeek: 8), "trimester1")
        XCTAssertEqual(PregnancyChecklistPlanner.currentTrimesterCategory(forWeek: 13), "trimester1")
        XCTAssertEqual(PregnancyChecklistPlanner.currentTrimesterCategory(forWeek: 14), "trimester2")
        XCTAssertEqual(PregnancyChecklistPlanner.currentTrimesterCategory(forWeek: 27), "trimester2")
        XCTAssertEqual(PregnancyChecklistPlanner.currentTrimesterCategory(forWeek: 28), "trimester3")
        XCTAssertEqual(PregnancyChecklistPlanner.currentTrimesterCategory(forWeek: 42), "trimester3") // 막달 이후도 3삼분기 과업
        XCTAssertNil(PregnancyChecklistPlanner.currentTrimesterCategory(forWeek: nil))
        XCTAssertNil(PregnancyChecklistPlanner.currentTrimesterCategory(forWeek: 0))
    }

    func test_checklistPlanner_completionRate() {
        XCTAssertEqual(PregnancyChecklistPlanner.completionRate([]), 0)
        let items = [checklistItem(cat: "trimester2", done: true), checklistItem(cat: "trimester2", done: false),
                     checklistItem(cat: "trimester3", done: true), checklistItem(cat: "trimester3", done: false)]
        XCTAssertEqual(PregnancyChecklistPlanner.completionRate(items), 0.5, accuracy: 0.001)
    }

    func test_checklistPlanner_weeklyHighlights_currentTrimesterIncompleteOrdered() {
        let items = [checklistItem(cat: "trimester2", done: false, order: 1, title: "t2-a"),
                     checklistItem(cat: "trimester2", done: true, order: 0, title: "t2-done"),
                     checklistItem(cat: "trimester2", done: false, order: 2, title: "t2-b"),
                     checklistItem(cat: "trimester3", done: false, order: 0, title: "t3")]
        let hi = PregnancyChecklistPlanner.weeklyHighlights(items, currentWeek: 20, limit: 3) // 20주=t2
        XCTAssertEqual(hi.map { $0.title }, ["t2-a", "t2-b"]) // 미완료만 · order 정렬 · 타 삼분기 제외
    }

    func test_checklistPlanner_weeklyHighlights_respectsLimit() {
        let items = (0..<5).map { checklistItem(cat: "trimester1", done: false, order: $0, title: "n\($0)") }
        XCTAssertEqual(PregnancyChecklistPlanner.weeklyHighlights(items, currentWeek: 6, limit: 2).count, 2)
    }

    func test_checklistPlanner_weeklyHighlights_nilWeekFallsBackToAllIncomplete() {
        let items = [checklistItem(cat: "trimester1", done: false, order: 0, title: "a"),
                     checklistItem(cat: "trimester3", done: true, order: 1, title: "b-done"),
                     checklistItem(cat: "custom", done: false, order: 2, title: "c")]
        let hi = PregnancyChecklistPlanner.weeklyHighlights(items, currentWeek: nil, limit: 5)
        XCTAssertEqual(hi.map { $0.title }, ["a", "c"]) // 주차 미상 → 전체 미완료
    }

    // --- VisitPrepQuestion / PrenatalVisit 임베딩 (진료준비 질문) ---

    func test_visitPrepQuestion_codableRoundTrip_preservesQuestions() throws {
        var v = PrenatalVisit(pregnancyId: "p", scheduledAt: Date())
        v.preparationQuestions = [VisitPrepQuestion(text: "철분제 계속 먹어도 되나요?"),
                                  VisitPrepQuestion(text: "체중 증가 괜찮나요?", asked: true)]
        let decoded = try JSONDecoder().decode(PrenatalVisit.self, from: JSONEncoder().encode(v))
        XCTAssertEqual(decoded.preparationQuestions?.count, 2)
        XCTAssertEqual(decoded.preparationQuestions?.first?.text, "철분제 계속 먹어도 되나요?")
        XCTAssertEqual(decoded.preparationQuestions?.last?.asked, true)
    }

    func test_prenatalVisit_backwardCompat_missingQuestionsDecodesNil() throws {
        // 구버전 문서(질문 필드 없음)도 디코드 — 신규 필드 optional 계약.
        let json = #"{"id":"v1","pregnancyId":"p","scheduledAt":0,"isCompleted":false,"createdAt":0,"updatedAt":0}"#
            .data(using: .utf8)!
        XCTAssertNil(try JSONDecoder().decode(PrenatalVisit.self, from: json).preparationQuestions)
    }

    func test_prenatalVisit_openQuestionCount() {
        var v = PrenatalVisit(pregnancyId: "p", scheduledAt: Date())
        XCTAssertEqual(v.openQuestionCount, 0)
        v.preparationQuestions = [VisitPrepQuestion(text: "a"), VisitPrepQuestion(text: "b", asked: true),
                                  VisitPrepQuestion(text: "c")]
        XCTAssertEqual(v.openQuestionCount, 2)
    }

    // --- PregnancyFoodSafety (음식·약물 안전 빠른 조회, 의료감수 전 초안) ---

    func test_foodSafety_itemsNonEmptyAndWellFormed() {
        XCTAssertFalse(PregnancyFoodSafety.items.isEmpty)
        for it in PregnancyFoodSafety.items {
            XCTAssertFalse(it.name.isEmpty, "\(it.id) name empty")
            XCTAssertFalse(it.guidance.isEmpty, "\(it.id) guidance empty")
        }
    }

    func test_foodSafety_search_emptyOrBlankReturnsAll() {
        XCTAssertEqual(PregnancyFoodSafety.search("").count, PregnancyFoodSafety.items.count)
        XCTAssertEqual(PregnancyFoodSafety.search("   ").count, PregnancyFoodSafety.items.count)
    }

    func test_foodSafety_search_matchesNameOrKeyword() {
        XCTAssertTrue(PregnancyFoodSafety.search("커피").contains { $0.id == "caffeine" })
        XCTAssertTrue(PregnancyFoodSafety.search("카페인").contains { $0.id == "caffeine" }) // 동의어 키워드
    }

    func test_foodSafety_search_noMatchEmpty_andCaseInsensitive() {
        XCTAssertTrue(PregnancyFoodSafety.search("존재하지않는음식zzz").isEmpty)
        XCTAssertEqual(PregnancyFoodSafety.search("COFFEE").count, PregnancyFoodSafety.search("coffee").count)
    }

    // MARK: - 이연: 타임라인 노드 완료/누락 진행도 (visit↔표준일정 fuzzy 매핑)

    private static let fixedLMP = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))!

    /// fixedLMP 기준 임신 N주차에 해당하는 검진(주차*7일).
    private func visitAtWeek(_ week: Int, type: String?, completed: Bool) -> PrenatalVisit {
        let date = Calendar.current.date(byAdding: .day, value: week * 7, to: Self.fixedLMP)!
        return PrenatalVisit(pregnancyId: "p", scheduledAt: date, visitType: type, isCompleted: completed)
    }

    func test_nodeProgress_doneWhenCompletedMatchingVisit() {
        let gtt = item("gdm-screening") // 24~28, hint gtt
        let v = visitAtWeek(26, type: "gtt", completed: true)
        XCTAssertEqual(PrenatalVisitPlanner.nodeProgress(for: gtt, visits: [v], lmpDate: Self.fixedLMP, currentWeek: 32), .done)
    }

    func test_nodeProgress_loggedWhenIncompleteMatchingVisit() {
        let gtt = item("gdm-screening")
        let v = visitAtWeek(25, type: "gtt", completed: false)
        XCTAssertEqual(PrenatalVisitPlanner.nodeProgress(for: gtt, visits: [v], lmpDate: Self.fixedLMP, currentWeek: 32), .logged)
    }

    func test_nodeProgress_missedWhenPastWindowNoVisit() {
        let nt = item("nt-first") // 11~13
        XCTAssertEqual(PrenatalVisitPlanner.nodeProgress(for: nt, visits: [], lmpDate: Self.fixedLMP, currentWeek: 32), .missed)
    }

    func test_nodeProgress_upcomingForCurrentAndFutureWindows() {
        let gtt = item("gdm-screening") // 24~28
        XCTAssertEqual(PrenatalVisitPlanner.nodeProgress(for: gtt, visits: [], lmpDate: Self.fixedLMP, currentWeek: 26), .upcoming) // 현재창
        let gbs = item("gbs-screening")  // 35~37
        XCTAssertEqual(PrenatalVisitPlanner.nodeProgress(for: gbs, visits: [], lmpDate: Self.fixedLMP, currentWeek: 26), .upcoming) // 미래창
    }

    func test_nodeProgress_typeMismatchNotMatched() {
        // 정밀초음파(18~24, hint ultrasound) 창에 든 혈액검사 방문은 초음파 노드를 채우지 않음 → 지난창=누락.
        let ultrasound = item("detailed-ultrasound")
        let v = visitAtWeek(20, type: "bloodTest", completed: true)
        XCTAssertEqual(PrenatalVisitPlanner.nodeProgress(for: ultrasound, visits: [v], lmpDate: Self.fixedLMP, currentWeek: 32), .missed)
    }

    func test_nodeProgress_untypedVisitMatchesByWindowOnly() {
        let ultrasound = item("detailed-ultrasound") // 18~24
        let v = visitAtWeek(20, type: nil, completed: true)
        XCTAssertEqual(PrenatalVisitPlanner.nodeProgress(for: ultrasound, visits: [v], lmpDate: Self.fixedLMP, currentWeek: 32), .done)
    }

    func test_nodeProgress_nilLMP_fallsBackToWindowStatus() {
        let nt = item("nt-first") // 11~13
        // 주차 환산 불가 → 매칭 없음. 지난창=누락 / 미래창=upcoming.
        XCTAssertEqual(PrenatalVisitPlanner.nodeProgress(for: nt, visits: [], lmpDate: nil, currentWeek: 32), .missed)
        XCTAssertEqual(PrenatalVisitPlanner.nodeProgress(for: nt, visits: [], lmpDate: nil, currentWeek: 5), .upcoming)
    }

    // MARK: - 이연: 국민행복카드 수동 잔액 진행도

    func test_voucher_usedProgress_clampsAndGuards() {
        XCTAssertEqual(HappyCardVoucher.usedProgress(used: 0, total: 1_000_000), 0)
        XCTAssertEqual(HappyCardVoucher.usedProgress(used: 500_000, total: 1_000_000), 0.5, accuracy: 0.001)
        XCTAssertEqual(HappyCardVoucher.usedProgress(used: 1_200_000, total: 1_000_000), 1.0) // 초과 클램프
        XCTAssertEqual(HappyCardVoucher.usedProgress(used: 100, total: 0), 0)                  // 총액 0 방어
        XCTAssertEqual(HappyCardVoucher.usedProgress(used: -50, total: 1_000_000), 0)          // 음수 방어
    }

    func test_voucher_remaining_neverNegative() {
        XCTAssertEqual(HappyCardVoucher.remaining(used: 300_000, total: 1_000_000), 700_000)
        XCTAssertEqual(HappyCardVoucher.remaining(used: 1_200_000, total: 1_000_000), 0) // 초과→0
        XCTAssertEqual(HappyCardVoucher.remaining(used: -50, total: 1_000_000), 1_000_000)
    }

    func test_voucher_isOverBudget() {
        XCTAssertFalse(HappyCardVoucher.isOverBudget(used: 1_000_000, total: 1_000_000))
        XCTAssertTrue(HappyCardVoucher.isOverBudget(used: 1_000_001, total: 1_000_000))
    }

    // MARK: - 이연: 산모수첩 자궁저높이·태아추정체중(EFW)

    func test_mirror_includesFundalHeightAndEFW_latestPerMetric() {
        let cal = Calendar.current
        let now = Date()
        func d(_ days: Int) -> Date { cal.date(byAdding: .day, value: days, to: now)! }
        let vitals = [
            PregnancyVitalEntry(pregnancyId: "p", measuredAt: d(-3), fundalHeight: 28.0),
            PregnancyVitalEntry(pregnancyId: "p", measuredAt: d(-1), fundalHeight: 30.0),   // 최신
            PregnancyVitalEntry(pregnancyId: "p", measuredAt: d(-2), estimatedFetalWeight: 1500)
        ]
        let m = MaternalRecordMirror.latestMeasurements(vitals: vitals, weights: [])
        XCTAssertEqual(m.first { $0.id == "fundalHeight" }?.value, "30.0")
        XCTAssertEqual(m.first { $0.id == "fundalHeight" }?.unit, "cm")
        XCTAssertEqual(m.first { $0.id == "efw" }?.value, "1500")
        XCTAssertEqual(m.first { $0.id == "efw" }?.unit, "g")
    }

    func test_mirror_excludesAbsentFundalAndEFW() {
        let m = MaternalRecordMirror.latestMeasurements(
            vitals: [PregnancyVitalEntry(pregnancyId: "p", systolic: 110, diastolic: 70, measuredAt: Date())],
            weights: [])
        XCTAssertNil(m.first { $0.id == "fundalHeight" })
        XCTAssertNil(m.first { $0.id == "efw" })
    }

    func test_vitalEntry_fundalEFW_codableRoundTrip() throws {
        let e = PregnancyVitalEntry(pregnancyId: "p", measuredAt: Date(), fundalHeight: 31.5, estimatedFetalWeight: 2100)
        let decoded = try JSONDecoder().decode(PregnancyVitalEntry.self, from: JSONEncoder().encode(e))
        XCTAssertEqual(decoded.fundalHeight, 31.5)
        XCTAssertEqual(decoded.estimatedFetalWeight, 2100)
    }

    func test_voucher_pregnancy_voucherUsedAmount_codableRoundTripAndBackwardCompat() throws {
        var p = Pregnancy(lmpDate: nil)
        p.voucherUsedAmount = 350_000
        let decoded = try JSONDecoder().decode(Pregnancy.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.voucherUsedAmount, 350_000)
        // 구버전 문서(필드 없음) → nil 안전 디코딩
        let legacy = #"{"id":"p1","createdAt":0,"updatedAt":0}"#.data(using: .utf8)!
        XCTAssertNil(try JSONDecoder().decode(Pregnancy.self, from: legacy).voucherUsedAmount)
    }
}
