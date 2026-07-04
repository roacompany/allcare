import XCTest
@testable import BabyCare

final class PregnancyTrackingTests: XCTestCase {

    private let cal = Calendar.current

    private func kick(at date: Date) -> KickSession {
        var s = KickSession(pregnancyId: "p1")
        s.startedAt = date
        return s
    }
    private func weight(at date: Date) -> PregnancyWeightEntry {
        PregnancyWeightEntry(pregnancyId: "p1", weight: 60, unit: "kg", measuredAt: date)
    }
    private func symptom(at date: Date) -> PregnancySymptom {
        PregnancySymptom(pregnancyId: "p1", memo: "메모", occurredAt: date)
    }

    func test_summary_countsOnlyToday() {
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let summary = PregnancyTrackingSummary(
            now: today,
            kickSessions: [kick(at: today), kick(at: yesterday)],
            weightEntries: [weight(at: today)],
            symptoms: [symptom(at: yesterday)]
        )
        XCTAssertEqual(summary.kickCount, 1)
        XCTAssertEqual(summary.weightCount, 1)
        XCTAssertEqual(summary.symptomCount, 0)
    }

    func test_summary_isEmptyWhenNothingToday() {
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let summary = PregnancyTrackingSummary(
            now: Date(), kickSessions: [kick(at: yesterday)], weightEntries: [], symptoms: []
        )
        XCTAssertTrue(summary.isEmpty)
    }

    func test_summary_notEmptyWhenAnyToday() {
        let summary = PregnancyTrackingSummary(
            now: Date(), kickSessions: [], weightEntries: [weight(at: Date())], symptoms: []
        )
        XCTAssertFalse(summary.isEmpty)
    }

    // MARK: - PregnancyVitalEntry (임당 참고 목표선)

    func test_glucose_withinReference_fasting() {
        // 공복 ≤ 95 mg/dL
        XCTAssertTrue(PregnancyVitalEntry.glucoseWithinReference(value: 90, context: .fasting))
        XCTAssertFalse(PregnancyVitalEntry.glucoseWithinReference(value: 100, context: .fasting))
    }

    func test_glucose_withinReference_postMeal1h() {
        // 식후 1시간 ≤ 140
        XCTAssertTrue(PregnancyVitalEntry.glucoseWithinReference(value: 130, context: .postMeal1h))
        XCTAssertFalse(PregnancyVitalEntry.glucoseWithinReference(value: 150, context: .postMeal1h))
    }

    func test_glucose_withinReference_postMeal2h() {
        // 식후 2시간 ≤ 120
        XCTAssertTrue(PregnancyVitalEntry.glucoseWithinReference(value: 110, context: .postMeal2h))
        XCTAssertFalse(PregnancyVitalEntry.glucoseWithinReference(value: 130, context: .postMeal2h))
    }

    @MainActor
    func test_addVitalEntry_persistsAndPrepends() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        vm.activePregnancy = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "t")
        await vm.addVitalEntry(
            PregnancyVitalEntry(pregnancyId: "p1", glucose: 90, glucoseContext: "fasting"),
            userId: "u1"
        )
        XCTAssertEqual(mock.saveVitalEntryCalls.count, 1)
        XCTAssertEqual(vm.vitalEntries.first?.glucose, 90)
    }

    // MARK: - ContractionSession (5-1-1)

    func test_511_metWhenIntervalsTightAndSustained() {
        // 5분 간격·1분 지속·1시간 지속 → 충족
        let now = Date()
        var session = ContractionSession(pregnancyId: "p1")
        for i in 0..<13 {
            let start = now.addingTimeInterval(Double(i) * 300)        // 5분 간격
            session.contractions.append(ContractionEvent(startedAt: start, endedAt: start.addingTimeInterval(60)))
        }
        XCTAssertTrue(session.meets511(asOf: now.addingTimeInterval(13 * 300)))
    }

    func test_511_notMetWhenSparse() {
        // 15분 간격 → 미충족
        let now = Date()
        var session = ContractionSession(pregnancyId: "p1")
        for i in 0..<5 {
            let start = now.addingTimeInterval(Double(i) * 900)
            session.contractions.append(ContractionEvent(startedAt: start, endedAt: start.addingTimeInterval(30)))
        }
        XCTAssertFalse(session.meets511(asOf: now.addingTimeInterval(5 * 900)))
    }

    func test_511_notMetWhenShortHistory() {
        // 5분 간격·1분 지속이지만 20분만 → 1시간 미충족
        let now = Date()
        var session = ContractionSession(pregnancyId: "p1")
        for i in 0..<5 {
            let start = now.addingTimeInterval(Double(i) * 300)
            session.contractions.append(ContractionEvent(startedAt: start, endedAt: start.addingTimeInterval(60)))
        }
        XCTAssertFalse(session.meets511(asOf: now.addingTimeInterval(5 * 300)))
    }

    @MainActor
    func test_saveContractionSession_upsertsById() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        vm.activePregnancy = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "t")
        var session = ContractionSession(pregnancyId: "p1")
        await vm.saveContractionSession(session, userId: "u1")
        XCTAssertEqual(vm.contractionSessions.count, 1)
        // 같은 id 재저장 → 교체(중복 추가 아님)
        session.contractions.append(ContractionEvent(startedAt: Date()))
        await vm.saveContractionSession(session, userId: "u1")
        XCTAssertEqual(vm.contractionSessions.count, 1)
        XCTAssertEqual(mock.saveContractionSessionCalls.count, 2)
    }

    // MARK: - Korean BMI 권장 증가밴드 (KoreanGestationalWeightGain)

    func test_bmi_computesFromHeightAndWeight() {
        // 160cm·51.2kg → BMI 20.0
        let bmi = KoreanGestationalWeightGain.bmi(heightCm: 160, weightKg: 51.2)
        XCTAssertEqual(bmi ?? 0, 20.0, accuracy: 0.01)
    }

    func test_bmi_nilForNonPositiveInput() {
        XCTAssertNil(KoreanGestationalWeightGain.bmi(heightCm: 0, weightKg: 60))
        XCTAssertNil(KoreanGestationalWeightGain.bmi(heightCm: 160, weightKg: 0))
    }

    func test_bmiCategory_koreanCutoffs() {
        typealias C = KoreanGestationalWeightGain.Category
        XCTAssertEqual(C.category(forBMI: 18.0), .underweight)
        XCTAssertEqual(C.category(forBMI: 18.5), .normal)      // 경계 포함
        XCTAssertEqual(C.category(forBMI: 22.9), .normal)
        XCTAssertEqual(C.category(forBMI: 23.0), .overweight)  // 한국 과체중 경계
        XCTAssertEqual(C.category(forBMI: 24.9), .overweight)
        XCTAssertEqual(C.category(forBMI: 25.0), .obese)       // 한국 비만 경계 (서구 30과 다름)
    }

    func test_recommendedTotalGain_matchesKSOG() {
        typealias C = KoreanGestationalWeightGain.Category
        XCTAssertEqual(C.underweight.recommendedTotalGainKg, 12.5...18.0)
        XCTAssertEqual(C.normal.recommendedTotalGainKg, 11.5...15.0)
        XCTAssertEqual(C.overweight.recommendedTotalGainKg, 7.0...11.5)
        // 비만 "7kg 미만" → 하한 없음(0)
        XCTAssertEqual(C.obese.recommendedTotalGainKg, 0.0...7.0)
    }

    func test_cumulativeBand_anchorsToLockedTotalAt40() {
        // 만삭(40주) 밴드 = FEATURES.md §③ LOCK 총 증가 범위
        let band = KoreanGestationalWeightGain.recommendedCumulativeRange(atWeek: 40, category: .normal)
        XCTAssertEqual(band?.lowerBound ?? -1, 11.5, accuracy: 0.001)
        XCTAssertEqual(band?.upperBound ?? -1, 15.0, accuracy: 0.001)
    }

    func test_cumulativeBand_zeroAtConception() {
        let band = KoreanGestationalWeightGain.recommendedCumulativeRange(atWeek: 0, category: .normal)
        XCTAssertEqual(band?.lowerBound ?? -1, 0.0, accuracy: 0.001)
        XCTAssertEqual(band?.upperBound ?? -1, 0.0, accuracy: 0.001)
    }

    func test_cumulativeBand_firstTrimesterModest() {
        // 13주(1삼분기 말) = 초안 1삼분기 범위 0.5~2.0 (정상)
        let band = KoreanGestationalWeightGain.recommendedCumulativeRange(atWeek: 13, category: .normal)
        XCTAssertEqual(band?.lowerBound ?? -1, 0.5, accuracy: 0.001)
        XCTAssertEqual(band?.upperBound ?? -1, 2.0, accuracy: 0.001)
    }

    func test_cumulativeBand_clampsBeyondTerm() {
        // 42주 → 40주로 클램프(만삭 후 동일)
        let b40 = KoreanGestationalWeightGain.recommendedCumulativeRange(atWeek: 40, category: .normal)
        let b42 = KoreanGestationalWeightGain.recommendedCumulativeRange(atWeek: 42, category: .normal)
        XCTAssertEqual(b42?.lowerBound ?? -1, b40?.lowerBound ?? -2, accuracy: 0.001)
        XCTAssertEqual(b42?.upperBound ?? -1, b40?.upperBound ?? -2, accuracy: 0.001)
    }

    func test_cumulativeBand_nilForNegativeWeek() {
        XCTAssertNil(KoreanGestationalWeightGain.recommendedCumulativeRange(atWeek: -1, category: .normal))
    }

    func test_bandPosition_belowWithinAbove() {
        typealias G = KoreanGestationalWeightGain
        // 정상·40주 밴드 = 11.5~15.0 (LOCK)
        XCTAssertEqual(G.position(cumulativeGainKg: 10.0, atWeek: 40, category: .normal), .below)
        XCTAssertEqual(G.position(cumulativeGainKg: 13.0, atWeek: 40, category: .normal), .within)
        XCTAssertEqual(G.position(cumulativeGainKg: 16.0, atWeek: 40, category: .normal), .above)
    }

    func test_bandPosition_boundaryIsWithin() {
        typealias G = KoreanGestationalWeightGain
        XCTAssertEqual(G.position(cumulativeGainKg: 11.5, atWeek: 40, category: .normal), .within)
        XCTAssertEqual(G.position(cumulativeGainKg: 15.0, atWeek: 40, category: .normal), .within)
    }

    func test_obeseBand_noLowerFloor() {
        typealias G = KoreanGestationalWeightGain
        // 비만 밴드 하한 0 → 적게 늘어도 below 아님(within), 7kg 초과만 above
        XCTAssertEqual(G.position(cumulativeGainKg: 0.5, atWeek: 40, category: .obese), .within)
        XCTAssertEqual(G.position(cumulativeGainKg: 8.0, atWeek: 40, category: .obese), .above)
    }

    // MARK: - 밴드 표시 상태 조립 (guidance) — 가드 + 계산

    func test_guidance_nilForTwins() {
        // 다태아는 단태아 밴드 비적용 → nil
        XCTAssertNil(KoreanGestationalWeightGain.guidance(
            prePregnancyHeightCm: 160, prePregnancyWeightKg: 55,
            latestWeightKg: 60, currentWeek: 20, fetusCount: 2))
    }

    func test_guidance_nilWhenBaselineMissing() {
        typealias G = KoreanGestationalWeightGain
        XCTAssertNil(G.guidance(prePregnancyHeightCm: nil, prePregnancyWeightKg: 55,
                                latestWeightKg: 60, currentWeek: 20, fetusCount: 1))
        XCTAssertNil(G.guidance(prePregnancyHeightCm: 160, prePregnancyWeightKg: nil,
                                latestWeightKg: 60, currentWeek: 20, fetusCount: 1))
    }

    func test_guidance_nilWhenNoCurrentWeightOrWeek() {
        typealias G = KoreanGestationalWeightGain
        XCTAssertNil(G.guidance(prePregnancyHeightCm: 160, prePregnancyWeightKg: 55,
                                latestWeightKg: nil, currentWeek: 20, fetusCount: 1))
        XCTAssertNil(G.guidance(prePregnancyHeightCm: 160, prePregnancyWeightKg: 55,
                                latestWeightKg: 60, currentWeek: nil, fetusCount: 1))
    }

    func test_guidance_computesCategoryGainPosition() {
        // 160cm·55kg → BMI 21.5(정상). 최신 60kg → 누적 +5.0kg. 20주.
        let g = KoreanGestationalWeightGain.guidance(
            prePregnancyHeightCm: 160, prePregnancyWeightKg: 55,
            latestWeightKg: 60, currentWeek: 20, fetusCount: 1)
        XCTAssertEqual(g?.category, .normal)
        XCTAssertEqual(g?.week, 20)
        XCTAssertEqual(g?.cumulativeGainKg ?? -1, 5.0, accuracy: 0.001)
        // 20주 정상 밴드 ≈ 3.35~5.37 → 5.0 within
        XCTAssertEqual(g?.position, .within)
    }

    func test_guidance_defaultsNilFetusCountToSingleton() {
        // fetusCount nil → 1(단태아)로 해석, 밴드 노출
        XCTAssertNotNil(KoreanGestationalWeightGain.guidance(
            prePregnancyHeightCm: 160, prePregnancyWeightKg: 55,
            latestWeightKg: 60, currentWeek: 20, fetusCount: nil))
    }

    // MARK: - 기준 정보(임신 전 키·체중) 영속화 — owner path

    @MainActor
    func test_setPrePregnancyBaseline_persistsToOwnerPath() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        // 파트너(partner-uid)가 입력해도 owner-uid 경로로 저장돼야 함(#41)
        await vm.setPrePregnancyBaseline(heightCm: 162, weightKg: 55, userId: "partner-uid")
        XCTAssertEqual(vm.activePregnancy?.prePregnancyHeight, 162)
        XCTAssertEqual(vm.activePregnancy?.prePregnancyWeight, 55)
        XCTAssertEqual(mock.savePregnancyUserIds.last, "owner-uid")
    }

    // MARK: - M2: 공유 임신 데이터는 owner 경로로 저장

    @MainActor
    func test_addVitalEntry_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        // 파트너(partner-uid)가 입력해도 owner-uid 경로로 저장돼야 함
        await vm.addVitalEntry(PregnancyVitalEntry(pregnancyId: shared.id, glucose: 90), userId: "partner-uid")
        XCTAssertEqual(mock.saveVitalEntryUserIds.last, "owner-uid")
    }

    /// 파트너가 토글해도 체크리스트 저장은 owner 경로로 가야 한다 (#41 격리).
    @MainActor
    func test_toggleChecklistItem_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        let item = PregnancyChecklistItem(pregnancyId: shared.id, title: "엽산", category: "trimester1")
        await vm.toggleChecklistItem(item, userId: "partner-uid")
        XCTAssertEqual(mock.saveChecklistItemUserIds.last, "owner-uid")
    }

    /// 파트너가 항목을 추가해도 owner 경로로 저장돼야 한다 (#41 격리).
    @MainActor
    func test_addChecklistItem_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        await vm.addChecklistItem(title: "병원 예약", userId: "partner-uid")
        XCTAssertEqual(mock.saveChecklistItemUserIds.last, "owner-uid")
    }

    /// 파트너가 검진을 저장/토글해도 owner 경로로 가야 한다 (#41 격리).
    @MainActor
    func test_savePrenatalVisit_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        let visit = PrenatalVisit(pregnancyId: shared.id, scheduledAt: Date())
        await vm.savePrenatalVisit(visit, userId: "partner-uid")
        XCTAssertEqual(mock.savePrenatalVisitUserIds.last, "owner-uid")
    }

    /// 파트너가 체중을 기록해도 owner 경로로 저장돼야 한다 (#41 격리).
    @MainActor
    func test_addWeightEntry_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        let entry = PregnancyWeightEntry(pregnancyId: shared.id, weight: 60, unit: "kg", measuredAt: Date())
        await vm.addWeightEntry(entry, userId: "partner-uid")
        XCTAssertEqual(mock.saveWeightEntryUserIds.last, "owner-uid")
    }

    /// 파트너가 증상을 기록해도 owner 경로로 저장돼야 한다 (#41 격리).
    @MainActor
    func test_addSymptom_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        let symptom = PregnancySymptom(pregnancyId: shared.id, memo: "메모", occurredAt: Date())
        await vm.addSymptom(symptom, userId: "partner-uid")
        XCTAssertEqual(mock.saveSymptomUserIds.last, "owner-uid")
    }

    // MARK: - 정서기록 (PregnancyMood) — 가벼운 기분 체크인

    func test_pregnancyMood_codableRoundtrip() throws {
        let m = PregnancyMood(pregnancyId: "p1", mood: .good, memo: "산책함", occurredAt: Date())
        let data = try JSONEncoder().encode(m)
        let decoded = try JSONDecoder().decode(PregnancyMood.self, from: data)
        XCTAssertEqual(decoded.mood, .good)
        XCTAssertEqual(decoded.memo, "산책함")
    }

    func test_mood_allCasesHaveDisplayAndEmoji() {
        for mood in PregnancyMood.Mood.allCases {
            XCTAssertFalse(mood.displayName.isEmpty)
            XCTAssertFalse(mood.emoji.isEmpty)
        }
    }

    func test_mood_rawValuesStableForPersistence() {
        // rawValue = Firestore 영구 저장값. 변경 금지.
        XCTAssertEqual(PregnancyMood.Mood.great.rawValue, "great")
        XCTAssertEqual(PregnancyMood.Mood.hard.rawValue, "hard")
        XCTAssertEqual(PregnancyMood.Mood.allCases.count, 5)
    }

    @MainActor
    func test_addMood_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        // 파트너가 기록해도 owner 경로로 저장돼야 함(#41)
        await vm.addMood(PregnancyMood(pregnancyId: shared.id, mood: .good), userId: "partner-uid")
        XCTAssertEqual(mock.saveMoodUserIds.last, "owner-uid")
        XCTAssertEqual(vm.moods.first?.mood, .good)
    }

    // MARK: - 증상 주차별 추천칩 (PregnancySymptomCatalog)

    func test_recommendedChips_earlyWeekIncludesNausea() {
        // 초기(8주)엔 입덧이 추천됨
        let chips = PregnancySymptomCatalog.recommended(forWeek: 8)
        XCTAssertTrue(chips.contains { $0.label.contains("입덧") })
    }

    func test_recommendedChips_lateWeekIncludesEdema() {
        // 후기(34주)엔 부종이 추천됨
        let chips = PregnancySymptomCatalog.recommended(forWeek: 34)
        XCTAssertTrue(chips.contains { $0.label.contains("부종") })
    }

    func test_recommendedChips_earlyWeekExcludesLateOnly() {
        // 후기 전용(부종)은 초기(8주) 추천에 없음
        let chips = PregnancySymptomCatalog.recommended(forWeek: 8)
        XCTAssertFalse(chips.contains { $0.label.contains("부종") })
    }

    func test_recommendedChips_neverIncludeUrgent() {
        // 응급 가능 증상은 '흔한 증상' 추천칩에 섞이지 않음
        for week in [6, 20, 38] {
            let chips = PregnancySymptomCatalog.recommended(forWeek: week)
            XCTAssertFalse(chips.contains { $0.isUrgent }, "week \(week)")
        }
    }

    func test_recommendedChips_allHaveLabels() {
        let chips = PregnancySymptomCatalog.recommended(forWeek: 20)
        XCTAssertFalse(chips.isEmpty)
        XCTAssertTrue(chips.allSatisfy { !$0.label.isEmpty })
    }

    func test_urgentChips_nonEmptyAndFlagged() {
        XCTAssertFalse(PregnancySymptomCatalog.urgent.isEmpty)
        XCTAssertTrue(PregnancySymptomCatalog.urgent.allSatisfy { $0.isUrgent })
        XCTAssertTrue(PregnancySymptomCatalog.urgent.contains { $0.label.contains("출혈") })
    }

    func test_urgentNotice_isNonDiagnostic() {
        // 위험도 판정 금지 — 의료진 연락 안내만
        let notice = PregnancySymptomCatalog.urgentNotice
        XCTAssertTrue(notice.contains("연락"))
        XCTAssertFalse(notice.isEmpty)
    }
}
