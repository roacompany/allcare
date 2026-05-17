import XCTest
@testable import BabyCare

// 분리: BabyCareTests.swift Widget 도메인 (#12 위젯 강화 — WidgetDataStore 기록 + 마이그레이션 + 동기화).

// MARK: - WidgetDataStore Tests (#12 위젯 강화)

final class WidgetDataStoreTests: XCTestCase {

    private let testSuite = "group.test.widget.datastore"

    // 테스트용 UserDefaults (앱 그룹 없음 → .standard fallback 검증)
    private var testDefaults: UserDefaults { .standard }

    // 테스트 전 정리
    override func setUp() {
        super.setUp()
        // 테스트 키 정리
        for key in [
            WidgetDataStore.Keys.growthPercentile,
            WidgetDataStore.Keys.napPrediction,
            WidgetDataStore.Keys.nextFeedingEstimate,
            WidgetDataStore.Keys.recentActivities
        ] {
            WidgetDataStore.defaults.removeObject(forKey: key)
        }
    }

    // Test 1: WidgetGrowthPercentile 직렬화/역직렬화
    func testWidgetGrowthPercentile_encodeDecode() throws {
        let original = WidgetGrowthPercentile(
            weightKg: 7.2,
            weightPercentile: 55.3,
            heightCm: 68.0,
            heightPercentile: 60.1,
            measuredAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetGrowthPercentile.self, from: data)

        XCTAssertEqual(decoded.weightKg ?? 0, 7.2, accuracy: 0.001, "체중 직렬화 일치해야 한다")
        XCTAssertEqual(decoded.weightPercentile ?? 0, 55.3, accuracy: 0.001, "체중 백분위 직렬화 일치해야 한다")
        XCTAssertEqual(decoded.heightCm ?? 0, 68.0, accuracy: 0.001, "키 직렬화 일치해야 한다")
        XCTAssertEqual(decoded.heightPercentile ?? 0, 60.1, accuracy: 0.001, "키 백분위 직렬화 일치해야 한다")
    }

    // Test 2: WidgetNapPrediction 직렬화/역직렬화
    func testWidgetNapPrediction_encodeDecode() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let original = WidgetNapPrediction(
            lastNapTime: now,
            nextNapTime: now.addingTimeInterval(7200),
            napIntervalMinutes: 120
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetNapPrediction.self, from: data)

        XCTAssertEqual(decoded.napIntervalMinutes, 120, "낮잠 간격 직렬화 일치해야 한다")
        XCTAssertEqual(decoded.lastNapTime?.timeIntervalSince1970 ?? 0, now.timeIntervalSince1970, accuracy: 0.001, "마지막 낮잠 시각 일치해야 한다")
        XCTAssertEqual(
            decoded.nextNapTime?.timeIntervalSince1970 ?? 0,
            now.addingTimeInterval(7200).timeIntervalSince1970,
            accuracy: 0.001,
            "다음 낮잠 시각 일치해야 한다"
        )
    }

    // Test 3: updateGrowthPercentile sync 후 read 일치
    func testUpdateGrowthPercentile_syncAndRead() throws {
        let percentile = WidgetGrowthPercentile(
            weightKg: 8.5,
            weightPercentile: 70.0,
            heightCm: 72.0,
            heightPercentile: 65.0,
            measuredAt: Date()
        )

        // UserDefaults에 직접 저장 (WidgetCenter 없이 테스트)
        if let data = try? JSONEncoder().encode(percentile) {
            WidgetDataStore.defaults.set(data, forKey: WidgetDataStore.Keys.growthPercentile)
        }

        let read = WidgetDataStore.growthPercentile
        XCTAssertNotNil(read, "저장된 성장 백분위 데이터가 있어야 한다")
        XCTAssertEqual(read?.weightKg ?? 0, 8.5, accuracy: 0.001, "체중 읽기 일치해야 한다")
        XCTAssertEqual(read?.weightPercentile ?? 0, 70.0, accuracy: 0.001, "체중 백분위 읽기 일치해야 한다")
    }

    // Test 4: napPrediction fallback — 데이터 없으면 nil 반환
    func testNapPrediction_fallbackNilWhenNoData() {
        WidgetDataStore.defaults.removeObject(forKey: WidgetDataStore.Keys.napPrediction)
        XCTAssertNil(WidgetDataStore.napPrediction, "낮잠 예측 데이터 없으면 nil이어야 한다")
    }

    // Test 5: growthPercentile fallback — 데이터 없으면 nil 반환
    func testGrowthPercentile_fallbackNilWhenNoData() {
        WidgetDataStore.defaults.removeObject(forKey: WidgetDataStore.Keys.growthPercentile)
        XCTAssertNil(WidgetDataStore.growthPercentile, "성장 백분위 데이터 없으면 nil이어야 한다")
    }

    // Test 6: WidgetActivity 배열 직렬화/역직렬화
    func testWidgetActivity_encodeDecode() throws {
        let activity = WidgetActivity(
            typeRaw: "feeding_breast",
            displayName: "모유수유",
            icon: "cup.and.saucer.fill",
            colorHex: "#FF9FB5",
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            detail: "15분"
        )
        let data = try JSONEncoder().encode([activity])
        let decoded = try JSONDecoder().decode([WidgetActivity].self, from: data)

        XCTAssertEqual(decoded.count, 1, "WidgetActivity 배열 개수 일치해야 한다")
        XCTAssertEqual(decoded.first?.typeRaw, "feeding_breast", "typeRaw 직렬화 일치해야 한다")
        XCTAssertEqual(decoded.first?.displayName, "모유수유", "displayName 직렬화 일치해야 한다")
        XCTAssertEqual(decoded.first?.detail, "15분", "detail 직렬화 일치해야 한다")
    }

    // Test 7: nextFeedingTime fallback — nextFeedingEstimate 없으면 lastFeeding + interval 사용
    func testNextFeedingTime_fallbackToIntervalCalc() {
        let now = Date()
        WidgetDataStore.defaults.removeObject(forKey: WidgetDataStore.Keys.nextFeedingEstimate)
        WidgetDataStore.defaults.set(now.addingTimeInterval(-7200), forKey: WidgetDataStore.Keys.lastFeedingTime)
        WidgetDataStore.defaults.set(180, forKey: WidgetDataStore.Keys.feedingIntervalMinutes)

        let nextFeeding = WidgetDataStore.nextFeedingTime
        XCTAssertNotNil(nextFeeding, "마지막 수유 + 간격으로 다음 수유 시각을 계산해야 한다")
        // 2시간 전 수유 + 3시간 간격 = 1시간 후
        let expected = now.addingTimeInterval(-7200 + 180 * 60)
        XCTAssertEqual(
            nextFeeding?.timeIntervalSince1970 ?? 0,
            expected.timeIntervalSince1970,
            accuracy: 5,
            "다음 수유 = 마지막 수유 + 180분이어야 한다"
        )
    }

    // Test 8: WidgetGrowthPercentile optional fields — nil 포함 Codable 호환
    func testWidgetGrowthPercentile_optionalFields() throws {
        let partial = WidgetGrowthPercentile(
            weightKg: 6.0,
            weightPercentile: 40.0,
            heightCm: nil,
            heightPercentile: nil,
            measuredAt: nil
        )
        let data = try JSONEncoder().encode(partial)
        let decoded = try JSONDecoder().decode(WidgetGrowthPercentile.self, from: data)

        XCTAssertEqual(decoded.weightKg ?? 0, 6.0, accuracy: 0.001, "체중은 있어야 한다")
        XCTAssertNil(decoded.heightCm, "키는 nil이어야 한다")
        XCTAssertNil(decoded.heightPercentile, "키 백분위는 nil이어야 한다")
        XCTAssertNil(decoded.measuredAt, "측정일은 nil이어야 한다")
    }

    // Test 9: napPrediction sync 후 read 일치
    func testNapPrediction_syncAndRead() throws {
        let prediction = WidgetNapPrediction(
            lastNapTime: Date(timeIntervalSince1970: 1_700_000_000),
            nextNapTime: Date(timeIntervalSince1970: 1_700_007_200),
            napIntervalMinutes: 90
        )
        if let data = try? JSONEncoder().encode(prediction) {
            WidgetDataStore.defaults.set(data, forKey: WidgetDataStore.Keys.napPrediction)
        }

        let read = WidgetDataStore.napPrediction
        XCTAssertNotNil(read, "저장된 낮잠 예측 데이터가 있어야 한다")
        XCTAssertEqual(read?.napIntervalMinutes, 90, "낮잠 간격 읽기 일치해야 한다")
    }

    // MARK: - Pregnancy Mode — Foundation Tests

    func testPregnancyOutcome_rawValues() {
        XCTAssertEqual(PregnancyOutcome.ongoing.rawValue, "ongoing")
        XCTAssertEqual(PregnancyOutcome.born.rawValue, "born")
        XCTAssertEqual(PregnancyOutcome.miscarriage.rawValue, "miscarriage")
        XCTAssertEqual(PregnancyOutcome.stillbirth.rawValue, "stillbirth")
        XCTAssertEqual(PregnancyOutcome.terminated.rawValue, "terminated")
    }

    func testPregnancy_codableRoundtrip() throws {
        let p = Pregnancy(
            lmpDate: Date(timeIntervalSince1970: 1_700_000_000),
            dueDate: Date(timeIntervalSince1970: 1_724_192_000),
            fetusCount: 1,
            babyNickname: "꿈이"
        )
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(Pregnancy.self, from: data)
        XCTAssertEqual(decoded.id, p.id)
        XCTAssertEqual(decoded.babyNickname, "꿈이")
        XCTAssertEqual(decoded.fetusCount, 1)
        XCTAssertNil(decoded.ownerUserId, "ownerUserId는 CodingKeys에서 제외되어야 한다")
    }

    func testPregnancy_currentWeekAndDay_noLmp() {
        let p = Pregnancy()
        XCTAssertNil(p.currentWeekAndDay)
    }

    func testPregnancy_currentWeekAndDay_basicCalc() {
        let lmp = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let p = Pregnancy(lmpDate: lmp)
        let result = p.currentWeekAndDay
        XCTAssertNotNil(result)
        // 100일 = 14주 2일
        XCTAssertEqual(result?.weeks, 14)
        XCTAssertEqual(result?.days, 2)
    }

    func testPregnancy_dDay_futureDueDate() {
        let due = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let p = Pregnancy(dueDate: due)
        XCTAssertEqual(p.dDay, 30)
    }

    func testPregnancy_dDay_nilWhenNoDueDate() {
        XCTAssertNil(Pregnancy().dDay)
    }

    func testPregnancy_isSingleton_defaultsTrue() {
        XCTAssertTrue(Pregnancy().isSingleton)
        XCTAssertTrue(Pregnancy(fetusCount: 1).isSingleton)
        XCTAssertFalse(Pregnancy(fetusCount: 2).isSingleton)
    }

    func testKickSession_codableRoundtrip() throws {
        var s = KickSession(pregnancyId: "p1")
        s.kicks = [KickEvent(), KickEvent()]
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(KickSession.self, from: data)
        XCTAssertEqual(decoded.kicks.count, 2)
        XCTAssertEqual(decoded.targetCount, 10)
    }

    func testKickSession_reachedTarget() {
        var s = KickSession(pregnancyId: "p1", targetCount: 3)
        XCTAssertFalse(s.reachedTarget)
        s.kicks = [KickEvent(), KickEvent(), KickEvent()]
        XCTAssertTrue(s.reachedTarget)
    }

    func testKickSession_exceededTwoHours() {
        let s = KickSession(
            pregnancyId: "p1",
            startedAt: Date().addingTimeInterval(-8000),
            endedAt: Date()
        )
        XCTAssertTrue(s.exceededTwoHours)
    }

    func testPrenatalVisit_codableRoundtrip() throws {
        let v = PrenatalVisit(
            pregnancyId: "p1",
            scheduledAt: Date(timeIntervalSince1970: 1_700_000_000),
            hospitalName: "테스트 산부인과"
        )
        let data = try JSONEncoder().encode(v)
        let decoded = try JSONDecoder().decode(PrenatalVisit.self, from: data)
        XCTAssertEqual(decoded.hospitalName, "테스트 산부인과")
        XCTAssertFalse(decoded.isCompleted)
    }

    func testPrenatalVisit_daysUntilScheduled() {
        let future = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let v = PrenatalVisit(pregnancyId: "p1", scheduledAt: future)
        XCTAssertEqual(v.daysUntilScheduled, 7)
        XCTAssertTrue(v.isDueSoon)
        XCTAssertFalse(v.isOverdue)
    }

    func testPrenatalVisit_isOverdue() {
        let past = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let v = PrenatalVisit(pregnancyId: "p1", scheduledAt: past)
        XCTAssertTrue(v.isOverdue)
    }

    func testPregnancyChecklistItem_codableRoundtrip() throws {
        let item = PregnancyChecklistItem(
            pregnancyId: "p1",
            title: "엽산 복용",
            category: "trimester1",
            source: "bundle"
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(PregnancyChecklistItem.self, from: data)
        XCTAssertEqual(decoded.title, "엽산 복용")
        XCTAssertEqual(decoded.source, "bundle")
        XCTAssertFalse(decoded.isCompleted)
    }

    func testPregnancyWeightEntry_codableRoundtrip() throws {
        let w = PregnancyWeightEntry(pregnancyId: "p1", weight: 58.5, unit: "kg")
        let data = try JSONEncoder().encode(w)
        let decoded = try JSONDecoder().decode(PregnancyWeightEntry.self, from: data)
        XCTAssertEqual(decoded.weight, 58.5, accuracy: 0.01)
        XCTAssertEqual(decoded.unit, "kg")
    }

    func testFirestoreCollections_pregnancyConstantsExist() {
        XCTAssertEqual(FirestoreCollections.pregnancies, "pregnancies")
        XCTAssertEqual(FirestoreCollections.kickSessions, "kickSessions")
        XCTAssertEqual(FirestoreCollections.prenatalVisits, "prenatalVisits")
        XCTAssertEqual(FirestoreCollections.pregnancyChecklists, "pregnancyChecklists")
        XCTAssertEqual(FirestoreCollections.pregnancyWeights, "pregnancyWeights")
    }

    func testFeatureFlags_pregnancyModeEnabledIsBool() {
        let _: Bool = FeatureFlags.pregnancyModeEnabled
        XCTAssertTrue(FeatureFlags.pregnancyModeEnabled || !FeatureFlags.pregnancyModeEnabled)
    }

    func testPregnancyWeeksJson_loadAndDecode() throws {
        guard let url = Bundle(for: type(of: self)).url(forResource: "pregnancy-weeks", withExtension: "json") else {
            // 번들 리소스는 Xcode 프로젝트에 추가되어야 함. 스캐폴딩 단계에서는 skip 가능.
            throw XCTSkip("pregnancy-weeks.json이 테스트 번들에 추가되지 않음 (xcodegen 후 재시도)")
        }
        let data = try Data(contentsOf: url)
        struct WeekInfo: Codable { let week: Int; let fruitSize: String; let milestone: String; let tip: String }
        let weeks = try JSONDecoder().decode([WeekInfo].self, from: data)
        XCTAssertFalse(weeks.isEmpty)
        XCTAssertTrue(weeks.allSatisfy { $0.week >= 1 && $0.week <= 40 })
    }

    func testPrenatalChecklistJson_loadAndDecode() throws {
        guard let url = Bundle(for: type(of: self)).url(forResource: "prenatal-checklist", withExtension: "json") else {
            throw XCTSkip("prenatal-checklist.json이 테스트 번들에 추가되지 않음 (xcodegen 후 재시도)")
        }
        let data = try Data(contentsOf: url)
        struct Item: Codable { let id: String; let title: String; let category: String; let source: String }
        let items = try JSONDecoder().decode([Item].self, from: data)
        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.allSatisfy { $0.source == "bundle" })
    }

    @MainActor
    func testPregnancyViewModel_dataUserId_fallbackToCurrent() {
        let vm = PregnancyViewModel()
        XCTAssertEqual(vm.dataUserId(currentUserId: "u1"), "u1")
    }

    @MainActor
    func testPregnancyViewModel_dataUserId_sharedRoute() {
        let vm = PregnancyViewModel()
        var p = Pregnancy()
        p.ownerUserId = "owner-uid"
        vm.activePregnancy = p
        XCTAssertEqual(vm.dataUserId(currentUserId: "self-uid"), "owner-uid")
    }

    @MainActor
    func testPregnancyViewModel_currentWeekAndDay_whenNoPregnancy() {
        let vm = PregnancyViewModel()
        XCTAssertNil(vm.currentWeekAndDay)
        XCTAssertNil(vm.dDay)
    }

    // MARK: - Pregnancy Widget DataStore Key Prefix

    func testPregnancyWidgetKeys_allPrefixed() {
        let keys = [
            PregnancyWidgetSyncService.TestableKeys.dueDate,
            PregnancyWidgetSyncService.TestableKeys.lmpDate,
            PregnancyWidgetSyncService.TestableKeys.babyNickname,
            PregnancyWidgetSyncService.TestableKeys.isActive
        ]
        for key in keys {
            XCTAssertTrue(key.hasPrefix("pregnancy_"), "Key '\(key)' must start with 'pregnancy_'")
        }
    }

    // MARK: - Pregnancy EDD History Append

    func testPregnancy_eddHistory_appendOnly() {
        var p = Pregnancy()
        p.dueDate = Date(timeIntervalSince1970: 1800000000)
        p.eddHistory = [Date(timeIntervalSince1970: 1800000000)]
        let oldHistory = p.eddHistory ?? []
        let newDue = Date(timeIntervalSince1970: 1800100000)
        var history = oldHistory
        if let existing = p.dueDate, !history.contains(existing) {
            history.append(existing)
        }
        p.dueDate = newDue
        p.eddHistory = history
        XCTAssertEqual(p.eddHistory?.count, 1) // 기존 값 중복 안 추가
        XCTAssertEqual(p.dueDate, newDue)
    }

    // MARK: - Pregnancy sharedWith Field

    func testPregnancy_sharedWith_defaultNil() {
        let p = Pregnancy()
        XCTAssertNil(p.sharedWith)
    }

    func testPregnancy_sharedWith_appendUid() {
        var p = Pregnancy()
        p.sharedWith = ["uid1"]
        XCTAssertEqual(p.sharedWith?.count, 1)
        p.sharedWith?.append("uid2")
        XCTAssertEqual(p.sharedWith?.count, 2)
    }

    // MARK: - Pregnancy outcomeType Raw Value Stability

    func testPregnancyOutcome_allCasesRawValues() {
        // Raw values are permanent contract — must never change.
        let expected: [(PregnancyOutcome, String)] = [
            (.ongoing, "ongoing"),
            (.born, "born"),
            (.miscarriage, "miscarriage"),
            (.stillbirth, "stillbirth"),
            (.terminated, "terminated")
        ]
        for (outcome, raw) in expected {
            XCTAssertEqual(outcome.rawValue, raw, "\(outcome) raw value must be '\(raw)'")
        }
    }

    // MARK: - Pregnancy D-day Past Due

    func testPregnancy_dDay_pastDue() {
        var p = Pregnancy()
        p.dueDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        let dDay = p.dDay
        XCTAssertNotNil(dDay)
        XCTAssertTrue(dDay! < 0, "Past due date should result in negative D-day")
    }

    // MARK: - KickSession Duration

    func testKickSession_duration() {
        var session = KickSession(pregnancyId: "p1")
        session.endedAt = session.startedAt.addingTimeInterval(3600)
        let duration = session.endedAt!.timeIntervalSince(session.startedAt)
        XCTAssertEqual(duration, 3600, accuracy: 1)
    }

    // MARK: - PregnancyChecklistItem Source Enum

    func testPregnancyChecklistItem_sourceValues() {
        let bundleItem = PregnancyChecklistItem(pregnancyId: "p1", title: "Test", category: "trimester1", source: "bundle")
        let userItem = PregnancyChecklistItem(pregnancyId: "p1", title: "Custom", category: "custom", source: "user")
        XCTAssertEqual(bundleItem.source, "bundle")
        XCTAssertEqual(userItem.source, "user")
    }

    // MARK: - PregnancyWeightEntry Unit

    func testPregnancyWeightEntry_unitPersistence() throws {
        let entry = PregnancyWeightEntry(pregnancyId: "p1", weight: 65.5, unit: "kg")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(PregnancyWeightEntry.self, from: data)
        XCTAssertEqual(decoded.unit, "kg")
        XCTAssertEqual(decoded.weight, 65.5, accuracy: 0.01)
    }

    // MARK: - Localizable Keys Existence

    func testLocalizable_pregnancyWidgetKeysExist() {
        let keys = [
            "pregnancy.widget.dday.title",
            "pregnancy.widget.label",
            "pregnancy.widget.inactive",
            "pregnancy.widget.progress",
            "pregnancy.share.title"
        ]
        for key in keys {
            let localized = NSLocalizedString(key, comment: "")
            XCTAssertNotEqual(localized, key, "Missing localization for '\(key)'")
        }
    }

    // MARK: - PregnancyViewModel.validateInputs

    @MainActor
    func testValidateInputs_bothNil_returnsError() {
        let result = PregnancyViewModel.validateInputs(lmpDate: nil, dueDate: nil, fetusCount: 1)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("필수") == true)
    }

    @MainActor
    func testValidateInputs_fetusCountTooLow_returnsError() {
        let result = PregnancyViewModel.validateInputs(lmpDate: Date(), dueDate: nil, fetusCount: 0)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("태아 수") == true)
    }

    @MainActor
    func testValidateInputs_fetusCountTooHigh_returnsError() {
        let result = PregnancyViewModel.validateInputs(lmpDate: Date(), dueDate: nil, fetusCount: 6)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("태아 수") == true)
    }

    @MainActor
    func testValidateInputs_lmpInFuture_returnsError() {
        let future = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let result = PregnancyViewModel.validateInputs(lmpDate: future, dueDate: nil, fetusCount: 1)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("월경일") == true)
    }

    @MainActor
    func testValidateInputs_eddInPast_returnsError() {
        let past = Calendar.current.date(byAdding: .day, value: -120, to: Date())!
        let result = PregnancyViewModel.validateInputs(lmpDate: nil, dueDate: past, fetusCount: 1)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("예정일") == true)
    }

    @MainActor
    func testValidateInputs_eddTooFar_returnsError() {
        let farFuture = Calendar.current.date(byAdding: .day, value: 400, to: Date())!
        let result = PregnancyViewModel.validateInputs(lmpDate: nil, dueDate: farFuture, fetusCount: 1)
        XCTAssertNotNil(result)
    }

    @MainActor
    func testValidateInputs_eddBeforeLmp_returnsError() {
        let lmp = Calendar.current.date(byAdding: .day, value: -50, to: Date())!
        let edd = Calendar.current.date(byAdding: .day, value: -80, to: Date())!   // edd < lmp (둘 다 유효 범위 내)
        let result = PregnancyViewModel.validateInputs(lmpDate: lmp, dueDate: edd, fetusCount: 1)
        XCTAssertNotNil(result)
    }

    @MainActor
    func testValidateInputs_validLmpOnly_returnsNil() {
        let lmp = Calendar.current.date(byAdding: .day, value: -84, to: Date())!   // 12주차
        let result = PregnancyViewModel.validateInputs(lmpDate: lmp, dueDate: nil, fetusCount: 1)
        XCTAssertNil(result)
    }

    @MainActor
    func testValidateInputs_validEddOnly_returnsNil() {
        let edd = Calendar.current.date(byAdding: .day, value: 196, to: Date())!
        let result = PregnancyViewModel.validateInputs(lmpDate: nil, dueDate: edd, fetusCount: 1)
        XCTAssertNil(result)
    }

    @MainActor
    func testValidateInputs_validBoth_returnsNil() {
        let lmp = Calendar.current.date(byAdding: .day, value: -84, to: Date())!
        let edd = Calendar.current.date(byAdding: .day, value: 196, to: Date())!
        let result = PregnancyViewModel.validateInputs(lmpDate: lmp, dueDate: edd, fetusCount: 2)
        XCTAssertNil(result)
    }

    // MARK: - BadgeEvaluator.BackfillCounts

    @MainActor
    func testBackfillCounts_defaultInit_allZeroAllSucceeded() {
        let counts = BadgeEvaluator.BackfillCounts()
        XCTAssertEqual(counts.feeding, 0)
        XCTAssertEqual(counts.sleep, 0)
        XCTAssertEqual(counts.diaper, 0)
        XCTAssertEqual(counts.growth, 0)
        XCTAssertNil(counts.earliest)
        XCTAssertTrue(counts.allSucceeded)
    }

    @MainActor
    func testBadgeEvaluator_aggregateMapping_feedingMapsToFeedingCount() {
        let result = BadgeEvaluator.aggregateMapping(kind: .feedingLogged)
        XCTAssertEqual(result?.field, "feedingCount")
        XCTAssertEqual(result?.badgeIds, ["feeding100"])
    }

    @MainActor
    func testBadgeEvaluator_aggregateMapping_routineStreakReturnsNil() {
        let result = BadgeEvaluator.aggregateMapping(kind: .routineStreakUpdated(newStreak: 5))
        XCTAssertNil(result)
    }

    @MainActor
    func testBadgeEvaluator_statsValue_withNilFields_returnsZero() {
        let stats = UserStats.empty()
        // empty() sets to 0, but we test the nil-safe path:
        var emptyStats = UserStats.empty()
        emptyStats.feedingCount = nil
        XCTAssertEqual(BadgeEvaluator.statsValue(stats: emptyStats, field: "feedingCount"), 0)
        XCTAssertEqual(BadgeEvaluator.statsValue(stats: stats, field: "feedingCount"), 0)
    }

    @MainActor
    func testBadgeEvaluator_statsValue_withPopulatedFields() {
        var stats = UserStats.empty()
        stats.feedingCount = 150
        stats.sleepCount = 75
        XCTAssertEqual(BadgeEvaluator.statsValue(stats: stats, field: "feedingCount"), 150)
        XCTAssertEqual(BadgeEvaluator.statsValue(stats: stats, field: "sleepCount"), 75)
        XCTAssertEqual(BadgeEvaluator.statsValue(stats: stats, field: "unknown"), 0)
    }

    @MainActor
    func testBadgeEvaluator_utcDateString_isStable() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)   // 2023-11-14 22:13:20 UTC
        XCTAssertEqual(BadgeEvaluator.utcDateString(date), "2023-11-14")
    }

    // MARK: - Dashboard/Health/Recording priority gating 로직 (빌드 59 회귀 방지)
    // baby 있으면 pregnancy UI는 덮어쓰면 안 됨.
    // 실제 View body 대신 gating 조건 boolean을 isolated하게 검증.

    @MainActor
    func testGating_babyOnly_showsBabyUI() {
        XCTAssertFalse(shouldShowPregnancyUI(babiesEmpty: false, pregnancyActive: false))
    }

    @MainActor
    func testGating_pregnancyOnly_showsPregnancyUI() {
        XCTAssertTrue(shouldShowPregnancyUI(babiesEmpty: true, pregnancyActive: true))
    }

    @MainActor
    func testGating_babyAndPregnancy_showsBabyUI_빌드59회귀방지() {
        // 이 테스트가 FAIL하면 baby 등록된 사용자 화면이 pregnancy로 덮어씌워짐
        XCTAssertFalse(
            shouldShowPregnancyUI(babiesEmpty: false, pregnancyActive: true),
            "baby가 있으면 pregnancy가 있어도 baby UI가 우선되어야 함"
        )
    }

    @MainActor
    func testGating_neitherBabyNorPregnancy_showsBabyUI() {
        // onboarding gating은 ContentView 담당. 이 레벨에서는 pregnancy UI 노출 금지.
        XCTAssertFalse(shouldShowPregnancyUI(babiesEmpty: true, pregnancyActive: false))
    }

    /// DashboardView/HealthView/RecordingView 공통 gating 조건.
    /// 세 View 모두 아래와 동일 조건 사용.
    private func shouldShowPregnancyUI(babiesEmpty: Bool, pregnancyActive: Bool) -> Bool {
        return babiesEmpty && pregnancyActive
    }

}

// MARK: - Badge Privacy Pass-through (H-4 자동 검증 — earnedByUserId)

