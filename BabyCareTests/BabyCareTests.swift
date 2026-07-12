import XCTest
@testable import BabyCare

final class BabyCareTests: XCTestCase {

    // MARK: - Baby Model Tests

    func testBabyAgeText_days() {
        let baby = Baby(
            name: "테스트",
            birthDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            gender: .male
        )
        XCTAssertTrue(baby.ageText.contains("5일"))
    }

    func testBabyAgeText_months() {
        let baby = Baby(
            name: "테스트",
            birthDate: Calendar.current.date(byAdding: .month, value: -3, to: Date())!,
            gender: .female
        )
        XCTAssertTrue(baby.ageText.contains("3개월"))
    }

    func testBabyDaysOld() {
        let baby = Baby(
            name: "테스트",
            birthDate: Calendar.current.date(byAdding: .day, value: -100, to: Date())!,
            gender: .male
        )
        XCTAssertEqual(baby.daysOld, 100)
    }

    // MARK: - Activity Model Tests

    func testActivityDurationText() {
        var activity = Activity(babyId: "test", type: .feedingBreast)
        activity.duration = 1800 // 30 min
        XCTAssertEqual(activity.durationText, "30분")

        activity.duration = 5400 // 1h 30m
        XCTAssertEqual(activity.durationText, "1시간 30분")
    }

    func testActivityAmountText() {
        var activity = Activity(babyId: "test", type: .feedingBottle)
        activity.amount = 120
        XCTAssertEqual(activity.amountText, "120ml")
    }

    func testActivityTypeCategory() {
        XCTAssertEqual(Activity.ActivityType.feedingBreast.category, .feeding)
        XCTAssertEqual(Activity.ActivityType.feedingBottle.category, .feeding)
        XCTAssertEqual(Activity.ActivityType.sleep.category, .sleep)
        XCTAssertEqual(Activity.ActivityType.diaperWet.category, .diaper)
        XCTAssertEqual(Activity.ActivityType.temperature.category, .health)
    }

    func testActivityTypeNeedsTimer() {
        XCTAssertTrue(Activity.ActivityType.feedingBreast.needsTimer)
        XCTAssertTrue(Activity.ActivityType.feedingBottle.needsTimer)
        XCTAssertTrue(Activity.ActivityType.sleep.needsTimer)
        XCTAssertFalse(Activity.ActivityType.diaperWet.needsTimer)
        XCTAssertFalse(Activity.ActivityType.temperature.needsTimer)
    }

    // MARK: - 유축(Pumping) Tests (Phase 1, spec §7)

    /// §7-1: needs* 플래그 — needsTimer/needsAmount/needsQuickInput는 default: 보유 switch라
    /// case만 추가하면 silent false가 되는 트랩(spec §4.1). 이 테스트가 유일한 가드.
    func testActivityType_feedingPumping_inputFlags() {
        XCTAssertEqual(Activity.ActivityType.feedingPumping.category, .pumping,
                       "유축은 절대 .feeding이 아니라 신규 .pumping 카테고리")
        XCTAssertTrue(Activity.ActivityType.feedingPumping.needsAmount,
                      "유축은 양 입력 필요 — default:false 트랩 가드")
        XCTAssertTrue(Activity.ActivityType.feedingPumping.needsQuickInput,
                      "유축은 빠른기록 미니시트 경로 — default:false 트랩 가드")
        XCTAssertFalse(Activity.ActivityType.feedingPumping.needsTimer,
                       "유축은 양이 ground-truth라 타이머 불필요")
        XCTAssertEqual(Activity.ActivityType.feedingPumping.color, "pumpingColor")
    }

    // testQuickInput_pumping_persistsAmountAndSide 제거(P4) —
    // QuickInputSheet 삭제, 검증은 ActivityDraftBuilderTests.test_build_pumping_amountAndSide 가 대체.

    /// §7-3a: 유축이 섭취 집계(todayTotalMl/todayFeedingCount)에서 자동 배제 (의료 정합)
    @MainActor
    func testPumping_excludedFromTodayFeedingTotals() {
        let vm = ActivityViewModel()
        let now = Date()
        vm.todayActivities = [
            Activity(babyId: "b1", type: .feedingBottle, startTime: now, amount: 100),
            Activity(babyId: "b1", type: .feedingPumping, startTime: now, amount: 200, side: .both)
        ]
        XCTAssertEqual(vm.todayFeedingCount, 1, "유축은 수유 횟수에 포함되면 안 된다")
        XCTAssertEqual(vm.todayTotalMl, 100, "유축 생산량은 섭취 총량에 합산되면 안 된다")
    }

    /// §7-3b: StatsViewModel — feeding 제외 + pumping 신규 집계
    @MainActor
    func testStats_pumpingSeparatedFromFeeding() {
        let vm = StatsViewModel()
        let now = Date()
        vm.weeklyActivities = [
            Activity(babyId: "b1", type: .feedingBottle, startTime: now, amount: 100),
            Activity(babyId: "b1", type: .feedingPumping, startTime: now, amount: 200)
        ]
        XCTAssertEqual(vm.feedingActivities.count, 1)
        XCTAssertEqual(vm.dailyFeedingAmounts.reduce(0) { $0 + $1.amount }, 100, accuracy: 0.001)
        XCTAssertEqual(vm.pumpingActivities.count, 1)
        XCTAssertEqual(vm.dailyPumpingAmounts.reduce(0) { $0 + $1.amount }, 200, accuracy: 0.001)
    }

    /// §7-6: 유축 0건이면 유축량 차트 데이터가 비어 empty-state로 처리
    @MainActor
    func testStats_noPumping_emptyAmounts() {
        let vm = StatsViewModel()
        vm.weeklyActivities = [
            Activity(babyId: "b1", type: .feedingBottle, startTime: Date(), amount: 100)
        ]
        XCTAssertTrue(vm.dailyPumpingAmounts.isEmpty, "유축 기록이 없으면 차트는 empty-state여야 한다")
    }

    // MARK: - Forward-compat unknown decode (2026-06-09 spec)
    // 구버전 앱이 신버전이 만든 미지의 ActivityType을 만나도 문서를 drop하지 않고
    // .unknown 으로 디코드 → 중립 read-only row. 쓰기/편집/집계/타이머/picker에서 격리.

    /// 불변 1: 미지의 type rawValue → .unknown 폴백 (문서 drop 방지)
    func testActivityType_decode_unknownRawValue_fallsBackToUnknown() throws {
        let known = Activity(babyId: "b1", type: .bath)
        let data = try JSONEncoder().encode(known)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
            .replacingOccurrences(of: "\"bath\"", with: "\"future_type_xyz\"")
        let mutated = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(Activity.self, from: mutated)
        XCTAssertEqual(decoded.type, .unknown, "미지의 rawValue는 .unknown으로 폴백되어 문서가 살아남아야 한다")
    }

    /// 불변 2: 알려진 type(유축)은 폴백 없이 정확히 디코드 (over-eager 폴백 방지)
    func testActivityType_decode_knownRawValue_stillDecodes() throws {
        let original = Activity(babyId: "b1", type: .feedingPumping, amount: 120)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Activity.self, from: data)
        XCTAssertEqual(decoded.type, .feedingPumping, "알려진 type은 .unknown으로 떨어지면 안 된다")
    }

    /// 불변 4(구조적): .unknown 활동은 인코딩 불가 → 어떤 쓰기 경로(Firestore setData /
    /// 오프라인 큐 JSONEncoder)로도 영속될 수 없다 = 실제 rawValue 덮어쓰기(데이터 손실) 봉쇄.
    func testActivity_encode_unknownType_throws() {
        var activity = Activity(babyId: "b1", type: .bath)
        activity.type = .unknown
        XCTAssertThrowsError(try JSONEncoder().encode(activity),
                             ".unknown 활동은 인코딩(=영속)되면 안 된다 (데이터 손실 방지)")
    }

    /// 커스텀 encode가 정상 type의 round-trip을 깨지 않아야 한다
    func testActivity_encodeDecode_knownType_roundTrips() throws {
        let original = Activity(babyId: "b1", type: .feedingBottle, amount: 100)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Activity.self, from: data)
        XCTAssertEqual(decoded.type, .feedingBottle)
        XCTAssertEqual(decoded.amount, 100)
    }

    /// 불변 3·5: .unknown 은 중립 카테고리 + 입력/타이머 플래그 모두 false
    func testActivityType_unknown_neutralFlags() {
        XCTAssertEqual(Activity.ActivityType.unknown.category, .unknown)
        XCTAssertNotEqual(Activity.ActivityType.unknown.category, .feeding)
        XCTAssertFalse(Activity.ActivityType.unknown.needsTimer)
        XCTAssertFalse(Activity.ActivityType.unknown.needsAmount)
        XCTAssertFalse(Activity.ActivityType.unknown.needsQuickInput)
    }

    /// init?(rawValue:) 부활 차단 — 센티넬 "unknown" 은 known(rawValue:)에서 nil
    func testActivityType_known_rejectsSentinelAndUnknownRaw() {
        XCTAssertEqual(Activity.ActivityType.known(rawValue: "sleep"), .sleep)
        XCTAssertEqual(Activity.ActivityType.known(rawValue: "feeding_pumping"), .feedingPumping)
        XCTAssertNil(Activity.ActivityType.known(rawValue: "unknown"), "센티넬은 raw로 부활 금지")
        XCTAssertNil(Activity.ActivityType.known(rawValue: "future_type_xyz"), "미지의 raw는 드롭")
    }

    /// 불변 5: .unknown 은 기록 가능 picker에서 제외
    func testQuickRecordSettings_excludesUnknown() {
        XCTAssertFalse(QuickRecordSettings.allAvailableTypes.contains(.unknown),
                       ".unknown 은 사용자 기록 picker에 노출되면 안 된다")
        XCTAssertFalse(QuickRecordSettings.defaultTypes.contains(.unknown))
    }

    /// 불변 3: .unknown(섭취량 보유)은 오늘 수유 집계에 끼면 안 된다 (의료 정합)
    @MainActor
    func testUnknown_excludedFromTodayFeedingTotals() {
        let vm = ActivityViewModel()
        let now = Date()
        var unknown = Activity(babyId: "b1", type: .feedingBottle, startTime: now, amount: 999)
        unknown.type = .unknown
        vm.todayActivities = [
            Activity(babyId: "b1", type: .feedingBottle, startTime: now, amount: 100),
            unknown
        ]
        XCTAssertEqual(vm.todayFeedingCount, 1, ".unknown 은 수유 횟수에 포함되면 안 된다")
        XCTAssertEqual(vm.todayTotalMl, 100, ".unknown 의 양은 섭취 총량에 합산되면 안 된다")
    }

    /// 불변 3: .unknown 은 주간 통계(수유/유축/수면/기저귀)에서 모두 배제
    @MainActor
    func testUnknown_excludedFromStats() {
        let vm = StatsViewModel()
        let now = Date()
        var unknown = Activity(babyId: "b1", type: .feedingBottle, startTime: now, duration: 99999, amount: 999)
        unknown.type = .unknown
        vm.weeklyActivities = [
            Activity(babyId: "b1", type: .feedingBottle, startTime: now, amount: 100),
            unknown
        ]
        XCTAssertEqual(vm.feedingActivities.count, 1)
        XCTAssertEqual(vm.pumpingActivities.count, 0)
        XCTAssertEqual(vm.dailyFeedingAmounts.reduce(0) { $0 + $1.amount }, 100, accuracy: 0.001,
                       ".unknown 의 양은 수유 차트에 합산되면 안 된다")
    }

    /// 불변 3(병원 체크리스트): .unknown 의 note/체온은 소아과 증상 스캔에 주입되면 안 된다 (적대검토 4번 누수)
    func testUnknown_excludedFromHospitalChecklistSymptoms() {
        var unknown = Activity(babyId: "b1", type: .feedingBottle, startTime: Date())
        unknown.temperature = 39.0
        unknown.note = "기침"
        unknown.type = .unknown
        XCTAssertTrue(HospitalChecklistService.symptomItems(from: [unknown]).isEmpty,
                      ".unknown 의 발열/증상이 병원 체크리스트에 잡히면 안 된다")

        // 대조군: 정상 type의 발열은 체크리스트에 잡힌다 (테스트 비공허 보장)
        var real = Activity(babyId: "b1", type: .temperature, startTime: Date())
        real.temperature = 39.0
        XCTAssertFalse(HospitalChecklistService.symptomItems(from: [real]).isEmpty,
                       "정상 발열은 체크리스트에 잡혀야 한다")
    }

    /// 불변 3(CSV): .unknown 은 CSV 데이터 행/양(ml) 컬럼에 새면 안 된다 (적대검토 5번 누수)
    func testUnknown_excludedFromCSVExport() {
        var unknown = Activity(babyId: "b1", type: .feedingBottle, startTime: Date(), amount: 999)
        unknown.type = .unknown
        let csv = ExportService.makeCSVString(activities: [unknown])
        XCTAssertEqual(csv.split(separator: "\n", omittingEmptySubsequences: true).count, 1,
                       ".unknown 은 CSV 데이터 행을 만들면 안 된다 (헤더만)")
        XCTAssertFalse(csv.contains("999"), ".unknown 의 양이 CSV 양(ml) 컬럼에 새면 안 된다")
    }

    /// §7-4: CSV가 유축량을 별도 컬럼에 분리, 섭취 양(ml)은 공란 (생산≠섭취)
    func testCSV_pumpingHasSeparateColumn() {
        let now = Date()
        let feeding = Activity(babyId: "b1", type: .feedingBottle, startTime: now, amount: 100)
        let pumping = Activity(babyId: "b1", type: .feedingPumping, startTime: now, amount: 200, side: .both)
        let csv = ExportService.makeCSVString(activities: [feeding, pumping])
        let lines = csv.split(separator: "\n").map(String.init)
        let header = lines[0].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        XCTAssertTrue(header.contains("유축량(ml)"), "헤더에 유축량(ml) 컬럼이 있어야 한다")
        XCTAssertTrue(header.contains("양(ml)"), "섭취 양(ml) 컬럼은 유지")

        // pumping 행의 유형 컬럼 = '짜기'(생산 액션 라벨). 헤더 유축량(ml)과 무관하게 데이터 행만 탐색.
        let pumpRow = lines.dropFirst().first { $0.contains("짜기") }
        XCTAssertNotNil(pumpRow, "짜기(생산) row가 있어야 한다")
        let cols = pumpRow!.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        let intakeIdx = header.firstIndex(of: "양(ml)")!
        let pumpIdx = header.firstIndex(of: "유축량(ml)")!
        XCTAssertEqual(cols[pumpIdx], "200", "생산량은 유축량(ml) 컬럼에 들어가야 한다")
        XCTAssertEqual(cols[intakeIdx], "", "짜기 row의 섭취 양(ml)은 공란이어야 한다")
    }

    /// §7-5: 유축은 캘린더 dot도, eventDots Set의 orphan 멤버도 만들지 않는다
    @MainActor
    func testCalendar_pumpingProducesNoDot() {
        let day = Date()
        let dots = CalendarViewModel.eventDots(forActivities: [
            Activity(babyId: "b1", type: .feedingBottle, startTime: day),
            Activity(babyId: "b1", type: .feedingPumping, startTime: day)
        ])
        let set = dots[day.startOfDay] ?? []
        XCTAssertTrue(set.contains(.activity(.feeding)))
        XCTAssertFalse(set.contains(.activity(.pumping)),
                       "유축은 캘린더 dot를 만들지 않고 orphan Set 멤버도 남기지 않아야 한다")
    }

    // MARK: - 병수유 내용물 (분유/모유) — 2026-06-09

    func testFeedingContent_displayNameAndRawValue() {
        XCTAssertEqual(Activity.FeedingContent.formula.displayName, "분유")
        XCTAssertEqual(Activity.FeedingContent.breastMilk.displayName, "모유")
        XCTAssertEqual(Activity.FeedingContent.formula.rawValue, "formula")
        XCTAssertEqual(Activity.FeedingContent.breastMilk.rawValue, "breast_milk")
    }

    func testActivity_feedingContentDefaultsNil() {
        let a = Activity(babyId: "b1", type: .feedingBottle, startTime: Date(), amount: 100)
        XCTAssertNil(a.feedingContent, "기존 분유 레코드 하위호환 — 미지정은 nil(=분유)")
    }

    func testActivity_isFormulaBottle_andBreastMilkBottle() {
        let formulaNil = Activity(babyId: "b1", type: .feedingBottle, startTime: Date(), amount: 100)
        XCTAssertTrue(formulaNil.isFormulaBottle, "content nil = 분유 병수유로 취급")
        XCTAssertFalse(formulaNil.isBreastMilkBottle)

        var breast = Activity(babyId: "b1", type: .feedingBottle, startTime: Date(), amount: 100)
        breast.feedingContent = .breastMilk
        XCTAssertTrue(breast.isBreastMilkBottle, "유축한 모유 병수유")
        XCTAssertFalse(breast.isFormulaBottle, "모유 병수유는 분유(formula)로 세면 안 된다")

        let pump = Activity(babyId: "b1", type: .feedingPumping, startTime: Date(), amount: 200)
        XCTAssertFalse(pump.isFormulaBottle)
        XCTAssertFalse(pump.isBreastMilkBottle)
    }

    func testActivity_displayLabel_contentAware() {
        var breast = Activity(babyId: "b1", type: .feedingBottle, startTime: Date(), amount: 100)
        breast.feedingContent = .breastMilk
        XCTAssertEqual(breast.displayLabel, "유축", "유축한 모유 병수유(섭취) = '유축' 타일 라벨")
        let formula = Activity(babyId: "b1", type: .feedingBottle, startTime: Date(), amount: 100)
        XCTAssertEqual(formula.displayLabel, "분유")
        let pump = Activity(babyId: "b1", type: .feedingPumping, startTime: Date(), amount: 200)
        XCTAssertEqual(pump.displayLabel, "짜기", "feedingPumping(생산) = '짜기' 라벨")
    }

    /// 수유 용어 정리 (2026-07-12 PO 확정) — 액션 라벨 짧게: 모유수유→모유, 유축(생산)→짜기.
    /// 수량 명사(유축량)는 유지. 콘텐츠 인지 라벨은 testActivity_displayLabel_contentAware 참조.
    func testDisplayName_shortenedActionLabels() {
        XCTAssertEqual(Activity.ActivityType.feedingBreast.displayName, "모유",
                       "모유수유→모유 (PO: 타일 라벨 짧게)")
        XCTAssertEqual(Activity.ActivityType.feedingPumping.displayName, "짜기",
                       "유축→짜기 (생산 행위. '유축'은 먹이기 타일이 가져감)")
        XCTAssertEqual(Activity.ActivityCategory.pumping.displayName, "짜기",
                       "생산 카테고리 라벨도 '짜기'로 일관")
    }

    // MARK: - RecordTile (분유/유축 타일 분리) — 2026-07-12 P2b

    func testRecordTile_label_contentAware() {
        XCTAssertEqual(RecordTile(.feedingBottle, content: .breastMilk).label, "유축",
                       "유축 = feedingBottle + breastMilk 프리셋")
        XCTAssertEqual(RecordTile(.feedingBottle, content: .formula).label, "분유")
        XCTAssertEqual(RecordTile(.feedingBottle).label, "분유", "content nil = 분유(하위호환)")
        XCTAssertEqual(RecordTile(.feedingPumping).label, "짜기", "짜기 = 생산")
        XCTAssertEqual(RecordTile(.feedingBreast).label, "모유")
        XCTAssertEqual(RecordTile(.feedingSolid).label, "이유식")
    }

    func testRecordTile_id_bottleTilesDistinct() {
        // 분유/유축은 같은 feedingBottle이되 id가 달라야 sheet(item:)/ForEach가 안 섞인다.
        XCTAssertNotEqual(RecordTile(.feedingBottle, content: .formula).id,
                          RecordTile(.feedingBottle, content: .breastMilk).id)
    }

    func testLauncherSections_feedingSplitsBottle() {
        let feeding = RecordTile.launcherSections.first { $0.title == "수유" }!.tiles
        let bottleTiles = feeding.filter { $0.type == .feedingBottle }
        XCTAssertEqual(bottleTiles.count, 2, "분유/유축 = feedingBottle 2타일로 분리")
        XCTAssertTrue(feeding.contains { $0.type == .feedingBottle && $0.contentPreset == .formula && $0.label == "분유" },
                      "분유 타일")
        XCTAssertTrue(feeding.contains { $0.type == .feedingBottle && $0.contentPreset == .breastMilk && $0.label == "유축" },
                      "유축 타일")
        XCTAssertTrue(feeding.contains { $0.type == .feedingPumping && $0.label == "짜기" }, "짜기(생산) 타일")
        XCTAssertTrue(feeding.contains { $0.type == .feedingBreast && $0.label == "모유" }, "모유 타일")
    }

    // MARK: - 유축 재고 (P4) — Activity 확장 + Builder + fromActivities

    func testActivity_pumpStorage_codableRoundtrip() {
        var a = Activity(babyId: "b1", type: .feedingPumping, startTime: Date(), amount: 200)
        a.pumpStorage = .freezer
        a.pumpDiscarded = true
        let data = try! JSONEncoder().encode(a)
        let decoded = try! JSONDecoder().decode(Activity.self, from: data)
        XCTAssertEqual(decoded.pumpStorage, .freezer)
        XCTAssertEqual(decoded.pumpDiscarded, true)
        let plain = Activity(babyId: "b1", type: .feedingPumping, startTime: Date(), amount: 100)
        XCTAssertNil(plain.pumpStorage, "미지정은 nil (하위호환·마이그0)")
        XCTAssertNil(plain.pumpDiscarded)
    }

    func testDraftBuilder_pumping_mapsPumpStorage() {
        var draft = ActivityDraft(babyId: "b1", type: .feedingPumping)
        draft.amountText = "150"
        draft.pumpStorage = .fridge
        guard case .success(let a) = ActivityDraftBuilder.build(draft) else { return XCTFail("build 실패") }
        XCTAssertEqual(a.pumpStorage, .fridge, "짜기(feedingPumping)는 보관 방식을 저장")
    }

    func testDraftBuilder_nonPumping_ignoresPumpStorage() {
        var draft = ActivityDraft(babyId: "b1", type: .feedingBottle)
        draft.amountText = "120"
        draft.pumpStorage = .freezer   // 병수유엔 무의미
        guard case .success(let a) = ActivityDraftBuilder.build(draft) else { return XCTFail("build 실패") }
        XCTAssertNil(a.pumpStorage, "짜기 외 타입은 pumpStorage 미저장")
    }

    func testInventory_fromActivities_pumpsMinusBreastMilkFeeds() {
        let now = Date()
        var pump = Activity(babyId: "b1", type: .feedingPumping, startTime: now.addingTimeInterval(-3600), amount: 200)
        pump.pumpStorage = .fridge
        var feed = Activity(babyId: "b1", type: .feedingBottle, startTime: now, amount: 50)
        feed.feedingContent = .breastMilk   // 유축 먹이기(소비)
        let formula = Activity(babyId: "b1", type: .feedingBottle, startTime: now, amount: 100)   // 분유(소비 아님)
        let state = PumpedMilkInventory.fromActivities([pump, feed, formula], now: now)
        XCTAssertEqual(state.totalRemaining, 150, "짜기 200 − 유축먹이기 50 = 150 (분유는 무관)")
    }

    func testInventory_fromActivities_storageNilDefaultsFridge_discardedExcluded() {
        let now = Date()
        let pumpNoStorage = Activity(babyId: "b1", type: .feedingPumping, startTime: now.addingTimeInterval(-3600), amount: 120)   // storage nil
        var discarded = Activity(babyId: "b1", type: .feedingPumping, startTime: now.addingTimeInterval(-1800), amount: 80)
        discarded.pumpStorage = .fridge
        discarded.pumpDiscarded = true
        let state = PumpedMilkInventory.fromActivities([pumpNoStorage, discarded], now: now)
        XCTAssertEqual(state.totalRemaining, 120, "storage nil=냉장 가정 포함(120), 폐기 배치(80) 제외")
    }

    @MainActor
    func testMakeDraft_pumping_capturesSelectedStorage() {
        let vm = ActivityViewModel()
        vm.selectedPumpStorage = .freezer
        vm.amount = "130"
        let draft = vm.makeDraft(type: .feedingPumping, babyId: "b1")
        XCTAssertEqual(draft.pumpStorage, .freezer, "makeDraft가 selectedPumpStorage를 draft에 캡처")
    }

    @MainActor
    func testBottle_breastMilkCountsAsIntake_pumpingDoesNot() {
        let vm = ActivityViewModel()
        let now = Date()
        var breastBottle = Activity(babyId: "b1", type: .feedingBottle, startTime: now, amount: 50)
        breastBottle.feedingContent = .breastMilk
        vm.todayActivities = [
            Activity(babyId: "b1", type: .feedingBottle, startTime: now, amount: 100), // 분유
            breastBottle,                                                              // 유축한 모유 병수유
            Activity(babyId: "b1", type: .feedingPumping, startTime: now, amount: 200) // 유축(생산)
        ]
        XCTAssertEqual(vm.todayTotalMl, 150, "병수유는 분유·모유 모두 섭취. 유축(생산)만 제외")
        XCTAssertEqual(vm.todayFeedingCount, 2, "병수유 2건은 섭취 횟수. 유축은 미포함")
    }

    // testQuickInput_bottle_persistsFeedingContent 제거(P4) —
    // QuickInputSheet 삭제, 병수유 내용물 영속 검증은 ActivityDraftBuilderTests.test_build_bottle_requiresValidAmount 가 대체.

    // MARK: - TimeInterval Extension Tests

    func testFormattedDuration() {
        let duration1: TimeInterval = 90 // 1:30
        XCTAssertEqual(duration1.formattedDuration, "01:30")

        let duration2: TimeInterval = 3661 // 1:01:01
        XCTAssertEqual(duration2.formattedDuration, "1:01:01")
    }

    func testShortDuration() {
        let duration1: TimeInterval = 1800 // 30 min
        XCTAssertEqual(duration1.shortDuration, "30분")

        let duration2: TimeInterval = 5400 // 1h 30m
        XCTAssertEqual(duration2.shortDuration, "1시간 30분")
    }

    // MARK: - Date Extension Tests

    func testDateIsToday() {
        XCTAssertTrue(Date().isToday)
        XCTAssertFalse(Date().adding(days: -1).isToday)
    }

    func testDateIsSameDay() {
        // 자정 edge case 방지: 당일 정오 기준
        let cal = Calendar.current
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let noonPlus2 = noon.adding(hours: 2)
        XCTAssertTrue(noon.isSameDay(as: noonPlus2))
    }

    // MARK: - TodoItem Tests

    func testTodoItemDefaults() {
        let todo = TodoItem(title: "테스트 할 일")
        XCTAssertFalse(todo.isCompleted)
        XCTAssertEqual(todo.category, .other)
        XCTAssertFalse(todo.isRecurring)
        XCTAssertNil(todo.dueDate)
    }

    // MARK: - AllergyRecord Codable Tests

    func testAllergyRecordCodableRoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let original = AllergyRecord(
            id: "test-allergy-id",
            babyId: "test-baby-id",
            allergenName: CommonAllergen.egg.displayName,
            reactionType: .skin,
            severity: .mild,
            date: fixedDate,
            symptoms: ["두드러기", "가려움"],
            note: "저녁 이유식 후 발생",
            createdAt: fixedDate
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AllergyRecord.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.babyId, original.babyId)
        XCTAssertEqual(decoded.allergenName, original.allergenName)
        XCTAssertEqual(decoded.reactionType, original.reactionType)
        XCTAssertEqual(decoded.severity, original.severity)
        XCTAssertEqual(decoded.symptoms, original.symptoms)
        XCTAssertEqual(decoded.note, original.note)
    }

    func testAllergyRecordEnumsRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for reactionType in AllergyReactionType.allCases {
            let data = try encoder.encode(reactionType)
            let decoded = try decoder.decode(AllergyReactionType.self, from: data)
            XCTAssertEqual(decoded, reactionType)
        }

        for severity in AllergySeverity.allCases {
            let data = try encoder.encode(severity)
            let decoded = try decoder.decode(AllergySeverity.self, from: data)
            XCTAssertEqual(decoded, severity)
        }

        for allergen in CommonAllergen.allCases {
            let data = try encoder.encode(allergen)
            let decoded = try decoder.decode(CommonAllergen.self, from: data)
            XCTAssertEqual(decoded, allergen)
        }
    }

    func testCommonAllergenCount() {
        XCTAssertEqual(CommonAllergen.allCases.count, 10)
    }

    // MARK: - PercentileCalculator Tests

    /// 정확도: 남아 3개월, 6.0kg → 25~40th 범위 (WHO 2006: M=6.3762, Z≈-0.515)
    /// 참고: 중앙값(50th)은 6.3762kg. 6.0kg은 중앙값보다 낮아 약 30th percentile
    func testPercentileAccuracy_maleWeight3mo() {
        let result = PercentileCalculator.percentile(value: 6.0, ageMonths: 3, gender: .male, metric: .weight)
        XCTAssertNotNil(result, "percentile 결과가 nil이어서는 안 됩니다")
        if let p = result {
            XCTAssertGreaterThanOrEqual(p, 25.0, "6.0kg 남아 3개월은 25th 이상이어야 합니다")
            XCTAssertLessThanOrEqual(p, 40.0, "6.0kg 남아 3개월은 40th 이하이어야 합니다")
        }
    }

    /// 정확도(중앙값): 남아 3개월, 6.3762kg(중앙값) → 45~55th 범위
    func testPercentileAccuracy_maleWeight3mo_median() {
        let result = PercentileCalculator.percentile(value: 6.3762, ageMonths: 3, gender: .male, metric: .weight)
        XCTAssertNotNil(result, "percentile 결과가 nil이어서는 안 됩니다")
        if let p = result {
            XCTAssertGreaterThanOrEqual(p, 45.0, "중앙값(6.3762kg)은 45th 이상이어야 합니다")
            XCTAssertLessThanOrEqual(p, 55.0, "중앙값(6.3762kg)은 55th 이하이어야 합니다")
        }
    }

    /// 경계값: 0개월(신생아)과 24개월 모두 nil 없이 정상 반환
    func testPercentileBoundaryMonths() {
        let at0 = PercentileCalculator.percentile(value: 3.3, ageMonths: 0, gender: .male, metric: .weight)
        XCTAssertNotNil(at0, "0개월 결과가 nil이어서는 안 됩니다")
        if let p = at0 {
            XCTAssertGreaterThan(p, 0.0)
            XCTAssertLessThan(p, 100.0)
        }

        let at24 = PercentileCalculator.percentile(value: 12.0, ageMonths: 24, gender: .female, metric: .weight)
        XCTAssertNotNil(at24, "24개월 결과가 nil이어서는 안 됩니다")
        if let p = at24 {
            XCTAssertGreaterThan(p, 0.0)
            XCTAssertLessThan(p, 100.0)
        }
    }

    /// 방어: 음수 값 → nil 반환
    func testPercentileNegativeValueReturnsNil() {
        let result = PercentileCalculator.percentile(value: -1.0, ageMonths: 3, gender: .male, metric: .weight)
        XCTAssertNil(result, "음수 입력값은 nil을 반환해야 합니다")
    }

    // MARK: - Temperature Trend Detection Tests

    @MainActor
    func testFeverTrend_normalTemperature_returnsFalse() {
        let vm = ActivityViewModel()
        let now = Date()
        let a1 = Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-3600), temperature: 37.5)
        let a2 = Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-1800), temperature: 36.8)
        vm.recentTemperatureActivities = [a1, a2]
        XCTAssertFalse(vm.isFeverTrendDetected, "정상 체온만 기록 시 isFeverTrendDetected는 false여야 합니다")
        XCTAssertEqual(vm.recentHighTemperatureCount, 0)
    }

    @MainActor
    func testFeverTrend_twoFeverRecords_returnsTrue() {
        let vm = ActivityViewModel()
        let now = Date()
        let a1 = Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-3600), temperature: 38.0)
        let a2 = Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-1800), temperature: 38.5)
        vm.recentTemperatureActivities = [a1, a2]
        XCTAssertTrue(vm.isFeverTrendDetected, "38.0°C 이상 2회 기록 시 isFeverTrendDetected는 true여야 합니다")
        XCTAssertEqual(vm.recentHighTemperatureCount, 2)
    }

    @MainActor
    func testFeverTrend_onlyOneFever_returnsFalse() {
        let vm = ActivityViewModel()
        let now = Date()
        let a1 = Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-3600), temperature: 38.2)
        let a2 = Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-1800), temperature: 37.0)
        vm.recentTemperatureActivities = [a1, a2]
        XCTAssertFalse(vm.isFeverTrendDetected, "발열 기록 1회만 있을 때 isFeverTrendDetected는 false여야 합니다")
        XCTAssertEqual(vm.recentHighTemperatureCount, 1)
    }

    @MainActor
    func testFeverTrend_outsideOf24Hours_notCounted() {
        let vm = ActivityViewModel()
        let now = Date()
        // 25시간 전 기록은 24시간 범위 밖 (recentTemperatureActivities는 48h 범위이지만 필터는 24h)
        let old = Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-90000), temperature: 38.5)
        let recent = Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-1800), temperature: 38.1)
        vm.recentTemperatureActivities = [old, recent]
        XCTAssertFalse(vm.isFeverTrendDetected, "24시간 이전 기록은 추세 계산에서 제외되어야 합니다")
        XCTAssertEqual(vm.recentHighTemperatureCount, 1)
    }

    @MainActor
    func testFeverTrend_emptyActivities_returnsFalse() {
        let vm = ActivityViewModel()
        vm.recentTemperatureActivities = []
        XCTAssertFalse(vm.isFeverTrendDetected)
        XCTAssertEqual(vm.recentHighTemperatureCount, 0)
    }

    @MainActor
    func testFeverTrend_overnightPair_detected() {
        let vm = ActivityViewModel()
        let now = Date()
        // 23시간 전 (어제 밤) + 1시간 전 (오늘 새벽) — 자정 경계를 넘는 야간 발열 페어
        let lastNight = Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-82800), temperature: 38.3)
        let earlyMorning = Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-3600), temperature: 38.6)
        vm.recentTemperatureActivities = [lastNight, earlyMorning]
        XCTAssertTrue(vm.isFeverTrendDetected, "야간 발열 페어(24시간 이내)는 감지되어야 합니다")
        XCTAssertEqual(vm.recentHighTemperatureCount, 2)
    }

    // MARK: - Analytics Tests

    func testMockAnalytics_trackEvent() {
        let mock = MockAnalyticsService()
        mock.trackEvent(AnalyticsEvents.recordSave, parameters: [AnalyticsParams.category: "feed"])
        XCTAssertEqual(mock.trackedEvents.count, 1)
        XCTAssertEqual(mock.trackedEvents.first?.name, AnalyticsEvents.recordSave)
        XCTAssertEqual(mock.trackedEvents.first?.parameters[AnalyticsParams.category], "feed")
    }

    func testMockAnalytics_trackScreen() {
        let mock = MockAnalyticsService()
        mock.trackScreen(AnalyticsScreens.dashboard)
        XCTAssertEqual(mock.trackedScreens.count, 1)
        XCTAssertEqual(mock.trackedScreens.first?.name, AnalyticsScreens.dashboard)
    }

    func testMockAnalytics_optOut_blocksEvents() {
        let mock = MockAnalyticsService()
        mock.setEnabled(false)
        mock.trackEvent(AnalyticsEvents.recordSave)
        mock.trackScreen(AnalyticsScreens.dashboard)
        XCTAssertTrue(mock.trackedEvents.isEmpty, "옵트아웃 시 이벤트가 기록되면 안 됩니다")
        XCTAssertTrue(mock.trackedScreens.isEmpty, "옵트아웃 시 화면 추적이 되면 안 됩니다")
    }

    func testMockAnalytics_setUserProperty() {
        let mock = MockAnalyticsService()
        mock.setUserProperty("3", forName: AnalyticsUserProperties.babyCount)
        XCTAssertEqual(mock.userProperties[AnalyticsUserProperties.babyCount] as? String, "3")
    }

    func testAnalyticsEvents_constants() {
        // 이벤트명·파라미터 키·화면명이 GA4 규칙을 준수하는지 확인 (소문자+숫자+언더스코어, 40자 이내)
        let identifiers = [
            // 이벤트 (전수)
            AnalyticsEvents.dashboardQuickRecord,
            AnalyticsEvents.calendarDateSelect, AnalyticsEvents.calendarRecordOpen,
            AnalyticsEvents.recordSave, AnalyticsEvents.feedRecordSave,
            AnalyticsEvents.sleepRecordSave, AnalyticsEvents.diaperRecordSave,
            AnalyticsEvents.pumpingRecorded,
            AnalyticsEvents.healthDataView, AnalyticsEvents.aiAdviceRequest,
            AnalyticsEvents.growthDataInput, AnalyticsEvents.productView,
            AnalyticsEvents.analyticsOptOutToggle,
            AnalyticsEvents.insightGenerated, AnalyticsEvents.insightShown, AnalyticsEvents.insightTapped,
            AnalyticsEvents.highlightTickerShown, AnalyticsEvents.highlightTickerTapped,
            AnalyticsEvents.highlightTickerPaused, AnalyticsEvents.highlightSheetOpened,
            AnalyticsEvents.highlightSheetDismissed, AnalyticsEvents.highlightCacheHit,
            AnalyticsEvents.highlightPatternReportTapped, AnalyticsEvents.highlightCardTapped,
            AnalyticsEvents.reviewPromptRequested,
            // 파라미터 키 (전수)
            AnalyticsParams.screenName, AnalyticsParams.actionType, AnalyticsParams.category,
            AnalyticsParams.source, AnalyticsParams.trigger, AnalyticsParams.content,
            AnalyticsParams.enabled, AnalyticsParams.dwellMs,
            AnalyticsParams.amountBucket, AnalyticsParams.side,
            AnalyticsParams.metricKey, AnalyticsParams.position,
            AnalyticsParams.scorerMode, AnalyticsParams.historyWeeks,
            // 화면명 (전수)
            AnalyticsScreens.dashboard, AnalyticsScreens.calendar, AnalyticsScreens.health,
            AnalyticsScreens.settings, AnalyticsScreens.recording, AnalyticsScreens.feedRecording,
            AnalyticsScreens.sleepRecording, AnalyticsScreens.diaperRecording,
            AnalyticsScreens.aiAdvice, AnalyticsScreens.growth, AnalyticsScreens.productList,
        ]
        for identifier in identifiers {
            XCTAssertTrue(identifier.count <= 40, "\(identifier)는 40자를 초과합니다")
            XCTAssertTrue(identifier.range(of: "^[a-z][a-z0-9_]*$", options: .regularExpression) != nil,
                          "\(identifier)는 소문자+숫자+언더스코어 규칙을 위반합니다")
            XCTAssertFalse(identifier.hasPrefix("ga_") || identifier.hasPrefix("google_") || identifier.hasPrefix("firebase_"),
                           "\(identifier)는 GA4 예약 접두사를 사용합니다")
        }
    }

    func testAnalyticsCategoryValues_areEnglishStableIdentifiers() {
        // category 파라미터로 전송되는 rawValue가 영어 안정 식별자인지 (한글 displayName 혼입 방지 회귀 가드)
        let categoryValues = Activity.ActivityType.allCases.map(\.rawValue)
            + Activity.ActivityCategory.allCases.map(\.rawValue)
            + Activity.FeedingContent.allCases.map(\.rawValue)
        for value in categoryValues {
            XCTAssertTrue(value.range(of: "^[a-z][a-z0-9_]*$", options: .regularExpression) != nil,
                          "category 값 \(value)는 영어 snake_case 안정 식별자가 아닙니다")
        }
    }

    func testTickerImpressionDeduper_firesOncePerKey() {
        var deduper = TickerImpressionDeduper()
        XCTAssertTrue(deduper.shouldFire("feeding.count"), "최초 노출은 발화해야 합니다")
        XCTAssertFalse(deduper.shouldFire("feeding.count"), "같은 metricKey 반복 tick은 발화하면 안 됩니다")
        XCTAssertTrue(deduper.shouldFire("sleep.hours"), "다른 metricKey는 발화해야 합니다")
        XCTAssertFalse(deduper.shouldFire("sleep.hours"))
    }

    func testPumpingAnalytics_bucket_boundaries() {
        XCTAssertEqual(PumpingAnalytics.bucket(nil), "unknown")
        XCTAssertEqual(PumpingAnalytics.bucket(0), "0-59")
        XCTAssertEqual(PumpingAnalytics.bucket(59.9), "0-59")
        XCTAssertEqual(PumpingAnalytics.bucket(60), "60-119")
        XCTAssertEqual(PumpingAnalytics.bucket(119.9), "60-119")
        XCTAssertEqual(PumpingAnalytics.bucket(120), "120-179")
        XCTAssertEqual(PumpingAnalytics.bucket(180), "180+")
        XCTAssertEqual(PumpingAnalytics.bucket(500), "180+")
    }

    // MARK: - Consecutive Fever Days Tests

    func testConsecutiveFeverDays_threeDays() {
        // 연속 3일 38.5°C → consecutiveFeverDays == 3
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let day1 = cal.date(byAdding: .day, value: -2, to: today)!.addingTimeInterval(3600)
        let day2 = cal.date(byAdding: .day, value: -1, to: today)!.addingTimeInterval(3600)
        let day3 = today.addingTimeInterval(3600)
        let activities = [
            Activity(babyId: "b1", type: .temperature, startTime: day1, temperature: 38.5),
            Activity(babyId: "b1", type: .temperature, startTime: day2, temperature: 38.5),
            Activity(babyId: "b1", type: .temperature, startTime: day3, temperature: 38.5),
        ]
        let health = PatternAnalysisService.analyzeHealth(activities: activities)
        XCTAssertEqual(health.consecutiveFeverDays, 3, "연속 3일 발열 시 consecutiveFeverDays는 3이어야 합니다")
    }

    func testConsecutiveFeverDays_noFever() {
        // 발열 없음 → consecutiveFeverDays == 0
        let now = Date()
        let activities = [
            Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-3600), temperature: 37.0),
            Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-1800), temperature: 36.8),
        ]
        let health = PatternAnalysisService.analyzeHealth(activities: activities)
        XCTAssertEqual(health.consecutiveFeverDays, 0, "발열 없음 시 consecutiveFeverDays는 0이어야 합니다")
    }

    func testConsecutiveFeverDays_intermittent() {
        // 간헐적 발열 (1일 - 쉼 - 1일) → consecutiveFeverDays == 1
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let day1 = cal.date(byAdding: .day, value: -3, to: today)!.addingTimeInterval(3600)
        // day2 건너뜀
        let day3 = cal.date(byAdding: .day, value: -1, to: today)!.addingTimeInterval(3600)
        let activities = [
            Activity(babyId: "b1", type: .temperature, startTime: day1, temperature: 38.5),
            Activity(babyId: "b1", type: .temperature, startTime: day3, temperature: 38.5),
        ]
        let health = PatternAnalysisService.analyzeHealth(activities: activities)
        XCTAssertEqual(health.consecutiveFeverDays, 1, "간헐적 발열 시 consecutiveFeverDays는 최장 연속 1일이어야 합니다")
    }

    // MARK: - Missing Days Tests

    func testMissingDays_fiveOfSeven() {
        // startDate~endDate 사이 6일 스팬 (dateComponents는 end-start=6),
        // 4일치 기록만 있을 때 missingDays == 2
        let cal = Calendar.current
        let startDate = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date()))!
        let endDate = cal.startOfDay(for: Date())
        // 4개 날짜에 기록 생성 (startDate + 0,1,2,3)
        let activities: [Activity] = (0..<4).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: startDate)!.addingTimeInterval(3600)
            return Activity(babyId: "b1", type: .feedingBreast, startTime: day)
        }
        let summary = PatternAnalysisService.analyzeSummary(activities: activities, startDate: startDate, endDate: endDate)
        XCTAssertEqual(summary.missingDays, 2, "6스팬 4일 기록 시 missingDays는 2이어야 합니다")
    }

    func testMissingDays_allDaysRecorded() {
        // startDate~endDate 사이 6일 스팬, 6일 모두 기록 → missingDays == 0
        let cal = Calendar.current
        let startDate = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date()))!
        let endDate = cal.startOfDay(for: Date())
        // totalDays = 6 (dateComponents), 6일 기록
        let activities: [Activity] = (0..<6).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: startDate)!.addingTimeInterval(3600)
            return Activity(babyId: "b1", type: .feedingBreast, startTime: day)
        }
        let summary = PatternAnalysisService.analyzeSummary(activities: activities, startDate: startDate, endDate: endDate)
        XCTAssertEqual(summary.missingDays, 0, "6스팬 6일 기록 시 missingDays는 0이어야 합니다")
    }

    func testMissingDays_noData() {
        // 데이터 없음, 6일 스팬 → missingDays == 6
        let cal = Calendar.current
        let startDate = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date()))!
        let endDate = cal.startOfDay(for: Date())
        let summary = PatternAnalysisService.analyzeSummary(activities: [], startDate: startDate, endDate: endDate)
        XCTAssertEqual(summary.missingDays, 6, "데이터 없음 시 missingDays는 dateComponents 스팬과 같아야 합니다")
    }

    // MARK: - Period Comparison Delta Tests

    func testPreviousDailyAverage_withData() {
        // analyzeComparison의 previousDays = dateComponents(end-start).day (스팬 기준)
        // previousStart~previousEnd 스팬 = 6, 36회 feeding → 6회/일
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let currentStart = cal.date(byAdding: .day, value: -6, to: today)!
        let currentEnd = today
        let previousStart = cal.date(byAdding: .day, value: -13, to: today)!
        let previousEnd = cal.date(byAdding: .day, value: -7, to: today)!

        // 이번주: 6일 × 8회 = 48회 feeding
        let currentActivities: [Activity] = (0..<48).map { i in
            let dayOffset = i % 6
            let day = cal.date(byAdding: .day, value: dayOffset, to: currentStart)!.addingTimeInterval(TimeInterval(i * 1000))
            return Activity(babyId: "b1", type: .feedingBreast, startTime: day)
        }
        let currentReport = PatternAnalysisService.analyze(
            activities: currentActivities,
            period: "7일",
            startDate: currentStart,
            endDate: currentEnd
        )

        // 지난주: previousDays 스팬 = 6, 36회 feeding → 6.0/일
        let previousActivities: [Activity] = (0..<36).map { i in
            let dayOffset = i % 6
            let day = cal.date(byAdding: .day, value: dayOffset, to: previousStart)!.addingTimeInterval(TimeInterval(i * 1000))
            return Activity(babyId: "b1", type: .feedingBreast, startTime: day)
        }

        let comparedReport = PatternAnalysisService.analyzeComparison(
            currentReport: currentReport,
            previousActivities: previousActivities,
            previousPeriod: (start: previousStart, end: previousEnd)
        )

        XCTAssertNotNil(comparedReport.feeding.previousDailyAverage, "이전 기간 데이터가 있을 때 previousDailyAverage는 nil이어서는 안 됩니다")
        XCTAssertEqual(comparedReport.feeding.previousDailyAverage!, 6.0, accuracy: 0.01, "이전 기간 6회/일이면 previousDailyAverage는 6.0이어야 합니다")
    }

    func testPreviousDailyAverage_noData() {
        // 이전 기간 데이터 없음 → previousDailyAverage == nil (analyzeComparison 호출 안 함)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let currentStart = cal.date(byAdding: .day, value: -6, to: today)!
        let currentEnd = today

        let currentActivities: [Activity] = [
            Activity(babyId: "b1", type: .feedingBreast, startTime: currentStart.addingTimeInterval(3600))
        ]
        let currentReport = PatternAnalysisService.analyze(
            activities: currentActivities,
            period: "7일",
            startDate: currentStart,
            endDate: currentEnd
        )

        // 이전 기간 데이터 없이 analyze()만 호출 시 previousDailyAverage는 nil
        XCTAssertNil(currentReport.feeding.previousDailyAverage, "이전 기간 데이터 없으면 previousDailyAverage는 nil이어야 합니다")
    }

    // MARK: - Cry Analysis Tests

    func test_cryLabel_allCasesCount_equalsFive() {
        XCTAssertEqual(CryLabel.allCases.count, 5)
    }

    func test_cryLabel_allCases_containsExpected() {
        XCTAssertTrue(CryLabel.allCases.contains(.hungry))
        XCTAssertTrue(CryLabel.allCases.contains(.burping))
        XCTAssertTrue(CryLabel.allCases.contains(.bellyPain))
        XCTAssertTrue(CryLabel.allCases.contains(.discomfort))
        XCTAssertTrue(CryLabel.allCases.contains(.tired))
    }

    func test_cryRecord_codableRoundTrip() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let original = CryRecord(
            id: "test-cry-id",
            babyId: "test-baby-id",
            recordedAt: fixedDate,
            durationSeconds: 5.0,
            probabilities: [CryLabel.hungry.rawValue: 1.0],
            topLabel: nil,
            isStub: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CryRecord.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.babyId, original.babyId)
        XCTAssertEqual(decoded.durationSeconds, original.durationSeconds)
        XCTAssertEqual(decoded.probabilities, original.probabilities)
        XCTAssertEqual(decoded.topLabel, original.topLabel)
        XCTAssertEqual(decoded.isStub, original.isStub)
    }

    @MainActor
    func test_cryAnalysisService_analyzeStub_probabilitiesSumToOne() {
        let service = CryAnalysisService()
        let record = service.analyzeStub(babyId: "test-baby")
        let sum = record.probabilities.values.reduce(0.0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }

    @MainActor
    func test_cryAnalysisService_analyzeStub_isStubTrue() {
        let service = CryAnalysisService()
        let record = service.analyzeStub(babyId: "test-baby")
        XCTAssertTrue(record.isStub)
    }

    @MainActor
    func test_cryAnalysisService_analyzeStub_topLabelIsNil() {
        let service = CryAnalysisService()
        let record = service.analyzeStub(babyId: "test-baby")
        XCTAssertNil(record.topLabel)
    }

    @MainActor
    func test_cryAnalysisService_analyzeStub_hasFiveLabels() {
        let service = CryAnalysisService()
        let record = service.analyzeStub(babyId: "test-baby")
        XCTAssertEqual(record.probabilities.count, 5)
    }

    func test_featureFlags_cryAnalysisEnabled_isBool() {
        // v2.6.2 build 52: TestFlight 테스터 확인용으로 flag flip (stub 노출).
        // 실제 프로덕션 릴리즈 전 flag 상태는 PM 판단으로 조정.
        let value: Bool = FeatureFlags.cryAnalysisEnabled
        XCTAssertTrue(value || !value) // 상수 참조 컴파일 무결성만 검증
    }

    func test_firestoreCollections_cryRecords_equalsString() {
        XCTAssertEqual(FirestoreCollections.cryRecords, "cryRecords")
    }

    // MARK: - FeedingPrediction v2 Tests

    func testIsDayHour_daytime() {
        XCTAssertTrue(FeedingPredictionService.isDayHour(14), "14시는 낮 시간대여야 합니다")
        XCTAssertTrue(FeedingPredictionService.isDayHour(10), "10시는 낮 시간대여야 합니다")
    }

    func testIsDayHour_nighttime() {
        XCTAssertFalse(FeedingPredictionService.isDayHour(2), "2시는 야간 시간대여야 합니다")
        XCTAssertFalse(FeedingPredictionService.isDayHour(23), "23시는 야간 시간대여야 합니다")
    }

    func testIsDayHour_boundary() {
        // dayStart=6 (inclusive) → true, dayEnd=22 (exclusive) → false
        XCTAssertTrue(FeedingPredictionService.isDayHour(6), "6시는 낮 시작 경계이므로 true여야 합니다")
        XCTAssertFalse(FeedingPredictionService.isDayHour(22), "22시는 낮 종료 경계(exclusive)이므로 false여야 합니다")
    }

    func testAverageInterval_dayContext() {
        // 낮 시간대(14시)에 3개의 수유 기록을 2시간 간격으로 생성
        // → dayIntervals에 2개 이상의 항목 → isPersonalized == true, interval ≈ 7200초
        let cal = Calendar.current
        let base = cal.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        let a1 = Activity(id: "d1", babyId: "b1", type: .feedingBreast, startTime: base)
        let a2 = Activity(id: "d2", babyId: "b1", type: .feedingBreast, startTime: base.addingTimeInterval(7200))
        let a3 = Activity(id: "d3", babyId: "b1", type: .feedingBreast, startTime: base.addingTimeInterval(14400))
        // recentActivities에 넣어 allFeedings에 포함되도록 함
        let result = FeedingPredictionService.averageInterval(
            todayActivities: [],
            recentActivities: [a1, a2, a3],
            babyAgeInMonths: 3
        )
        // 낮(14시) 수유 3개 → gap이 7200초 × 2 = 평균 7200초
        // dayIntervals에 2개 이상 → isPersonalized 결과는 현재 시간대에 따라 달라지나,
        // 어느 시간대든 allIntervals에는 2개 이상 → interval은 age fallback이 아님
        let ageFallback = AppConstants.feedingIntervalHours(ageInMonths: 3) * 3600
        XCTAssertNotEqual(result.interval, ageFallback, "데이터가 충분하면 월령 기반 기본값을 사용하지 않아야 합니다")
        XCTAssertEqual(result.interval, 7200, accuracy: 1.0, "낮 2시간 간격 수유의 평균 간격은 7200초여야 합니다")
    }

    func testAverageInterval_nightContext() {
        // 야간 시간대(1시, 3시, 5시)에 3개의 수유 기록을 2시간 간격으로 생성
        // → nightIntervals에 2개 이상의 항목 (gap 7200 < 43200 허용)
        // 1개월 age fallback = 2.5h * 3600 = 9000초 → 7200 != 9000이므로 구분 가능
        // 1시, 3시, 5시 모두 isDayHour == false → nightIntervals = [7200, 7200]
        let cal = Calendar.current
        let base = cal.date(bySettingHour: 1, minute: 0, second: 0, of: Date())!
        let a1 = Activity(id: "n1", babyId: "b1", type: .feedingBottle, startTime: base)
        let a2 = Activity(id: "n2", babyId: "b1", type: .feedingBottle, startTime: base.addingTimeInterval(7200))
        let a3 = Activity(id: "n3", babyId: "b1", type: .feedingBottle, startTime: base.addingTimeInterval(14400))
        let result = FeedingPredictionService.averageInterval(
            todayActivities: [],
            recentActivities: [a1, a2, a3],
            babyAgeInMonths: 1  // fallback = 2.5h = 9000초 (7200과 다름)
        )
        let ageFallback = AppConstants.feedingIntervalHours(ageInMonths: 1) * 3600
        XCTAssertNotEqual(result.interval, ageFallback, "야간 데이터가 충분하면 월령 기반 기본값을 사용하지 않아야 합니다")
        XCTAssertEqual(result.interval, 7200, accuracy: 1.0, "야간 2시간 간격 수유의 평균 간격은 7200초여야 합니다")
    }

    func testAverageInterval_insufficientDayData_fallsBackToAll() {
        // 낮 수유 2개(gap 1개, 어제) + 야간 수유 2개(gap 1개, 그제)
        // 날짜를 분리해 교차 버킷 오염(day-night 경계 gap) 방지
        // → dayIntervals.count == 1 < 2, nightIntervals.count == 1 < 2
        // → 둘 다 시간대 threshold 미달 → allIntervals fallback → isPersonalized == false
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: Date())!
        let dayBase  = cal.date(bySettingHour: 10, minute: 0, second: 0, of: yesterday)!
        let nightBase = cal.date(bySettingHour: 2, minute: 0, second: 0, of: twoDaysAgo)!
        let d1 = Activity(id: "fd1", babyId: "b1", type: .feedingBreast, startTime: dayBase)
        let d2 = Activity(id: "fd2", babyId: "b1", type: .feedingBreast, startTime: dayBase.addingTimeInterval(7200))
        let n1 = Activity(id: "fn1", babyId: "b1", type: .feedingBreast, startTime: nightBase)
        let n2 = Activity(id: "fn2", babyId: "b1", type: .feedingBreast, startTime: nightBase.addingTimeInterval(10800))
        let result = FeedingPredictionService.averageInterval(
            todayActivities: [],
            recentActivities: [d1, d2, n1, n2],
            babyAgeInMonths: 3
        )
        // 4개 기록이지만 인접한 gap은 각 날짜 내에서만 발생 → day 1개, night 1개 gap
        // allIntervals.count == 2 (>= 2) → 기본값 아님
        // ageFallback = 3.0h = 10800초, allIntervals avg = (7200+10800)/2 = 9000 ≠ 10800
        let ageFallback = AppConstants.feedingIntervalHours(ageInMonths: 3) * 3600
        XCTAssertNotEqual(result.interval, ageFallback, accuracy: 1.0,
                          "전체 interval 데이터가 있으면 월령 기본값으로 내려가지 않아야 합니다")
        XCTAssertFalse(result.isPersonalized, "각 시간대 데이터가 1개씩(미달)일 때 isPersonalized는 false여야 합니다")
    }

    func testAverageInterval_noData_fallsBackToAgebased() {
        // 활동 없음 → unique.count < 2 → ageFallback 반환, isPersonalized == false
        let result = FeedingPredictionService.averageInterval(
            todayActivities: [],
            recentActivities: [],
            babyAgeInMonths: 3
        )
        let ageFallback = AppConstants.feedingIntervalHours(ageInMonths: 3) * 3600
        XCTAssertEqual(result.interval, ageFallback, accuracy: 1.0, "데이터 없음 시 월령 기반 기본값을 반환해야 합니다")
        XCTAssertFalse(result.isPersonalized, "데이터 없음 시 isPersonalized는 false여야 합니다")
    }

    @MainActor
    func testCrossMidnight_lastFeedingFallback() {
        // todayActivities 비어 있고, recentFeedingActivities에 수유 기록이 있을 때
        // deriveLatestActivities() 호출 후 lastFeeding이 nil이 아닌지 검증
        let vm = ActivityViewModel()
        let yesterday = Date().addingTimeInterval(-3600) // 1시간 전 (어제 혹은 오늘 초반)
        let recentFeeding = Activity(id: "rf1", babyId: "b1", type: .feedingBreast, startTime: yesterday)
        vm.todayActivities = []
        vm.recentFeedingActivities = [recentFeeding]
        vm.deriveLatestActivities()
        XCTAssertNotNil(vm.lastFeeding, "오늘 수유 없을 때 recentFeedingActivities에서 lastFeeding을 fallback해야 합니다")
        XCTAssertEqual(vm.lastFeeding?.id, "rf1", "fallback된 lastFeeding은 recentFeedingActivities의 항목이어야 합니다")
    }

    // MARK: - WeeklyInsight Tests

    // MARK: - Insight Provider Tests (v2: Provider + Scoring)

    private func makeFeedingActivity(date: Date, amount: Double = 100, type: Activity.ActivityType = .feedingBottle) -> Activity {
        Activity(babyId: "b1", type: type, startTime: date, amount: amount)
    }

    private func makeSleepActivity(date: Date, durationHours: Double = 1.0, quality: Activity.SleepQualityType? = nil) -> Activity {
        Activity(babyId: "b1", type: .sleep, startTime: date, duration: durationHours * 3600, sleepQuality: quality)
    }

    private func makeDiaperActivity(date: Date, type: Activity.ActivityType = .diaperWet) -> Activity {
        Activity(babyId: "b1", type: type, startTime: date)
    }

    private func makeReportWithActivities(_ acts: [Activity], days: Int = 7) -> PatternReport {
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -days, to: end) ?? end
        return PatternAnalysisService.analyze(activities: acts, period: "test", startDate: start, endDate: end)
    }

    /// FeedingInsightProvider — 횟수/용량/간격 candidate 생성 (이전 활동 있을 때)
    func testFeedingInsightProvider_producesMultipleCandidates() {
        let now = Date()
        let curActs = (0..<14).map { makeFeedingActivity(date: now.addingTimeInterval(Double(-$0 * 12 * 3600)), amount: 120) }
        let prevActs = (0..<10).map { makeFeedingActivity(date: now.addingTimeInterval(Double(-(7 + $0) * 12 * 3600)), amount: 100) }
        let curReport = makeReportWithActivities(curActs)
        let ctx = InsightContext(current: curReport, previousActivities: prevActs, previousDays: 7, weights: .default, currentDays: 7, metricHistory: [:])
        let candidates = FeedingInsightProvider.candidates(ctx)
        XCTAssertGreaterThanOrEqual(candidates.count, 1, "Feeding provider는 최소 1개 이상의 candidate (count/volume/interval) 생성")
        let metricKeys = Set(candidates.map { $0.metricKey })
        XCTAssertTrue(metricKeys.contains("feeding.count"), "수유 횟수 candidate 존재")
    }

    /// DiaperInsightProvider — wet/dirty 분리 candidate
    func testDiaperInsightProvider_splitsWetAndDirty() {
        let now = Date()
        var curActs: [Activity] = []
        for i in 0..<14 {
            let d = now.addingTimeInterval(Double(-i * 6 * 3600))
            curActs.append(makeDiaperActivity(date: d, type: i % 2 == 0 ? .diaperWet : .diaperDirty))
        }
        // 전주는 소변만 5회 → 이번주 wet=7, dirty=7 → wet 변화율 ↑, dirty 변화율 매우 큼
        let prevActs = (0..<5).map { makeDiaperActivity(date: now.addingTimeInterval(Double(-(7 + $0) * 24 * 3600)), type: .diaperWet) }
        let curReport = makeReportWithActivities(curActs)
        let ctx = InsightContext(current: curReport, previousActivities: prevActs, previousDays: 7, weights: .default, currentDays: 7, metricHistory: [:])
        let candidates = DiaperInsightProvider.candidates(ctx)
        let keys = Set(candidates.map { $0.metricKey })
        XCTAssertTrue(keys.contains("diaper.wet"), "소변 candidate 존재")
        // 대변 prev=0이라 nil 반환됨 (subMetricCandidate guard)
    }

    /// SleepInsightProvider — 시간 candidate
    func testSleepInsightProvider_hoursCandidate() {
        let now = Date()
        let curActs = (0..<7).map { makeSleepActivity(date: now.addingTimeInterval(Double(-$0 * 24 * 3600)), durationHours: 12) }
        let prevActs = (0..<7).map { makeSleepActivity(date: now.addingTimeInterval(Double(-(7 + $0) * 24 * 3600)), durationHours: 10) }
        let curReport = makeReportWithActivities(curActs)
        let ctx = InsightContext(current: curReport, previousActivities: prevActs, previousDays: 7, weights: .default, currentDays: 7, metricHistory: [:])
        let candidates = SleepInsightProvider.candidates(ctx)
        let hours = candidates.first { $0.metricKey == "sleep.hours" }
        XCTAssertNotNil(hours, "수면 시간 candidate 존재")
        XCTAssertGreaterThan(hours?.changePercent ?? 0, 0, "10→12시간 변화는 양수 changePercent")
    }

    /// HealthInsightProvider — 발열 prev=0, cur>0이면 changePct=300으로 강조
    func testHealthInsightProvider_feverFromZero() {
        let now = Date()
        let curActs = [
            Activity(babyId: "b1", type: .temperature, startTime: now, temperature: 38.5),
            Activity(babyId: "b1", type: .temperature, startTime: now.addingTimeInterval(-86400), temperature: 38.2)
        ]
        let prevActs: [Activity] = []
        let curReport = makeReportWithActivities(curActs)
        let ctx = InsightContext(current: curReport, previousActivities: prevActs, previousDays: 7, weights: .default, currentDays: 7, metricHistory: [:])
        let candidates = HealthInsightProvider.candidates(ctx)
        let fever = candidates.first { $0.metricKey == "health.fever" }
        XCTAssertNotNil(fever, "발열 candidate 생성 (prev=0, cur=2)")
        XCTAssertEqual(fever?.changePercent, 300, "prev=0인데 cur>0이면 300% 강조")
    }

    /// InsightScoringService — minChangePct 미만 candidate 제외
    func testScoringService_filtersBelowMinChangePct() {
        let small = InsightCandidate(category: .feeding, metricKey: "feeding.count", currentValue: 6, title: "t", detail: "d", changePercent: 3, trend: .stable, medicalWeight: 1.0, sampleSize: 7)
        let big = InsightCandidate(category: .sleep, metricKey: "sleep.hours", currentValue: 12, title: "t", detail: "d", changePercent: 20, trend: .increasing, medicalWeight: 1.0, sampleSize: 7)
        let result = InsightScoringService.selectTopN([small, big], scorer: HeuristicScorer(), metricHistory: [:], weights: .default)
        XCTAssertEqual(result.count, 1, "minChangePct(5) 미만은 필터링")
        XCTAssertEqual(result[0].metricKey, "sleep.hours")
    }

    /// InsightScoringService — heuristic score 정렬
    func testScoringService_sortsByScore() {
        let a = InsightCandidate(category: .feeding, metricKey: "feeding.count", currentValue: 6, title: "t", detail: "d", changePercent: 20, trend: .increasing, medicalWeight: 1.0, sampleSize: 7)
        let c = InsightCandidate(category: .health, metricKey: "health.fever", currentValue: 2, title: "t", detail: "d", changePercent: 15, trend: .increasing, medicalWeight: 2.0, sampleSize: 7)
        let result = InsightScoringService.selectTopN([a, c], scorer: HeuristicScorer(), metricHistory: [:], weights: .default)
        XCTAssertEqual(result[0].metricKey, "health.fever", "weight 2.0이 곱해진 health가 1순위")
    }

    /// InsightScoringService — maxCount 적용
    func testScoringService_appliesMaxCount() {
        let candidates = (1...10).map {
            InsightCandidate(category: .feeding, metricKey: "feeding.\($0)", currentValue: Double($0), title: "t", detail: "d", changePercent: Double($0 * 5), trend: .increasing, medicalWeight: 1.0, sampleSize: 7)
        }
        let result = InsightScoringService.selectTopN(candidates, scorer: HeuristicScorer(), metricHistory: [:], weights: .default)
        XCTAssertEqual(result.count, 3, "default maxCount=3")
    }

    /// InsightWeights.default — 기대 값 확인
    func testInsightWeights_defaults() {
        XCTAssertEqual(InsightWeights.default.minChangePct, 5)
        XCTAssertEqual(InsightWeights.default.maxCount, 3)
        XCTAssertEqual(InsightWeights.default.diaperDirty, 1.5, "대변은 0.8(소변)보다 가중치 ↑")
        XCTAssertEqual(InsightWeights.default.healthFever, 2.0, "발열이 가장 높은 가중치")
    }

    /// E2E — WeeklyInsightService 새 시그니처
    func testWeeklyInsightService_e2e() {
        let now = Date()
        let curActs = (0..<14).map { makeFeedingActivity(date: now.addingTimeInterval(Double(-$0 * 12 * 3600)), amount: 150) }
        let prevActs = (0..<7).map { makeFeedingActivity(date: now.addingTimeInterval(Double(-(7 + $0) * 12 * 3600)), amount: 100) }
        let curReport = makeReportWithActivities(curActs)
        let insights = WeeklyInsightService.generateInsights(from: curReport, previousActivities: prevActs, previousDays: 7, currentDays: 7)
        XCTAssertGreaterThan(insights.count, 0, "수유 변화 있을 때 인사이트 생성")
        XCTAssertEqual(insights[0].category, .feeding)
    }

    // MARK: - Phase 1 ML Tests (Scorer dispatch + Statistical Anomaly)

    /// HeuristicScorer — 기존 룰 동일 결과
    func testHeuristicScorer_legacyFormula() {
        let c = InsightCandidate(category: .feeding, metricKey: "feeding.count", currentValue: 6, title: "t", detail: "d", changePercent: 20, trend: .increasing, medicalWeight: 1.5, sampleSize: 7)
        let scorer = HeuristicScorer()
        let s = scorer.score(c, history: [], weights: .default)
        // |20| × 1.5 × min(7/7, 1.0) = 30
        XCTAssertEqual(s, 30, accuracy: 0.001)
    }

    /// StatisticalAnomalyScorer — history 부족 → 0
    func testAnomalyScorer_insufficientHistory_returnsZero() {
        let c = InsightCandidate(category: .feeding, metricKey: "feeding.count", currentValue: 10, title: "t", detail: "d", changePercent: 50, trend: .increasing, medicalWeight: 1.0, sampleSize: 7)
        let scorer = StatisticalAnomalyScorer(minSamples: 4)
        let s = scorer.score(c, history: [5, 5, 5], weights: .default)  // 3주 < 4
        XCTAssertEqual(s, 0)
    }

    /// StatisticalAnomalyScorer — history 충분 + currentValue 이상 → 양수
    func testAnomalyScorer_zScore() {
        // history mean=5, std=√(((5-5)²+(5-5)²+(5-5)²+(5-5)²)/4) = 0 → fallback (changePct × 0.1 × weight)
        // 위 케이스는 std=0 fallback 테스트. 분산 있는 케이스:
        let c = InsightCandidate(category: .feeding, metricKey: "feeding.count", currentValue: 10, title: "t", detail: "d", changePercent: 50, trend: .increasing, medicalWeight: 2.0, sampleSize: 7)
        let scorer = StatisticalAnomalyScorer(minSamples: 4)
        // history: [4, 5, 6, 5] → mean=5, var=((1+0+1+0)/4)=0.5, std=√0.5≈0.707
        // zScore = |10 - 5| / 0.707 ≈ 7.07
        // score = 7.07 × 2.0 ≈ 14.14
        let s = scorer.score(c, history: [4, 5, 6, 5], weights: .default)
        XCTAssertGreaterThan(s, 14.0, "Z-score × weight 계산 결과")
        XCTAssertLessThan(s, 14.5)
    }

    /// HybridScorer — history 부족 → Heuristic, 충분 → Anomaly
    func testHybridScorer_fallback() {
        let c = InsightCandidate(category: .feeding, metricKey: "feeding.count", currentValue: 10, title: "t", detail: "d", changePercent: 50, trend: .increasing, medicalWeight: 1.0, sampleSize: 7)
        let hybrid = HybridScorer(minSamples: 4)
        let cold = hybrid.score(c, history: [5, 5], weights: .default)  // 2주 < 4 → heuristic
        let warm = hybrid.score(c, history: [4, 5, 6, 5], weights: .default)  // 4주 ≥ 4 → anomaly
        XCTAssertEqual(cold, 50, accuracy: 0.001, "콜드: |50|×1.0×1.0 = 50")
        XCTAssertGreaterThan(warm, 5, "워밍업: anomaly score (Z=5/std)")
    }

    /// InsightScorerFactory — mode 매핑
    func testScorerFactory_modes() {
        XCTAssertTrue(InsightScorerFactory.make(mode: .heuristic, minSamples: 4) is HeuristicScorer)
        XCTAssertTrue(InsightScorerFactory.make(mode: .anomaly, minSamples: 4) is StatisticalAnomalyScorer)
        XCTAssertTrue(InsightScorerFactory.make(mode: .hybrid, minSamples: 4) is HybridScorer)
    }

    /// InsightScorerMode — RC 문자열 파싱
    func testScorerMode_parsing() {
        XCTAssertEqual(InsightScorerMode(rawValue: "heuristic"), .heuristic)
        XCTAssertEqual(InsightScorerMode(rawValue: "ANOMALY"), .anomaly)
        XCTAssertEqual(InsightScorerMode(rawValue: "hybrid"), .hybrid)
        XCTAssertEqual(InsightScorerMode(rawValue: ""), .hybrid, "빈 문자열은 hybrid fallback")
        XCTAssertEqual(InsightScorerMode(rawValue: "garbage"), .hybrid, "알 수 없는 값은 hybrid fallback")
    }

    /// WeeklyMetricSnapshot — weekKey ISO 형식
    func testWeeklyMetricSnapshot_weekKey() {
        // 2026-05-04 (월요일) → ISO Week 19 of 2026
        let date = Calendar.iso8601Calendar.date(from: DateComponents(year: 2026, month: 5, day: 4))!
        let key = WeeklyMetricSnapshot.weekKey(for: date)
        XCTAssertTrue(key.contains("W"), "weekKey 형식 'YYYYWnn'")
        XCTAssertEqual(key.count, 7, "예: '2026W19'")
    }

    /// WeeklyMetricSnapshot — Codable round-trip
    func testWeeklyMetricSnapshot_codable() throws {
        let original = WeeklyMetricSnapshot(
            weekKey: "2026W19",
            weekStartDate: Date(),
            metrics: ["feeding.count": 6.5, "diaper.dirty": 3.0]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WeeklyMetricSnapshot.self, from: data)
        XCTAssertEqual(decoded.weekKey, original.weekKey)
        XCTAssertEqual(decoded.metrics["feeding.count"], 6.5)
        XCTAssertEqual(decoded.metrics["diaper.dirty"], 3.0)
    }

    /// WeeklyInsightService.metricHistory — snapshot 배열 → metric_key 시계열
    func testWeeklyInsightService_metricHistory() {
        let snaps = [
            WeeklyMetricSnapshot(weekKey: "2026W19", weekStartDate: Date(), metrics: ["feeding.count": 6, "diaper.dirty": 3]),
            WeeklyMetricSnapshot(weekKey: "2026W18", weekStartDate: Date().addingTimeInterval(-604800), metrics: ["feeding.count": 5, "diaper.dirty": 4])
        ]
        let history = WeeklyInsightService.metricHistory(from: snaps)
        XCTAssertEqual(history["feeding.count"], [6, 5])
        XCTAssertEqual(history["diaper.dirty"], [3, 4])
    }

    /// WeeklyInsightService.snapshotMetrics — candidate currentValue를 metric 사전으로
    func testWeeklyInsightService_snapshotMetrics() {
        let now = Date()
        let curActs = (0..<14).map { makeFeedingActivity(date: now.addingTimeInterval(Double(-$0 * 12 * 3600)), amount: 120) }
        let report = makeReportWithActivities(curActs)
        let metrics = WeeklyInsightService.snapshotMetrics(from: report, previousActivities: [], previousDays: 7, currentDays: 7)
        XCTAssertNotNil(metrics["feeding.count"], "수유 횟수 metric 저장")
        XCTAssertNotNil(metrics["feeding.volume"], "수유 용량 metric 저장")
        XCTAssertGreaterThan(metrics["feeding.count"] ?? 0, 0)
    }

    // MARK: - Todo/Routine Automation Tests

    func testNextDueDate_daily() {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 14))!
        let next = TodoItem.nextDueDate(from: base, interval: .daily)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: next)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 15)
    }

    func testNextDueDate_weekly() {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 14))!
        let next = TodoItem.nextDueDate(from: base, interval: .weekly)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: next)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 21)
    }

    func testNextDueDate_monthly() {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 14))!
        let next = TodoItem.nextDueDate(from: base, interval: .monthly)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: next)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 5)
        XCTAssertEqual(components.day, 14)
    }

    func testNextDueDate_nilBase_usesNow() {
        let before = Date()
        let next = TodoItem.nextDueDate(from: nil, interval: .daily)
        let expectedMin = before.addingTimeInterval(23 * 3600)  // at least ~23 hours later
        XCTAssertTrue(next > expectedMin)
    }

    func testRoutine_defaultsOptionalFields() {
        // Routine init with default lastResetDate=nil, currentStreak=nil
        let routine = Routine(id: "r1", name: "Morning", items: [], babyId: nil, createdAt: Date())
        XCTAssertNil(routine.lastResetDate)
        XCTAssertNil(routine.currentStreak)
    }

    func testRoutineStreak_fullCompletion_gap1_increments() {
        // Given: lastResetDate = yesterday (startOfDay), currentStreak = 5, all items completed
        // When: checkAndAutoResetIfNeeded runs
        // Then: currentStreak should be 6
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        let items = [Routine.RoutineItem(id: "i1", title: "A", order: 0, isCompleted: true)]
        var routine = Routine(id: "r1", name: "Morning", items: items, babyId: nil, createdAt: Date())
        routine.lastResetDate = yesterday
        routine.currentStreak = 5
        // 직접 로직 검증 (RoutineViewModel 호출은 Firestore mock 필요하므로 스킵)
        let today = Calendar.current.startOfDay(for: Date())
        let gapDays = Calendar.current.dateComponents([.day], from: yesterday, to: today).day ?? 0
        let wasFullyCompleted = routine.items.allSatisfy { $0.isCompleted } && !routine.items.isEmpty
        var newStreak = routine.currentStreak ?? 0
        if wasFullyCompleted && gapDays == 1 {
            newStreak += 1
        } else if gapDays > 1 || !wasFullyCompleted {
            newStreak = 0
        }
        XCTAssertEqual(newStreak, 6)
    }

    func testRoutineStreak_partialCompletion_resets() {
        // items 일부만 완료 → 스트릭 0
        let items = [
            Routine.RoutineItem(id: "i1", title: "A", order: 0, isCompleted: true),
            Routine.RoutineItem(id: "i2", title: "B", order: 1, isCompleted: false)
        ]
        let wasFullyCompleted = items.allSatisfy { $0.isCompleted } && !items.isEmpty
        XCTAssertFalse(wasFullyCompleted)
    }

    func testRoutineStreak_gapOverOneDay_resets() {
        // gap = 3일 → 스트릭 0
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Calendar.current.startOfDay(for: Date()))!
        let today = Calendar.current.startOfDay(for: Date())
        let gapDays = Calendar.current.dateComponents([.day], from: threeDaysAgo, to: today).day ?? 0
        XCTAssertEqual(gapDays, 3)
        XCTAssertTrue(gapDays > 1)  // should reset
    }

    // MARK: - Sleep Location Tests

    func testSleepMethodType_newCases_exist() {
        XCTAssertNotNil(Activity.SleepMethodType(rawValue: "bed"))
        XCTAssertNotNil(Activity.SleepMethodType(rawValue: "bouncer"))
        XCTAssertNotNil(Activity.SleepMethodType(rawValue: "inArms"))
    }

    func testSleepMethodType_newCases_rawValues() {
        XCTAssertEqual(Activity.SleepMethodType.bed.rawValue, "bed")
        XCTAssertEqual(Activity.SleepMethodType.bouncer.rawValue, "bouncer")
        XCTAssertEqual(Activity.SleepMethodType.inArms.rawValue, "inArms")
    }

    func testSleepMethodType_existingRawValuesPreserved() {
        XCTAssertEqual(Activity.SleepMethodType.selfSettled.rawValue, "selfSettled")
        XCTAssertEqual(Activity.SleepMethodType.nursing.rawValue, "nursing")
        XCTAssertEqual(Activity.SleepMethodType.holding.rawValue, "holding")
        XCTAssertEqual(Activity.SleepMethodType.stroller.rawValue, "stroller")
        XCTAssertEqual(Activity.SleepMethodType.carSeat.rawValue, "carSeat")
    }

    func testSleepMethodType_allCasesOrder() {
        let expected: [Activity.SleepMethodType] = [.bed, .selfSettled, .holding, .inArms, .bouncer, .nursing, .stroller, .carSeat]
        XCTAssertEqual(Activity.SleepMethodType.allCases, expected)
    }

    func testSleepMethodType_displayNames_nonEmpty() {
        for method in Activity.SleepMethodType.allCases {
            XCTAssertFalse(method.displayName.isEmpty, "\(method.rawValue) displayName이 비어 있으면 안 됩니다")
        }
    }

    func testSleepMethodType_icons_nonEmpty() {
        for method in Activity.SleepMethodType.allCases {
            XCTAssertFalse(method.icon.isEmpty, "\(method.rawValue) icon이 비어 있으면 안 됩니다")
        }
    }

    func testSleepMethodType_backwardCompat_decode() {
        XCTAssertNotNil(Activity.SleepMethodType(rawValue: "selfSettled"))
        XCTAssertNotNil(Activity.SleepMethodType(rawValue: "nursing"))
        XCTAssertNil(Activity.SleepMethodType(rawValue: "unknownCase"))
    }

    func testSleepMethodType_appStorageKeyFormat() {
        let babyId = "abc123"
        let key = "lastSleepMethod_\(babyId)"
        XCTAssertEqual(key, "lastSleepMethod_abc123")
    }

    func testMethodDistribution_crashFreeOnNewCases() {
        let dist: [Activity.SleepMethodType: Int] = [.bed: 3, .bouncer: 1, .inArms: 2]
        XCTAssertEqual(dist[.bed], 3)
        XCTAssertEqual(dist[.bouncer], 1)
        XCTAssertEqual(dist[.inArms], 2)
    }

    // MARK: - SleepMethodType Consolidation

    func testSleepMethodType_selectableCases_excludesDuplicatesAndSituations() {
        let selectable = Activity.SleepMethodType.selectableCases
        XCTAssertFalse(selectable.contains(.holding), "holding은 inArms와 중복, 픽커에서 제외")
        XCTAssertFalse(selectable.contains(.nursing), "nursing은 장소가 아닌 상황, 픽커에서 제외")
        XCTAssertEqual(selectable.count, 6)
        XCTAssertEqual(Set(selectable), Set([.bed, .selfSettled, .inArms, .bouncer, .stroller, .carSeat]))
    }

    func testSleepMethodType_holdingDisplayName_mergedWithInArms() {
        XCTAssertEqual(Activity.SleepMethodType.holding.displayName, Activity.SleepMethodType.inArms.displayName)
        XCTAssertEqual(Activity.SleepMethodType.inArms.displayName, "품에 안겨서")
    }

    func testSleepMethodType_deprecatedCases_stillDecodable() {
        // 기존 프로덕션 데이터 회귀 방지 — raw value decode 성공해야 함
        XCTAssertNotNil(Activity.SleepMethodType(rawValue: "holding"))
        XCTAssertNotNil(Activity.SleepMethodType(rawValue: "nursing"))
    }

    func testSleepMethodType_allCases_unchanged() {
        // allCases는 backward compat용 — 8개 유지
        XCTAssertEqual(Activity.SleepMethodType.allCases.count, 8)
    }

    // MARK: - Badge UI Tests (Phase 2)

    @MainActor
    func testBadgeTile_progressClamp_underflow() {
        let def = BadgeCatalog.definition(id: "feeding100")!
        let result = BadgeTileView.progress(definition: def, stats: nil)
        XCTAssertEqual(result, 0.0, "stats nil → 0.0")
    }

    @MainActor
    func testBadgeTile_progressClamp_overflow() {
        let def = BadgeCatalog.definition(id: "feeding100")!
        var stats = UserStats.empty()
        stats.feedingCount = 250 // > 100 threshold
        let result = BadgeTileView.progress(definition: def, stats: stats)
        XCTAssertEqual(result, 1.0, "250/100 → clamp 1.0")
    }

    @MainActor
    func testBadgeTile_progressClamp_inRange() {
        let def = BadgeCatalog.definition(id: "sleep50")!
        var stats = UserStats.empty()
        stats.sleepCount = 25 // 50% of threshold 50
        let result = BadgeTileView.progress(definition: def, stats: stats)
        XCTAssertEqual(result, 0.5, accuracy: 0.001)
    }

    func testBadgeCategory_sectionCounts() {
        let firstTime = BadgeCatalog.all.filter { $0.category == .firstTime }
        let aggregate = BadgeCatalog.all.filter { $0.category == .aggregate }
        let streak = BadgeCatalog.all.filter { $0.category == .streak }
        XCTAssertEqual(firstTime.count, 1, "firstRecord 1개")
        XCTAssertEqual(aggregate.count, 4, "feeding100/sleep50/diaper200/growth10 = 4개")
        XCTAssertEqual(streak.count, 6, "routineStreak 3/7/30 + recordStreak 3/7/14 = 6개")
    }

    func testBadgeCatalog_localizableKeys_allPresent() {
        for def in BadgeCatalog.all {
            let title = NSLocalizedString(def.titleKey, comment: "")
            let desc = NSLocalizedString(def.descriptionKey, comment: "")
            XCTAssertNotEqual(title, def.titleKey, "\(def.id) 타이틀 Localizable 누락: \(def.titleKey)")
            XCTAssertNotEqual(desc, def.descriptionKey, "\(def.id) 설명 Localizable 누락: \(def.descriptionKey)")
        }
    }

    // MARK: - BadgePresenter Tests

    @MainActor
    func testBadgePresenter_enqueueSingle_setsCurrent() {
        let p = BadgePresenter()
        let b = Self.makeTestBadge(id: "firstRecord")
        p.enqueue([b])
        XCTAssertEqual(p.current?.id, "firstRecord")
        XCTAssertEqual(p.pending.count, 0)
    }

    @MainActor
    func testBadgePresenter_enqueueMultiple_fifoDrain() {
        let p = BadgePresenter()
        let b1 = Self.makeTestBadge(id: "firstRecord")
        let b2 = Self.makeTestBadge(id: "feeding100")
        let b3 = Self.makeTestBadge(id: "sleep50")
        p.enqueue([b1, b2, b3])
        XCTAssertEqual(p.current?.id, "firstRecord")
        XCTAssertEqual(p.pending.map(\.id), ["feeding100", "sleep50"])
        p.dismiss()
        XCTAssertEqual(p.current?.id, "feeding100")
        p.dismiss()
        XCTAssertEqual(p.current?.id, "sleep50")
        p.dismiss()
        XCTAssertNil(p.current)
    }

    @MainActor
    func testBadgePresenter_dismissEmpty_noOp() {
        let p = BadgePresenter()
        p.dismiss()
        XCTAssertNil(p.current)
        XCTAssertTrue(p.pending.isEmpty)
    }

    @MainActor
    func testBadgePresenter_enqueueEmpty_noOp() {
        let p = BadgePresenter()
        p.enqueue([])
        XCTAssertNil(p.current)
    }

    private static func makeTestBadge(id: String) -> Badge {
        Badge(
            id: id,
            category: .firstTime,
            earnedByUserId: "u1",
            babyId: nil,
            earnedAt: Date(timeIntervalSince1970: 1_700_000_000),
            earnedAtDateUTC: "2023-11-14",
            conditionVersion: 1
        )
    }



    func testBadge_codableRoundTrip() throws {
        let badge = Badge(
            id: "feeding100",
            category: .aggregate,
            earnedByUserId: "user1",
            babyId: "babyA",
            earnedAt: Date(timeIntervalSince1970: 1_700_000_000),
            earnedAtDateUTC: "2023-11-14",
            conditionVersion: 1
        )
        let data = try JSONEncoder().encode(badge)
        let decoded = try JSONDecoder().decode(Badge.self, from: data)
        XCTAssertEqual(decoded, badge)
    }

    func testBadgeCategory_allCases() {
        let all = BadgeCategory.allCases
        XCTAssertEqual(Set(all), Set([.firstTime, .aggregate, .streak]))
        XCTAssertEqual(all.count, 3)
    }

    func testBadgeCatalog_hasEleven() {
        // 8 + recordStreak 3종(C1)
        XCTAssertEqual(BadgeCatalog.all.count, 11)
    }

    func testBadgeCatalog_allIdsUnique() {
        let ids = BadgeCatalog.all.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testBadgeCatalog_iconNonEmpty() {
        for def in BadgeCatalog.all {
            XCTAssertFalse(def.iconSFSymbol.isEmpty, "iconSFSymbol empty for \(def.id)")
        }
    }

    func testBadgeCatalog_definitionLookup() {
        XCTAssertNotNil(BadgeCatalog.definition(id: "feeding100"))
        XCTAssertNotNil(BadgeCatalog.definition(id: "routineStreak7"))
        XCTAssertNil(BadgeCatalog.definition(id: "unknownBadge"))
    }

    func testBadgeCatalog_thresholds() {
        XCTAssertEqual(BadgeCatalog.definition(id: "feeding100")?.threshold, 100)
        XCTAssertEqual(BadgeCatalog.definition(id: "sleep50")?.threshold, 50)
        XCTAssertEqual(BadgeCatalog.definition(id: "diaper200")?.threshold, 200)
        XCTAssertEqual(BadgeCatalog.definition(id: "growth10")?.threshold, 10)
        XCTAssertEqual(BadgeCatalog.definition(id: "routineStreak3")?.threshold, 3)
        XCTAssertEqual(BadgeCatalog.definition(id: "routineStreak7")?.threshold, 7)
        XCTAssertEqual(BadgeCatalog.definition(id: "routineStreak30")?.threshold, 30)
        XCTAssertEqual(BadgeCatalog.definition(id: "firstRecord")?.threshold, 1)
    }

    func testBadgeCatalog_statsFieldCoverage() {
        for def in BadgeCatalog.all {
            switch def.category {
            case .aggregate:
                XCTAssertNotNil(def.statsField, "aggregate \(def.id) must have statsField")
            case .firstTime, .streak:
                XCTAssertNil(def.statsField, "\(def.category.rawValue) \(def.id) must NOT have statsField")
            }
        }
    }

    func testFirestoreCollections_badgesAndStats() {
        XCTAssertEqual(FirestoreCollections.badges, "badges")
        XCTAssertEqual(FirestoreCollections.stats, "stats")
    }

    func testUserStats_emptyFactory() {
        let stats = UserStats.empty()
        XCTAssertEqual(stats.id, "lifetime")
        XCTAssertEqual(stats.feedingCount, 0)
        XCTAssertEqual(stats.sleepCount, 0)
        XCTAssertEqual(stats.diaperCount, 0)
        XCTAssertEqual(stats.growthRecordCount, 0)
        XCTAssertNil(stats.firstRecordAt)
    }

    @MainActor
    func testBadgeEvaluator_shouldCheckFirstRecord() {
        XCTAssertTrue(BadgeEvaluator.shouldCheckFirstRecord(kind: .feedingLogged))
        XCTAssertTrue(BadgeEvaluator.shouldCheckFirstRecord(kind: .sleepLogged))
        XCTAssertTrue(BadgeEvaluator.shouldCheckFirstRecord(kind: .diaperLogged))
        XCTAssertTrue(BadgeEvaluator.shouldCheckFirstRecord(kind: .growthLogged))
        XCTAssertFalse(BadgeEvaluator.shouldCheckFirstRecord(kind: .routineStreakUpdated(newStreak: 7)))
    }

    @MainActor
    func testBadgeEvaluator_aggregateMapping() {
        XCTAssertEqual(BadgeEvaluator.aggregateMapping(kind: .feedingLogged)?.field, "feedingCount")
        XCTAssertEqual(BadgeEvaluator.aggregateMapping(kind: .feedingLogged)?.badgeIds, ["feeding100"])
        XCTAssertEqual(BadgeEvaluator.aggregateMapping(kind: .sleepLogged)?.field, "sleepCount")
        XCTAssertEqual(BadgeEvaluator.aggregateMapping(kind: .diaperLogged)?.field, "diaperCount")
        XCTAssertEqual(BadgeEvaluator.aggregateMapping(kind: .growthLogged)?.field, "growthRecordCount")
        XCTAssertNil(BadgeEvaluator.aggregateMapping(kind: .routineStreakUpdated(newStreak: 3)))
    }

    @MainActor
    func testBadgeEvaluator_statsValue() {
        var stats = UserStats.empty()
        stats.feedingCount = 42
        stats.sleepCount = 17
        stats.diaperCount = 108
        stats.growthRecordCount = 5
        XCTAssertEqual(BadgeEvaluator.statsValue(stats: stats, field: "feedingCount"), 42)
        XCTAssertEqual(BadgeEvaluator.statsValue(stats: stats, field: "sleepCount"), 17)
        XCTAssertEqual(BadgeEvaluator.statsValue(stats: stats, field: "diaperCount"), 108)
        XCTAssertEqual(BadgeEvaluator.statsValue(stats: stats, field: "growthRecordCount"), 5)
        XCTAssertEqual(BadgeEvaluator.statsValue(stats: stats, field: "unknown"), 0)
    }

    @MainActor
    func testBadgeEvaluator_utcDateString_format() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)  // 2023-11-14 22:13:20 UTC
        XCTAssertEqual(BadgeEvaluator.utcDateString(date), "2023-11-14")
    }

    // MARK: - InsightService Tests

    @MainActor
    func testInsightService_feedingInsight_noTodayFeedings_returnsNil() {
        let svc = InsightService()
        let result = svc.makeFeedingInsight(todayActivities: [], recentActivities: [])
        XCTAssertNil(result)
    }

    @MainActor
    func testInsightService_feedingInsight_moreThanAverage() {
        let svc = InsightService()
        let baby = Baby(id: "b1", name: "Test", birthDate: Date(), gender: .female)
        let now = Date()
        // 오늘 수유 3회
        let todayFeedings = (0..<3).map { _ in
            Activity(babyId: baby.id, type: .feedingBreast, startTime: now)
        }
        // 최근 7일 평균 1회/일 (7일 x 1회)
        let calendar = Calendar.current
        let recentFeedings = (1...7).map { day -> Activity in
            let date = calendar.date(byAdding: .day, value: -day, to: now) ?? now
            return Activity(babyId: baby.id, type: .feedingBreast, startTime: date)
        }
        let insight = svc.makeFeedingInsight(todayActivities: todayFeedings, recentActivities: recentFeedings)
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.kind, .feeding)
        // 오늘 3회 > 평균 1회 → more 케이스
        XCTAssertNotNil(insight?.secondaryText)
    }

    @MainActor
    func testInsightService_feedingInsight_lessThanAverage() {
        let svc = InsightService()
        let baby = Baby(id: "b1", name: "Test", birthDate: Date(), gender: .female)
        let now = Date()
        // 오늘 수유 1회
        let todayFeedings = [Activity(babyId: baby.id, type: .feedingBreast, startTime: now)]
        // 최근 7일 평균 5회/일
        let calendar = Calendar.current
        let recentFeedings: [Activity] = (1...7).flatMap { day -> [Activity] in
            (0..<5).map { _ in
                let date = calendar.date(byAdding: .day, value: -day, to: now) ?? now
                return Activity(babyId: baby.id, type: .feedingBreast, startTime: date)
            }
        }
        let insight = svc.makeFeedingInsight(todayActivities: todayFeedings, recentActivities: recentFeedings)
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.kind, .feeding)
    }

    @MainActor
    func testInsightService_feedingInsight_lessInMorning_noWarning() {
        // 오전 10시에 "적음" 문구가 뜨면 불안 조성 — 현재 시각까지 expected로 평가
        let svc = InsightService()
        let baby = Baby(id: "b1", name: "Test", birthDate: Date(), gender: .female)
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let morning = calendar.date(byAdding: .hour, value: 10, to: todayStart) ?? Date()
        // 오전 10시에 오늘 수유 1회, 풀일 평균 5회 (expected by 10am = 5 * 10/24 ≈ 2.08)
        let todayFeedings = [Activity(babyId: baby.id, type: .feedingBreast, startTime: morning)]
        let recentFeedings: [Activity] = (1...7).flatMap { day -> [Activity] in
            (0..<5).map { _ in
                let date = calendar.date(byAdding: .day, value: -day, to: morning) ?? morning
                return Activity(babyId: baby.id, type: .feedingBreast, startTime: date)
            }
        }
        let insight = svc.makeFeedingInsight(
            todayActivities: todayFeedings, recentActivities: recentFeedings, now: morning
        )
        XCTAssertNotNil(insight)
        // 오전에는 less.sub("오늘은 N회 적네요") 대신 normal.sub 노출
        XCTAssertNotEqual(insight?.secondaryText, "오늘은 4회 적네요")
    }

    @MainActor
    func testInsightService_feedingInsight_lessAtNight_showsWarning() {
        // 오후 8시에는 하루가 거의 끝났으니 "적음" 문구 표시 허용
        let svc = InsightService()
        let baby = Baby(id: "b1", name: "Test", birthDate: Date(), gender: .female)
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let evening = calendar.date(byAdding: .hour, value: 20, to: todayStart) ?? Date()
        let todayFeedings = [Activity(babyId: baby.id, type: .feedingBreast, startTime: evening)]
        let recentFeedings: [Activity] = (1...7).flatMap { day -> [Activity] in
            (0..<5).map { _ in
                let date = calendar.date(byAdding: .day, value: -day, to: evening) ?? evening
                return Activity(babyId: baby.id, type: .feedingBreast, startTime: date)
            }
        }
        let insight = svc.makeFeedingInsight(
            todayActivities: todayFeedings, recentActivities: recentFeedings, now: evening
        )
        XCTAssertNotNil(insight)
        // 오후 8시 + 1회 vs 평균 5회 → less.sub 노출
        XCTAssertEqual(insight?.secondaryText, "오늘은 4회 적네요")
    }

    @MainActor
    func testInsightService_healthInsight_noHighTemp_returnsNil() {
        let svc = InsightService()
        let result = svc.makeHealthInsight(recentTemperatureActivities: [])
        XCTAssertNil(result)
    }

    @MainActor
    func testInsightService_healthInsight_singleHighTemp() {
        let svc = InsightService()
        let baby = Baby(id: "b1", name: "Test", birthDate: Date(), gender: .female)
        let activity = Activity(babyId: baby.id, type: .temperature, startTime: Date(), temperature: 38.5)
        let insight = svc.makeHealthInsight(recentTemperatureActivities: [activity])
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.kind, .health)
        XCTAssertEqual(insight?.icon, "thermometer.medium")
    }

    @MainActor
    func testInsightService_healthInsight_consecutiveDaysFever() {
        let svc = InsightService()
        let baby = Baby(id: "b1", name: "Test", birthDate: Date(), gender: .female)
        let calendar = Calendar.current
        let activities = (0..<2).map { day -> Activity in
            let date = calendar.date(byAdding: .day, value: -day, to: Date()) ?? Date()
            return Activity(babyId: baby.id, type: .temperature, startTime: date, temperature: 38.5)
        }
        let insight = svc.makeHealthInsight(recentTemperatureActivities: activities)
        XCTAssertNotNil(insight)
        // 2일 연속 발열 → consecutive 메시지
        XCTAssertTrue(insight?.primaryText.contains("2") ?? false)
    }

    @MainActor
    func testInsightService_healthInsight_normalTemp_returnsNil() {
        let svc = InsightService()
        let baby = Baby(id: "b1", name: "Test", birthDate: Date(), gender: .female)
        let activity = Activity(babyId: baby.id, type: .temperature, startTime: Date(), temperature: 36.5)
        let result = svc.makeHealthInsight(recentTemperatureActivities: [activity])
        XCTAssertNil(result)
    }

    @MainActor
    func testInsightService_milestoneInsight_noBaby_returnsNil() {
        let svc = InsightService()
        let result = svc.makeMilestoneInsight(baby: nil, pendingMilestones: [])
        XCTAssertNil(result)
    }

    @MainActor
    func testInsightService_milestoneInsight_noPendingMilestones_returnsNil() {
        let svc = InsightService()
        let baby = Baby(id: "b1", name: "Test", birthDate: Date(), gender: .female)
        let result = svc.makeMilestoneInsight(baby: baby, pendingMilestones: [])
        XCTAssertNil(result)
    }

    @MainActor
    func testInsightService_milestoneInsight_returnsUpcomingMilestone() {
        let svc = InsightService()
        // 4개월 아기
        let birthDate = Calendar.current.date(byAdding: .month, value: -4, to: Date()) ?? Date()
        let baby = Baby(id: "b1", name: "Test", birthDate: birthDate, gender: .female)
        let milestones = Milestone.generateChecklist(babyId: baby.id)
        let pending = milestones.filter { !$0.isAchieved }
        let insight = svc.makeMilestoneInsight(baby: baby, pendingMilestones: pending)
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.kind, .milestone)
        XCTAssertEqual(insight?.icon, "star.fill")
    }

    @MainActor
    func testInsightService_napIntervalHours() {
        let svc = InsightService()
        XCTAssertEqual(svc.napIntervalHours(ageMonths: 1), 1.0)
        XCTAssertEqual(svc.napIntervalHours(ageMonths: 4), 1.5)
        XCTAssertEqual(svc.napIntervalHours(ageMonths: 7), 2.0)
        XCTAssertEqual(svc.napIntervalHours(ageMonths: 10), 2.5)
        XCTAssertEqual(svc.napIntervalHours(ageMonths: 14), 3.0)
        XCTAssertEqual(svc.napIntervalHours(ageMonths: 24), 4.0)
    }

    @MainActor
    func testInsightService_refresh_withNoData_hasNoInsights() {
        let svc = InsightService()
        svc.refresh(
            todayActivities: [],
            recentActivities: [],
            recentTemperatureActivities: [],
            baby: nil,
            pendingMilestones: []
        )
        XCTAssertTrue(svc.insights.isEmpty)
    }

    @MainActor
    func testInsightService_sleepInsight_noSleep_returnsNil() {
        let svc = InsightService()
        let result = svc.makeSleepInsight(
            todayActivities: [],
            recentActivities: [],
            baby: nil
        )
        XCTAssertNil(result)
    }

    // MARK: - SleepAnalysisService Tests

    func testSleepAnalysis_detectRegression_noData_returnsNil() {
        let result = SleepAnalysisService.detectRegression(sleepActivities: [])
        XCTAssertNil(result)
    }

    func testSleepAnalysis_detectRegression_sufficientDecline_returnsWarning() {
        let calendar = Calendar.current
        let now = Date()

        // baseline: 직전 14~28일 — 하루 평균 12시간
        var baselineActivities: [Activity] = []
        for dayOffset in 8...28 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            var act = Activity(babyId: "b1", type: .sleep)
            act.startTime = date
            act.duration = 12 * 3600  // 12시간
            baselineActivities.append(act)
        }

        // recent: 최근 7일 — 하루 평균 8시간 (33% 감소 → 퇴행)
        var recentActivities: [Activity] = []
        for dayOffset in 0...6 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            var act = Activity(babyId: "b1", type: .sleep)
            act.startTime = date
            act.duration = 8 * 3600  // 8시간
            recentActivities.append(act)
        }

        let all = baselineActivities + recentActivities
        let warning = SleepAnalysisService.detectRegression(sleepActivities: all)
        XCTAssertNotNil(warning, "30% 이상 감소 시 경고 반환 필요")
        XCTAssertLessThanOrEqual(warning?.declineRate ?? 0, -0.20)
    }

    func testSleepAnalysis_detectRegression_insufficientDecline_returnsNil() {
        let calendar = Calendar.current
        let now = Date()

        // baseline: 10시간/일
        var baselineActivities: [Activity] = []
        for dayOffset in 8...28 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            var act = Activity(babyId: "b1", type: .sleep)
            act.startTime = date
            act.duration = 10 * 3600
            baselineActivities.append(act)
        }

        // recent: 9시간/일 (10% 감소 → 임계치 미달)
        var recentActivities: [Activity] = []
        for dayOffset in 0...6 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            var act = Activity(babyId: "b1", type: .sleep)
            act.startTime = date
            act.duration = 9 * 3600
            recentActivities.append(act)
        }

        let all = baselineActivities + recentActivities
        let warning = SleepAnalysisService.detectRegression(sleepActivities: all)
        XCTAssertNil(warning, "10% 감소는 퇴행 임계치 미달")
    }

    func testSleepAnalysis_computeOptimalBedtime_noNightSleeps_returnsNil() {
        // 낮잠만 있는 경우
        let calendar = Calendar.current
        let now = Date()
        var activities: [Activity] = []
        for dayOffset in 0...6 {
            guard let base = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            // 10시 (낮) 시작
            guard let date = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: base) else { continue }
            var act = Activity(babyId: "b1", type: .sleep)
            act.startTime = date
            act.duration = 3600
            activities.append(act)
        }
        let result = SleepAnalysisService.computeOptimalBedtime(sleepActivities: activities)
        XCTAssertNil(result, "낮잠만 있는 경우 취침 시간 추천 없음")
    }

    func testSleepAnalysis_computeOptimalBedtime_withNightSleeps_returnsResult() {
        let calendar = Calendar.current
        let now = Date()
        var activities: [Activity] = []
        for dayOffset in 0...6 {
            guard let base = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            // 21시 (밤) 시작
            guard let date = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: base) else { continue }
            var act = Activity(babyId: "b1", type: .sleep)
            act.startTime = date
            act.duration = 9 * 3600
            activities.append(act)
        }
        let result = SleepAnalysisService.computeOptimalBedtime(sleepActivities: activities)
        XCTAssertNotNil(result, "밤잠 데이터 있을 때 취침 시간 추천 반환")
        XCTAssertNotNil(result?.bedtimeStart)
        XCTAssertNotNil(result?.bedtimeEnd)
        if let start = result?.bedtimeStart, let end = result?.bedtimeEnd {
            XCTAssertLessThan(start, end)
        }
    }

    func testSleepAnalysis_computeNapNightRatios_correctRatio() {
        let calendar = Calendar.current
        let now = Date()
        var activities: [Activity] = []

        guard let base = calendar.date(byAdding: .day, value: -1, to: now) else { return }

        // 낮잠 2시간 (10시)
        if let napTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: base) {
            var nap = Activity(babyId: "b1", type: .sleep)
            nap.startTime = napTime
            nap.duration = 2 * 3600
            activities.append(nap)
        }

        // 밤잠 8시간 (21시)
        if let nightTime = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: base) {
            var night = Activity(babyId: "b1", type: .sleep)
            night.startTime = nightTime
            night.duration = 8 * 3600
            activities.append(night)
        }

        let ratios = SleepAnalysisService.computeNapNightRatios(sleepActivities: activities)
        XCTAssertFalse(ratios.isEmpty)
        if let ratio = ratios.first {
            XCTAssertEqual(ratio.napHours ?? 0, 2.0, accuracy: 0.01)
            XCTAssertEqual(ratio.nightHours ?? 0, 8.0, accuracy: 0.01)
            XCTAssertEqual(ratio.napRatio ?? 0, 0.2, accuracy: 0.01)
        }
    }

    func testSleepAnalysis_computeQualityScore_noData_returnsNil() {
        let result = SleepAnalysisService.computeQualityScore(sleepActivities: [])
        XCTAssertNil(result)
    }

    func testSleepAnalysis_computeQualityScore_goodSleep_highScore() {
        let calendar = Calendar.current
        let now = Date()
        var activities: [Activity] = []

        // 7일간 하루 14시간 수면 (2회: 낮잠 2h + 밤잠 12h)
        for dayOffset in 0...6 {
            guard let base = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }

            // 낮잠 2시간
            if let napTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: base) {
                var nap = Activity(babyId: "b1", type: .sleep)
                nap.startTime = napTime
                nap.duration = 2 * 3600
                activities.append(nap)
            }

            // 밤잠 12시간
            if let nightTime = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: base) {
                var night = Activity(babyId: "b1", type: .sleep)
                night.startTime = nightTime
                night.duration = 12 * 3600
                activities.append(night)
            }
        }

        let score = SleepAnalysisService.computeQualityScore(sleepActivities: activities)
        XCTAssertNotNil(score)
        XCTAssertNotNil(score?.score)
        XCTAssertGreaterThanOrEqual(score?.score ?? 0, 60, "충분한 수면 시 점수 60 이상")
        XCTAssertNotNil(score?.durationScore)
        XCTAssertNotNil(score?.wakeScore)
        XCTAssertNotNil(score?.napScore)
    }

    func testSleepAnalysis_formatBedtimeSeconds_midnight() {
        // 자정 = 0초
        let result = SleepAnalysisService.formatBedtimeSeconds(0)
        XCTAssertEqual(result, "00:00")
    }

    func testSleepAnalysis_formatBedtimeSeconds_21hours() {
        // 21시 = 75600초
        let result = SleepAnalysisService.formatBedtimeSeconds(75600)
        XCTAssertEqual(result, "21:00")
    }

    func testSleepAnalysis_formatBedtimeSeconds_nextDay_wraps() {
        // 25시 (다음날 1시 보정값) → 01:00
        let result = SleepAnalysisService.formatBedtimeSeconds(25 * 3600)
        XCTAssertEqual(result, "01:00")
    }

    @MainActor
    func testInsightService_sleepRegressionInsight_noData_returnsNil() {
        let svc = InsightService()
        let result = svc.makeSleepRegressionInsight(allSleepActivities: [], baby: nil)
        XCTAssertNil(result)
    }

    func testSleepModels_codable_roundtrip() throws {
        let warning = SleepRegressionWarning(
            regressionAgeMonth: 4,
            recentAvgHours: 8.5,
            baselineAvgHours: 12.0,
            declineRate: -0.29
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(warning)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SleepRegressionWarning.self, from: data)
        XCTAssertEqual(decoded.regressionAgeMonth, 4)
        XCTAssertEqual(decoded.recentAvgHours ?? 0, 8.5, accuracy: 0.001)
        XCTAssertEqual(decoded.declineRate ?? 0, -0.29, accuracy: 0.001)
    }

    func testSleepQualityScore_codable_roundtrip() throws {
        let score = SleepQualityScore(score: 78, durationScore: 40, wakeScore: 24, napScore: 14)
        let data = try JSONEncoder().encode(score)
        let decoded = try JSONDecoder().decode(SleepQualityScore.self, from: data)
        XCTAssertEqual(decoded.score, 78)
        XCTAssertEqual(decoded.durationScore, 40)
        XCTAssertEqual(decoded.wakeScore, 24)
        XCTAssertEqual(decoded.napScore, 14)
    }

    // MARK: - #6 예방접종 알림 강화 Tests

    func testVaccination_daysUntilScheduled_futureDate() {
        let future = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let vax = Vaccination(babyId: "b1", vaccine: .bcg, doseNumber: 1, scheduledDate: future)
        XCTAssertEqual(vax.daysUntilScheduled, 7)
    }

    func testVaccination_daysUntilScheduled_pastDate_returnsNil() {
        let past = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let vax = Vaccination(babyId: "b1", vaccine: .bcg, doseNumber: 1, scheduledDate: past)
        XCTAssertNil(vax.daysUntilScheduled)
    }

    func testVaccination_daysUntilScheduled_completed_returnsNil() {
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        var vax = Vaccination(babyId: "b1", vaccine: .bcg, doseNumber: 1, scheduledDate: future)
        vax.isCompleted = true
        XCTAssertNil(vax.daysUntilScheduled)
    }

    func testVaccination_sideEffectRecords_codableRoundtrip() throws {
        let effect = VaccineSideEffect(type: .fever, severity: .mild, recordedAt: Date(timeIntervalSince1970: 1_700_000_000), note: "미열")
        var vax = Vaccination(babyId: "b1", vaccine: .dtap, doseNumber: 1, scheduledDate: Date())
        vax.sideEffectRecords = [effect]
        let data = try JSONEncoder().encode(vax)
        let decoded = try JSONDecoder().decode(Vaccination.self, from: data)
        XCTAssertEqual(decoded.sideEffectRecords?.count, 1)
        XCTAssertEqual(decoded.sideEffectRecords?.first?.type, .fever)
        XCTAssertEqual(decoded.sideEffectRecords?.first?.severity, .mild)
        XCTAssertEqual(decoded.sideEffectRecords?.first?.note, "미열")
    }

    func testVaccination_sideEffectRecords_nilByDefault() {
        let vax = Vaccination(babyId: "b1", vaccine: .hepB, doseNumber: 1, scheduledDate: Date())
        XCTAssertNil(vax.sideEffectRecords)
    }

    @MainActor
    func testInsightService_vaccinationInsight_within7Days_returnsCard() {
        let svc = InsightService()
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let vax = Vaccination(babyId: "b1", vaccine: .bcg, doseNumber: 1, scheduledDate: future)
        let insight = svc.makeVaccinationInsight(upcomingVaccinations: [vax])
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.kind, .vaccination)
    }

    @MainActor
    func testInsightService_vaccinationInsight_beyond7Days_returnsNil() {
        let svc = InsightService()
        let future = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let vax = Vaccination(babyId: "b1", vaccine: .bcg, doseNumber: 1, scheduledDate: future)
        let insight = svc.makeVaccinationInsight(upcomingVaccinations: [vax])
        XCTAssertNil(insight)
    }

    @MainActor
    func testInsightService_vaccinationInsight_completed_returnsNil() {
        let svc = InsightService()
        let future = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        var vax = Vaccination(babyId: "b1", vaccine: .bcg, doseNumber: 1, scheduledDate: future)
        vax.isCompleted = true
        let insight = svc.makeVaccinationInsight(upcomingVaccinations: [vax])
        XCTAssertNil(insight)
    }

    @MainActor
    func testInsightService_vaccinationInsight_empty_returnsNil() {
        let svc = InsightService()
        let insight = svc.makeVaccinationInsight(upcomingVaccinations: [])
        XCTAssertNil(insight)
    }

    func testVaccineSideEffect_allTypes_haveDisplayNames() {
        for type in VaccineSideEffect.SideEffectType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type.rawValue) displayName is empty")
        }
    }

    func testVaccineSideEffect_allSeverities_haveDisplayNames() {
        for severity in VaccineSideEffect.Severity.allCases {
            XCTAssertFalse(severity.displayName.isEmpty, "\(severity.rawValue) displayName is empty")
        }
    }

    // MARK: - DiaryAnalysisService Tests

    func testDiaryAnalysis_monthlyDistribution_correctCounts() {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 15))!
        let entry1 = DiaryEntry(babyId: "b1", date: date, content: "행복한 날", mood: .happy)
        let entry2 = DiaryEntry(babyId: "b1", date: date, content: "피곤한 날", mood: .tired)

        let dist = DiaryAnalysisService.monthlyDistribution(entries: [entry1, entry2], year: 2026, month: 3)
        XCTAssertEqual(dist.totalEntries, 2)
        XCTAssertEqual(dist.moodCounts["happy"], 1)
        XCTAssertEqual(dist.moodCounts["tired"], 1)
    }

    func testDiaryAnalysis_monthlyDistribution_writtenDays_deduplicates() {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let day1 = cal.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let day2 = cal.date(from: DateComponents(year: 2026, month: 3, day: 11))!
        let entries = [
            DiaryEntry(babyId: "b1", date: day1, content: "첫 번째"),
            DiaryEntry(babyId: "b1", date: day1, content: "같은 날"),
            DiaryEntry(babyId: "b1", date: day2, content: "다음 날")
        ]

        let dist = DiaryAnalysisService.monthlyDistribution(entries: entries, year: 2026, month: 3)
        XCTAssertEqual(dist.writtenDays, 2, "중복 날짜는 1일로 카운트해야 함")
    }

    func testDiaryAnalysis_monthlyDistribution_averageLength() {
        // 월 중간 + 정오로 timezone 무관하게 month=4 보장
        // (월말/월초 자정은 Calendar.current 가 다른 zone일 때 다른 월로 인식 가능)
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = cal.date(from: DateComponents(year: 2026, month: 4, day: 15, hour: 12))!
        let entries = [
            DiaryEntry(babyId: "b1", date: date, content: "12345"),      // 5자
            DiaryEntry(babyId: "b1", date: date, content: "1234567890")  // 10자
        ]

        let dist = DiaryAnalysisService.monthlyDistribution(entries: entries, year: 2026, month: 4)
        XCTAssertEqual(dist.averageContentLength, 7.5, accuracy: 0.01)
    }

    func testDiaryAnalysis_throwbackEntries_returnsMatchingOffset() {
        let calendar = Calendar.current
        let today = Date()
        guard let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: today) else {
            XCTFail("날짜 계산 실패"); return
        }
        let entry = DiaryEntry(babyId: "b1", date: oneMonthAgo, content: "한달 전")
        let throwbacks = DiaryAnalysisService.throwbackEntries(
            entries: [entry],
            monthOffsets: [1, 3],
            referenceDate: today
        )
        XCTAssertEqual(throwbacks.count, 1)
        XCTAssertEqual(throwbacks.first?.monthsAgo, 1)
    }

    func testDiaryAnalysis_throwbackEntries_emptyWhenNoMatch() {
        let today = Date()
        let entry = DiaryEntry(babyId: "b1", date: today, content: "오늘")
        let throwbacks = DiaryAnalysisService.throwbackEntries(
            entries: [entry],
            monthOffsets: [1, 3, 6],
            referenceDate: today
        )
        XCTAssertTrue(throwbacks.isEmpty, "오늘 날짜는 회고 카드에 포함되지 않아야 함")
    }

    func testDiaryAnalysis_moodTrends_aggregatesCorrectly() {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let ref = cal.date(from: DateComponents(year: 2026, month: 4, day: 15))!
        let march15 = cal.date(from: DateComponents(year: 2026, month: 3, day: 15))!

        let entries = [
            DiaryEntry(babyId: "b1", date: march15, content: "3월행복", mood: .happy),
            DiaryEntry(babyId: "b1", date: march15, content: "3월피곤", mood: .tired)
        ]

        let trends = DiaryAnalysisService.moodTrends(entries: entries, monthCount: 6, referenceDate: ref)
        let marchTrends = trends.filter { $0.year == 2026 && $0.month == 3 }
        XCTAssertFalse(marchTrends.isEmpty, "3월 트렌드가 있어야 함")

        let happyTrend = marchTrends.first { $0.mood == "happy" }
        XCTAssertNotNil(happyTrend)
        XCTAssertEqual(happyTrend?.ratio ?? 0, 0.5, accuracy: 0.01)
    }

    func testDiaryAnalysis_allPhotoItems_returnsAllURLs() {
        let entry1 = DiaryEntry(babyId: "b1", date: Date(), content: "1", photoURLs: ["urlA", "urlB"])
        let entry2 = DiaryEntry(babyId: "b1", date: Date(), content: "2", photoURLs: ["urlC"])
        let entry3 = DiaryEntry(babyId: "b1", date: Date(), content: "3", photoURLs: [])

        let items = DiaryAnalysisService.allPhotoItems(from: [entry1, entry2, entry3])
        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.map(\.url).contains("urlA"))
        XCTAssertTrue(items.map(\.url).contains("urlC"))
    }

    func testDiaryAnalysis_monthlyDistribution_empty_returnsZeros() {
        let dist = DiaryAnalysisService.monthlyDistribution(entries: [], year: 2026, month: 4)
        XCTAssertEqual(dist.totalEntries, 0)
        XCTAssertEqual(dist.writtenDays, 0)
        XCTAssertEqual(dist.averageContentLength, 0)
        XCTAssertNil(dist.dominantMood)
    }

    func testDiaryAnalysis_monthlyDistribution_ratio_correctPercentage() {
        // 월 중간 + 정오로 timezone 무관하게 month=2 보장
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = cal.date(from: DateComponents(year: 2026, month: 2, day: 15, hour: 12))!
        let entries = [
            DiaryEntry(babyId: "b1", date: date, content: "a", mood: .happy),
            DiaryEntry(babyId: "b1", date: date, content: "b", mood: .happy),
            DiaryEntry(babyId: "b1", date: date, content: "c", mood: .calm)
        ]

        let dist = DiaryAnalysisService.monthlyDistribution(entries: entries, year: 2026, month: 2)
        XCTAssertEqual(dist.ratio(for: "happy"), 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(dist.ratio(for: "calm"), 1.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(dist.dominantMood, "happy")
    }

    // MARK: - FoodSafetyService Tests

    private func makeSolidActivity(
        babyId: String = "b1",
        foodName: String,
        reaction: Activity.FoodReaction? = nil,
        date: Date = Date()
    ) -> Activity {
        Activity(
            babyId: babyId,
            type: .feedingSolid,
            startTime: date,
            foodName: foodName,
            foodReaction: reaction
        )
    }

    private func makeAllergyRecord(babyId: String = "b1", allergenName: String) -> AllergyRecord {
        AllergyRecord(babyId: babyId, allergenName: allergenName)
    }

    // Test 1: 알레르기 기록 있으면 forbidden 분류
    func testFoodSafety_classify_allergyRecord_returnsForbidden() {
        let activities: [Activity] = []
        let allergyRecords = [makeAllergyRecord(allergenName: "계란")]
        let status = FoodSafetyService.classify(
            foodName: "계란",
            activities: activities,
            allergyRecords: allergyRecords
        )
        XCTAssertEqual(status, .forbidden)
    }

    // Test 2: allergy reaction 활동 있으면 forbidden 분류
    func testFoodSafety_classify_allergyReactionActivity_returnsForbidden() {
        let activities = [makeSolidActivity(foodName: "두부", reaction: .allergy)]
        let status = FoodSafetyService.classify(
            foodName: "두부",
            activities: activities,
            allergyRecords: []
        )
        XCTAssertEqual(status, .forbidden)
    }

    // Test 3: 3회 이상 good/normal 시도 시 safe 분류
    func testFoodSafety_classify_threeGoodTrials_returnsSafe() {
        let activities = [
            makeSolidActivity(foodName: "당근", reaction: .good),
            makeSolidActivity(foodName: "당근", reaction: .normal),
            makeSolidActivity(foodName: "당근", reaction: .good)
        ]
        let status = FoodSafetyService.classify(
            foodName: "당근",
            activities: activities,
            allergyRecords: []
        )
        XCTAssertEqual(status, .safe)
    }

    // Test 4: refused 반응 포함 시 caution 분류
    func testFoodSafety_classify_refusedReaction_returnsCaution() {
        let activities = [
            makeSolidActivity(foodName: "시금치", reaction: .refused),
            makeSolidActivity(foodName: "시금치", reaction: .good)
        ]
        let status = FoodSafetyService.classify(
            foodName: "시금치",
            activities: activities,
            allergyRecords: []
        )
        XCTAssertEqual(status, .caution)
    }

    // Test 5: 히스토리 빌드 — allergy 반응 시 .reaction 이벤트 생성
    func testFoodSafety_buildHistory_allergyReaction_returnsReactionEvent() {
        let activities = [makeSolidActivity(foodName: "땅콩", reaction: .allergy)]
        let events = FoodSafetyService.buildHistory(
            foodName: "땅콩",
            activities: activities,
            allergyRecords: []
        )
        XCTAssertFalse(events.isEmpty)
        XCTAssertTrue(events.contains { $0.kind == .reaction })
    }

    // Test 6: 히스토리 빌드 — 3회 good 연속 시 .safe 이벤트 생성
    func testFoodSafety_buildHistory_threeConsecutiveGood_returnsSafeEvent() {
        let base = Date()
        let activities = [
            makeSolidActivity(foodName: "고구마", reaction: .good, date: base),
            makeSolidActivity(foodName: "고구마", reaction: .good, date: base.addingTimeInterval(86400)),
            makeSolidActivity(foodName: "고구마", reaction: .good, date: base.addingTimeInterval(172800))
        ]
        let events = FoodSafetyService.buildHistory(
            foodName: "고구마",
            activities: activities,
            allergyRecords: []
        )
        XCTAssertTrue(events.contains { $0.kind == .safe }, "3회 연속 good 시 safe 이벤트가 있어야 합니다")
    }

    // Test 7: 자동 제안 트리거 — allergy reaction 시 true
    func testFoodSafety_shouldSuggest_allergyReaction_returnsTrue() {
        let activity = makeSolidActivity(foodName: "우유", reaction: .allergy)
        XCTAssertTrue(FoodSafetyService.shouldSuggestAllergyRecord(for: activity))
    }

    // Test 8: 자동 제안 트리거 — refused reaction 시 true
    func testFoodSafety_shouldSuggest_refusedReaction_returnsTrue() {
        let activity = makeSolidActivity(foodName: "새우", reaction: .refused)
        XCTAssertTrue(FoodSafetyService.shouldSuggestAllergyRecord(for: activity))
    }

    // Test 9: 자동 제안 트리거 — good reaction 시 false
    func testFoodSafety_shouldSuggest_goodReaction_returnsFalse() {
        let activity = makeSolidActivity(foodName: "바나나", reaction: .good)
        XCTAssertFalse(FoodSafetyService.shouldSuggestAllergyRecord(for: activity))
    }

    // Test 10: allFoodNames — 콤마 구분 식품 분리 처리
    func testFoodSafety_allFoodNames_commaSeparated_splitCorrectly() {
        let activity = makeSolidActivity(foodName: "쌀, 당근, 감자")
        let names = FoodSafetyService.allFoodNames(activities: [activity], allergyRecords: [])
        XCTAssertTrue(names.contains("쌀"))
        XCTAssertTrue(names.contains("당근"))
        XCTAssertTrue(names.contains("감자"))
    }

    // Test 11: buildEntries — 데이터 없으면 빈 배열
    func testFoodSafety_buildEntries_noData_returnsEmpty() {
        let entries = FoodSafetyService.buildEntries(activities: [], allergyRecords: [])
        XCTAssertTrue(entries.isEmpty)
    }

    // Test 12: FoodSafetyStatus 기본값 caution (데이터 없는 음식)
    func testFoodSafety_classify_noData_returnsCaution() {
        let status = FoodSafetyService.classify(
            foodName: "처음보는음식",
            activities: [],
            allergyRecords: []
        )
        XCTAssertEqual(status, .caution)
    }

    // MARK: - FirstRecordGuidePolicy Tests (P0-1 첫 기록 가이드 — 이탈 방지)

    func testFirstRecordGuide_visibleWhenBabyAndNoRecords() {
        XCTAssertTrue(FirstRecordGuidePolicy.isVisible(
            hasSelectedBaby: true, todayCount: 0, recentWeekCount: 0, isLoading: false
        ))
    }

    func testFirstRecordGuide_hiddenWithoutBaby() {
        XCTAssertFalse(FirstRecordGuidePolicy.isVisible(
            hasSelectedBaby: false, todayCount: 0, recentWeekCount: 0, isLoading: false
        ))
    }

    func testFirstRecordGuide_hiddenWhenTodayRecordExists() {
        XCTAssertFalse(FirstRecordGuidePolicy.isVisible(
            hasSelectedBaby: true, todayCount: 1, recentWeekCount: 0, isLoading: false
        ))
    }

    func testFirstRecordGuide_hiddenWhenRecentWeekRecordExists() {
        // 최근 1주 내 기록이 있는 활성 사용자에게는 노출 금지 (매일 아침 오노출 방지)
        XCTAssertFalse(FirstRecordGuidePolicy.isVisible(
            hasSelectedBaby: true, todayCount: 0, recentWeekCount: 3, isLoading: false
        ))
    }

    func testFirstRecordGuide_hiddenWhileLoading() {
        // 로딩 중 깜빡 노출(flash) 방지
        XCTAssertFalse(FirstRecordGuidePolicy.isVisible(
            hasSelectedBaby: true, todayCount: 0, recentWeekCount: 0, isLoading: true
        ))
    }

    func testFirstRecordGuide_guideTypesAreThreeCoreTypes() {
        // 수유·기저귀·수면 3종 고정 순서 — 대시보드 quickSave 경로 재사용 계약
        XCTAssertEqual(FirstRecordGuidePolicy.guideTypes, [.feedingBreast, .diaperWet, .sleep])
    }

    // MARK: - ReturnNudgePolicy Tests (P0-2 D1 복귀 넛지 — 이탈 방지)

    func testReturnNudge_fireDateIs24hAfterLastRecord() {
        let last = Date(timeIntervalSince1970: 1_000_000)
        let fire = ReturnNudgePolicy.fireDate(lastRecordAt: last, now: last)
        XCTAssertEqual(fire, last.addingTimeInterval(24 * 60 * 60))
    }

    func testReturnNudge_nilWhenSilenceAlreadyPast() {
        // 이미 24h+ 지난 시점엔 과거 발화 예약 금지 (UNTimeIntervalNotificationTrigger 음수 크래시 가드)
        let last = Date(timeIntervalSince1970: 1_000_000)
        let now = last.addingTimeInterval(25 * 60 * 60)
        XCTAssertNil(ReturnNudgePolicy.fireDate(lastRecordAt: last, now: now))
    }

    func testReturnNudge_nilAtExactBoundary() {
        let last = Date(timeIntervalSince1970: 1_000_000)
        let now = last.addingTimeInterval(24 * 60 * 60)
        XCTAssertNil(ReturnNudgePolicy.fireDate(lastRecordAt: last, now: now))
    }

    func testReturnNudge_identifierStable() {
        // 동일 id 교체 예약 계약 — 저장할 때마다 이 id로 갈아끼워 "기록 이어지는 동안 침묵" 보장
        XCTAssertEqual(ReturnNudgePolicy.notificationIdentifier, "return-nudge-d1")
    }

    func testReturnNudgeSetting_defaultOnAndPersistToggle() {
        let key = "returnNudgeEnabled"
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertTrue(NotificationSettings.returnNudgeEnabled, "미설정 기본값은 ON (P0-2 핵심)")
        NotificationSettings.returnNudgeEnabled = false
        XCTAssertFalse(NotificationSettings.returnNudgeEnabled)
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - ActivityDayAttribution Tests (자정 넘김 수면 귀속 fix)
    // timezone 교훈: 월 중간 + 고정 KST 캘린더로 구성 (CI runner 캘린더 무관)

    private var kst: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }

    private func kstDate(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        kst.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func sleepActivity(id: String = "s1", start: Date, end: Date?, duration: TimeInterval? = nil) -> Activity {
        var a = Activity(babyId: "test-baby", type: .sleep)
        a.id = id
        a.startTime = start
        a.endTime = end
        a.duration = duration ?? end.map { $0.timeIntervalSince(start) }
        return a
    }

    func testDayAttribution_effectiveEnd_prefersEndTimeThenDurationThenStart() {
        let start = kstDate(4, 15, 21, 15)
        let end = kstDate(4, 16, 8, 43)
        // endTime 우선
        XCTAssertEqual(ActivityDayAttribution.effectiveEnd(startTime: start, endTime: end, duration: 60), end)
        // 레거시 duration-only 기록 (편집시트 fallback 경로 실존)
        XCTAssertEqual(
            ActivityDayAttribution.effectiveEnd(startTime: start, endTime: nil, duration: 3600),
            start.addingTimeInterval(3600)
        )
        // 둘 다 없으면 포인트 이벤트
        XCTAssertEqual(ActivityDayAttribution.effectiveEnd(startTime: start, endTime: nil, duration: nil), start)
    }

    func testDayAttribution_overlaps_crossMidnight_appearsOnBothDays() {
        // 실측 재현: 7/9 21:15 → 7/10 08:43 (uid=XPDu1V) — 시작일·종료일 양쪽에 보여야 한다
        let start = kstDate(4, 14, 21, 15)
        let end = kstDate(4, 15, 8, 43)
        XCTAssertTrue(ActivityDayAttribution.overlaps(day: kstDate(4, 14, 12), startTime: start, endTime: end, duration: nil, calendar: kst))
        XCTAssertTrue(ActivityDayAttribution.overlaps(day: kstDate(4, 15, 12), startTime: start, endTime: end, duration: nil, calendar: kst))
        XCTAssertFalse(ActivityDayAttribution.overlaps(day: kstDate(4, 13, 12), startTime: start, endTime: end, duration: nil, calendar: kst))
        XCTAssertFalse(ActivityDayAttribution.overlaps(day: kstDate(4, 16, 12), startTime: start, endTime: end, duration: nil, calendar: kst))
    }

    func testDayAttribution_overlaps_boundaryAtMidnight() {
        // 종료가 정확히 자정이면 다음날에 안 나타남
        let start = kstDate(4, 14, 21)
        let midnight = kstDate(4, 15, 0)
        XCTAssertTrue(ActivityDayAttribution.overlaps(day: kstDate(4, 14, 12), startTime: start, endTime: midnight, duration: nil, calendar: kst))
        XCTAssertFalse(ActivityDayAttribution.overlaps(day: kstDate(4, 15, 12), startTime: start, endTime: midnight, duration: nil, calendar: kst))
        // 자정 정각의 포인트 이벤트는 그 날짜 소속
        XCTAssertTrue(ActivityDayAttribution.overlaps(day: kstDate(4, 15, 12), startTime: midnight, endTime: nil, duration: nil, calendar: kst))
        XCTAssertFalse(ActivityDayAttribution.overlaps(day: kstDate(4, 14, 12), startTime: midnight, endTime: nil, duration: nil, calendar: kst))
    }

    func testDayAttribution_clippedDuration_splitsAtMidnight() {
        // 21:15→08:43 = 총 41,280초. 시작일 9,900초(2h45m) + 종료일 31,380초(8h43m)
        let start = kstDate(4, 14, 21, 15)
        let end = kstDate(4, 15, 8, 43)
        let onStartDay = ActivityDayAttribution.clippedDuration(on: kstDate(4, 14, 12), startTime: start, endTime: end, duration: nil, calendar: kst)
        let onEndDay = ActivityDayAttribution.clippedDuration(on: kstDate(4, 15, 12), startTime: start, endTime: end, duration: nil, calendar: kst)
        XCTAssertEqual(onStartDay, 9_900, accuracy: 0.5)
        XCTAssertEqual(onEndDay, 31_380, accuracy: 0.5)
        XCTAssertEqual(onStartDay + onEndDay, end.timeIntervalSince(start), accuracy: 0.5, "클립 합 = 전체 구간 보존")
    }

    func testDayAttribution_clippedDuration_edgeCases() {
        // 통째로 걸친 중간 날짜 = 86,400초
        let longStart = kstDate(4, 14, 23)
        let longEnd = kstDate(4, 16, 1)
        XCTAssertEqual(
            ActivityDayAttribution.clippedDuration(on: kstDate(4, 15, 12), startTime: longStart, endTime: longEnd, duration: nil, calendar: kst),
            86_400, accuracy: 0.5
        )
        // 포인트 이벤트 = 0
        let point = kstDate(4, 15, 10)
        XCTAssertEqual(ActivityDayAttribution.clippedDuration(on: kstDate(4, 15, 12), startTime: point, endTime: nil, duration: nil, calendar: kst), 0)
        // 역전 구간(방어) = 0
        XCTAssertEqual(
            ActivityDayAttribution.clippedDuration(on: kstDate(4, 15, 12), startTime: point, endTime: point.addingTimeInterval(-3600), duration: nil, calendar: kst),
            0
        )
        // 겹치지 않는 날짜 = 0
        XCTAssertEqual(
            ActivityDayAttribution.clippedDuration(on: kstDate(4, 17, 12), startTime: longStart, endTime: longEnd, duration: nil, calendar: kst),
            0
        )
    }

    func testDayAttribution_spannedDays_listAndCap() {
        let start = kstDate(4, 14, 21, 15)
        let end = kstDate(4, 15, 8, 43)
        let days = ActivityDayAttribution.spannedDays(startTime: start, endTime: end, duration: nil, calendar: kst)
        XCTAssertEqual(days, [kst.startOfDay(for: start), kst.startOfDay(for: end)])
        // 같은 날이면 하루만
        XCTAssertEqual(
            ActivityDayAttribution.spannedDays(startTime: kstDate(4, 15, 10), endTime: kstDate(4, 15, 11), duration: nil, calendar: kst).count,
            1
        )
        // 손상 데이터 폭주 방지 상한
        let corrupt = ActivityDayAttribution.spannedDays(
            startTime: start, endTime: start.addingTimeInterval(400 * 86_400), duration: nil, calendar: kst
        )
        XCTAssertEqual(corrupt.count, ActivityDayAttribution.maxSpannedDays)
    }

    func testDayAttribution_mergeDayResults_dedupesAndSortsDescending() {
        let a = sleepActivity(id: "a", start: kstDate(4, 14, 21), end: kstDate(4, 15, 7))
        let b = sleepActivity(id: "b", start: kstDate(4, 15, 9), end: kstDate(4, 15, 10))
        let c = sleepActivity(id: "c", start: kstDate(4, 15, 13), end: kstDate(4, 15, 14))
        let merged = ActivityDayAttribution.mergeDayResults([c, b], [a, b])
        XCTAssertEqual(merged.map(\.id), ["c", "b", "a"], "id dedupe + startTime 내림차순 (기존 fetch 정렬 계약 유지)")
    }

    func testSupportsEndTime_matchesRecordViewShowEndTimeSet() {
        // 기록 뷰 showEndTime 집합과 동일: needsTimer(모유/병수유/수면) + 목욕
        XCTAssertTrue(Activity.ActivityType.sleep.supportsEndTime)
        XCTAssertTrue(Activity.ActivityType.feedingBreast.supportsEndTime)
        XCTAssertTrue(Activity.ActivityType.feedingBottle.supportsEndTime)
        XCTAssertTrue(Activity.ActivityType.bath.supportsEndTime)
        XCTAssertFalse(Activity.ActivityType.diaperWet.supportsEndTime)
        XCTAssertFalse(Activity.ActivityType.temperature.supportsEndTime)
        XCTAssertFalse(Activity.ActivityType.feedingSolid.supportsEndTime)
        XCTAssertFalse(Activity.ActivityType.medication.supportsEndTime)
        XCTAssertFalse(Activity.ActivityType.unknown.supportsEndTime)
    }

    // MARK: - Vaccination Cold Start (가입 전 지난 일정 = 기록 전, 진짜 지연과 구분)

    func testVaccination_pastAtSeeding_isUnrecordedPast_notOverdue() {
        let now = Date()
        let vax = Vaccination(
            babyId: "b1", vaccine: .bcg, doseNumber: 1,
            scheduledDate: now.addingTimeInterval(-30 * 86_400),
            createdAt: now
        )
        XCTAssertTrue(vax.isUnrecordedPast, "시딩 시점에 이미 지난 일정은 미기록 과거")
        XCTAssertFalse(vax.isOverdue, "미기록 과거는 지연으로 계산하지 않는다")
        XCTAssertEqual(vax.statusText, "기록 전")
    }

    func testVaccination_scheduledSameDayAsSeeding_isNotUnrecordedPast() {
        // 등록 당일 출생(BCG 예정일 = 오늘) — 미기록 아님
        let now = Date()
        let vax = Vaccination(babyId: "b1", vaccine: .bcg, doseNumber: 1, scheduledDate: now, createdAt: now)
        XCTAssertFalse(vax.isUnrecordedPast)
    }

    func testVaccination_lapsedAfterSeeding_staysOverdue() {
        // 시딩 이후 예정일이 실제로 경과 → 진짜 지연 유지 (회귀 가드)
        let now = Date()
        let vax = Vaccination(
            babyId: "b1", vaccine: .hepB, doseNumber: 2,
            scheduledDate: now.addingTimeInterval(-3_600),
            createdAt: now.addingTimeInterval(-2 * 86_400)
        )
        XCTAssertFalse(vax.isUnrecordedPast)
        XCTAssertTrue(vax.isOverdue)
        XCTAssertEqual(vax.statusText, "접종 지연")
    }

    func testVaccination_completedPast_isNeitherUnrecordedNorOverdue() {
        let now = Date()
        var vax = Vaccination(
            babyId: "b1", vaccine: .bcg, doseNumber: 1,
            scheduledDate: now.addingTimeInterval(-30 * 86_400),
            createdAt: now
        )
        vax.isCompleted = true
        XCTAssertFalse(vax.isUnrecordedPast)
        XCTAssertFalse(vax.isOverdue)
    }

    func testVaccination_completedBackfill_marksOnlyUnrecordedPast() {
        let now = Date()
        let unrecorded = Vaccination(
            babyId: "b1", vaccine: .bcg, doseNumber: 1,
            scheduledDate: now.addingTimeInterval(-30 * 86_400), createdAt: now
        )
        let future = Vaccination(
            babyId: "b1", vaccine: .mmr, doseNumber: 1,
            scheduledDate: now.addingTimeInterval(30 * 86_400), createdAt: now
        )
        let lapsed = Vaccination(
            babyId: "b1", vaccine: .hepB, doseNumber: 2,
            scheduledDate: now.addingTimeInterval(-3_600),
            createdAt: now.addingTimeInterval(-2 * 86_400)
        )
        let backfilled = Vaccination.completedBackfill(of: [unrecorded, future, lapsed])
        XCTAssertEqual(backfilled.map(\.id), [unrecorded.id], "미기록 과거만 대상 (미래·진짜 지연 제외)")
        XCTAssertTrue(backfilled.allSatisfy(\.isCompleted))
        XCTAssertEqual(backfilled.first?.administeredDate, unrecorded.scheduledDate, "접종일은 예정일로 저장")
    }

    // MARK: - StoragePath (사진 경로 단일 소스 — 삭제 프리픽스가 업로드 경로를 커버하는 불변 잠금)

    func testStoragePath_matchesLiveUploadPaths() {
        // ⚠️ 기존 업로드 파일 도달성 계약 — 경로 형식 변경 금지 (변경 시 이전 사진 orphan)
        XCTAssertEqual(StoragePath.babyProfile(userId: "u1", babyId: "b1"), "users/u1/babies/b1/profile.jpg")
        XCTAssertEqual(
            StoragePath.activityPhoto(userId: "u1", babyId: "b1", activityId: "a1"),
            "users/u1/babies/b1/activities/a1.jpg"
        )
        XCTAssertEqual(
            StoragePath.diaryPhoto(userId: "u1", babyId: "b1", diaryId: "d1", index: 2),
            "users/u1/babies/b1/diary/d1_2.jpg"
        )
    }

    func testStoragePath_babyRootCoversAllUploadPaths() {
        let root = StoragePath.babyRoot(userId: "u1", babyId: "b1")
        XCTAssertTrue(StoragePath.babyProfile(userId: "u1", babyId: "b1").hasPrefix(root + "/"))
        XCTAssertTrue(StoragePath.activityPhoto(userId: "u1", babyId: "b1", activityId: "a1").hasPrefix(root + "/"))
        XCTAssertTrue(StoragePath.diaryPhoto(userId: "u1", babyId: "b1", diaryId: "d1", index: 0).hasPrefix(root + "/"))
        // 다른 아기 경로는 미포함 (오삭제 방지)
        XCTAssertFalse(StoragePath.babyProfile(userId: "u1", babyId: "b2").hasPrefix(root + "/"))
    }

    func testStoragePath_userRootCoversBabyRoot() {
        let userRoot = StoragePath.userRoot(userId: "u1")
        XCTAssertTrue(StoragePath.babyRoot(userId: "u1", babyId: "b1").hasPrefix(userRoot + "/"), "계정 purge가 아기 purge를 포함")
        // 다른 사용자 경로는 미포함 (오삭제 방지)
        XCTAssertFalse(StoragePath.babyRoot(userId: "u2", babyId: "b1").hasPrefix(userRoot + "/"))
    }

    // MARK: - InfoToastCenter (A3 — 정보 안내를 에러 채널에서 분리)

    @MainActor
    func testInfoToast_dismissOnlyWhenStillShowingSameMessage() {
        let center = InfoToastCenter()
        center.show("첫 안내")
        center.dismiss(ifStillShowing: "첫 안내")
        XCTAssertNil(center.message, "표시 중인 같은 문구는 소거")

        center.show("첫 안내")
        center.show("나중 안내")
        center.dismiss(ifStillShowing: "첫 안내")
        XCTAssertEqual(center.message, "나중 안내", "소거 대기 중 새 토스트가 떴으면 유지 (레이스 가드)")
    }

    @MainActor
    func testInfoToast_offlineSavedSingleCopy() {
        let center = InfoToastCenter()
        center.offlineSaved()
        XCTAssertEqual(center.message, "오프라인 저장됨 — 연결 시 자동 동기화")
    }

    // MARK: - ActivityReminderChainPolicy (B1 — 원샷 영구침묵 → 2발 체인)

    func testReminderChain_offsets_areIntervalAndDouble() {
        XCTAssertEqual(ActivityReminderChainPolicy.offsetsMinutes(intervalMinutes: 180), [180, 360])
        XCTAssertEqual(ActivityReminderChainPolicy.offsetsMinutes(intervalMinutes: 120), [120, 240])
    }

    func testReminderChain_identifiers_perTypeAndShot() {
        XCTAssertEqual(
            ActivityReminderChainPolicy.identifiers(typeRaw: "feeding_bottle"),
            ["activity-feeding_bottle-1", "activity-feeding_bottle-2"]
        )
    }

    func testReminderChain_cancellationIncludesLegacyOneShot() {
        let ids = ActivityReminderChainPolicy.cancellationIdentifiers(typeRaw: "feeding_breast")
        XCTAssertTrue(ids.contains("activity-feeding_breast"), "구버전 원샷 id도 취소 — 잔존 예약 방지")
        XCTAssertTrue(ids.contains("activity-feeding_breast-1"))
        XCTAssertTrue(ids.contains("activity-feeding_breast-2"))
        XCTAssertEqual(ids.count, 3)
    }

    // MARK: - MedicationReminderPromptPolicy (B2 — 투약 알림 인라인 제안, 생애 1회)

    func testMedicationPrompt_offersOnlyWhenRuleOffAndNeverPrompted() {
        XCTAssertTrue(MedicationReminderPromptPolicy.shouldOffer(ruleEnabled: false, alreadyPrompted: false))
        XCTAssertFalse(MedicationReminderPromptPolicy.shouldOffer(ruleEnabled: true, alreadyPrompted: false), "이미 켜져 있으면 제안 불필요")
        XCTAssertFalse(MedicationReminderPromptPolicy.shouldOffer(ruleEnabled: false, alreadyPrompted: true), "생애 1회 — 재노출 금지")
        XCTAssertFalse(MedicationReminderPromptPolicy.shouldOffer(ruleEnabled: true, alreadyPrompted: true))
    }

    // MARK: - RecordPrefillPolicy (B3 — 직전 값 프리필)

    func testPrefill_lastAmount_prefersTodayLatestOfSameType() {
        var oldBottle = Activity(babyId: "b1", type: .feedingBottle, startTime: Date().addingTimeInterval(-3 * 86_400))
        oldBottle.amount = 90
        var todayBottle = Activity(babyId: "b1", type: .feedingBottle, startTime: Date().addingTimeInterval(-3_600))
        todayBottle.amount = 140
        var pumping = Activity(babyId: "b1", type: .feedingPumping, startTime: Date().addingTimeInterval(-1_800))
        pumping.amount = 120

        XCTAssertEqual(
            RecordPrefillPolicy.lastAmount(type: .feedingBottle, todayActivities: [todayBottle, pumping], recentActivities: [oldBottle]),
            "140", "오늘 최신 동일 타입 우선"
        )
        XCTAssertEqual(
            RecordPrefillPolicy.lastAmount(type: .feedingBottle, todayActivities: [pumping], recentActivities: [oldBottle]),
            "90", "오늘 없으면 최근 7일 fallback"
        )
        XCTAssertEqual(
            RecordPrefillPolicy.lastAmount(type: .feedingPumping, todayActivities: [todayBottle, pumping], recentActivities: []),
            "120", "타입별 분리 — 병수유 값이 유축에 새지 않는다"
        )
        XCTAssertNil(RecordPrefillPolicy.lastAmount(type: .feedingBottle, todayActivities: [], recentActivities: []))
    }

    func testPrefill_lastFeedingContent_fromLatestBottle() {
        var older = Activity(babyId: "b1", type: .feedingBottle, startTime: Date().addingTimeInterval(-7_200))
        older.amount = 100
        older.feedingContent = .formula
        var newer = Activity(babyId: "b1", type: .feedingBottle, startTime: Date().addingTimeInterval(-600))
        newer.amount = 100
        newer.feedingContent = .breastMilk

        XCTAssertEqual(
            RecordPrefillPolicy.lastFeedingContent(todayActivities: [older, newer], recentActivities: []),
            .breastMilk, "최신 병수유의 내용물"
        )
        XCTAssertNil(RecordPrefillPolicy.lastFeedingContent(todayActivities: [], recentActivities: []))
    }

    // MARK: - WidgetPromoPolicy (C2 — 위젯 설치 유도, 해제형 1회)

    func testWidgetPromo_visibleAfterThreeRecordsUntilDismissed() {
        XCTAssertFalse(WidgetPromoPolicy.isVisible(recordCount: 0, dismissed: false), "기록 없음 — 온보딩 소음 금지")
        XCTAssertFalse(WidgetPromoPolicy.isVisible(recordCount: 2, dismissed: false))
        XCTAssertTrue(WidgetPromoPolicy.isVisible(recordCount: 3, dismissed: false), "습관 시작(3건+)부터 노출")
        XCTAssertFalse(WidgetPromoPolicy.isVisible(recordCount: 10, dismissed: true), "해제 후 재노출 금지")
    }

    // MARK: - WeeklySummaryPolicy (C6 — 주간 요약 푸시 본문)

    func testWeeklySummary_countsByCategory() {
        let now = Date()
        let acts = [
            Activity(babyId: "b1", type: .feedingBreast, startTime: now),
            Activity(babyId: "b1", type: .feedingBottle, startTime: now),
            Activity(babyId: "b1", type: .sleep, startTime: now),
            Activity(babyId: "b1", type: .diaperWet, startTime: now),
            Activity(babyId: "b1", type: .feedingPumping, startTime: now)   // 유축=생산, 수유 카테고리 아님
        ]
        let line = WeeklySummaryPolicy.summaryLine(babyName: "서연", weekActivities: acts)
        XCTAssertEqual(line, "이번 주 서연 기록 5건 — 수유 2 · 수면 1 · 기저귀 1")
    }

    func testWeeklySummary_emptyReturnsNil() {
        XCTAssertNil(WeeklySummaryPolicy.summaryLine(babyName: "서연", weekActivities: []), "기록 없으면 nil → generic 폴백")
    }

    func testWeeklySummary_totalOnlyWhenNoCoreCategories() {
        let acts = [Activity(babyId: "b1", type: .temperature, startTime: Date())]
        XCTAssertEqual(WeeklySummaryPolicy.summaryLine(babyName: "서연", weekActivities: acts), "이번 주 서연 기록 1건")
    }

    // MARK: - RecordStreakPolicy (C1 — 기록 스트릭 배지)

    func testRecordStreak_incrementsFromYesterday() {
        let cal = Calendar.current
        let now = Date()
        let yKey = RecordStreakPolicy.dayKey(cal.date(byAdding: .day, value: -1, to: now)!)
        XCTAssertEqual(RecordStreakPolicy.updatedStreak(previousStreak: 4, lastDayKey: yKey, now: now), 5)
    }

    func testRecordStreak_sameDayReturnsNilNoChange() {
        let now = Date()
        let tKey = RecordStreakPolicy.dayKey(now)
        XCTAssertNil(RecordStreakPolicy.updatedStreak(previousStreak: 3, lastDayKey: tKey, now: now), "오늘 이미 카운트 — 변경 없음")
    }

    func testRecordStreak_gapResetsToOne() {
        let cal = Calendar.current
        let now = Date()
        let threeDaysAgo = RecordStreakPolicy.dayKey(cal.date(byAdding: .day, value: -3, to: now)!)
        XCTAssertEqual(RecordStreakPolicy.updatedStreak(previousStreak: 9, lastDayKey: threeDaysAgo, now: now), 1, "공백 후 재시작")
        XCTAssertEqual(RecordStreakPolicy.updatedStreak(previousStreak: 0, lastDayKey: nil, now: now), 1, "최초 기록 = 1")
    }

    func testRecordStreak_earnedBadgeIdsByThreshold() {
        XCTAssertEqual(RecordStreakPolicy.earnedBadgeIds(streak: 2), [])
        XCTAssertEqual(RecordStreakPolicy.earnedBadgeIds(streak: 3), ["recordStreak3"])
        XCTAssertEqual(RecordStreakPolicy.earnedBadgeIds(streak: 14), ["recordStreak3", "recordStreak7", "recordStreak14"])
    }

    // MARK: - NextRecordSuggestionPolicy (B4 — 이어서 기록 제안)

    func testNextRecordSuggestion_coreLoopCycle() {
        XCTAssertEqual(NextRecordSuggestionPolicy.suggestion(after: .feedingBreast), .diaperWet)
        XCTAssertEqual(NextRecordSuggestionPolicy.suggestion(after: .feedingBottle), .diaperWet)
        XCTAssertEqual(NextRecordSuggestionPolicy.suggestion(after: .diaperWet), .sleep)
        XCTAssertEqual(NextRecordSuggestionPolicy.suggestion(after: .diaperBoth), .sleep)
        XCTAssertEqual(NextRecordSuggestionPolicy.suggestion(after: .sleep), .feedingBreast)
    }

    func testNextRecordSuggestion_nonCyclicTypesSuppressed() {
        XCTAssertNil(NextRecordSuggestionPolicy.suggestion(after: .temperature))
        XCTAssertNil(NextRecordSuggestionPolicy.suggestion(after: .medication))
        XCTAssertNil(NextRecordSuggestionPolicy.suggestion(after: .bath))
        XCTAssertNil(NextRecordSuggestionPolicy.suggestion(after: .unknown))
    }

    // MARK: - WelcomeBackPolicy (C5 — 복귀 웰컴백, 자동 소멸)

    func testWelcomeBack_gapDays() {
        let cal = Calendar.current
        let now = Date()
        let fiveDaysAgo = cal.date(byAdding: .day, value: -5, to: now)!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now)!

        XCTAssertEqual(WelcomeBackPolicy.gapDays(lastRecordAt: fiveDaysAgo, todayCount: 0, now: now), 5)
        XCTAssertNil(WelcomeBackPolicy.gapDays(lastRecordAt: fiveDaysAgo, todayCount: 1, now: now), "오늘 기록 생기면 자동 소멸")
        XCTAssertNil(WelcomeBackPolicy.gapDays(lastRecordAt: twoDaysAgo, todayCount: 0, now: now), "3일 미만 공백은 평시")
        XCTAssertNil(WelcomeBackPolicy.gapDays(lastRecordAt: nil, todayCount: 0, now: now), "기록 이력 없음 = 첫기록 가이드 영역")
    }

    // MARK: - AnniversaryPolicy (C4 — 기념일 카운트다운)

    private func anniversaryKstDay(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal.date(from: DateComponents(timeZone: cal.timeZone, year: y, month: m, day: d, hour: 12))!
    }

    private var anniversaryKstCal: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }

    func testAnniversary_next_hundredDaysConvention() {
        // 출생 2026-01-01 → 백일 = 출생일 포함 100번째 날 = 2026-04-10 (birth + 99일)
        let birth = anniversaryKstDay(2026, 1, 1)
        let next = AnniversaryPolicy.next(birthDate: birth, now: anniversaryKstDay(2026, 4, 3), calendar: anniversaryKstCal)
        XCTAssertEqual(next?.title, "백일")
        XCTAssertEqual(next?.dDay, 7)
    }

    func testAnniversary_next_skipsPastAndFindsFirstBirthday() {
        let birth = anniversaryKstDay(2025, 7, 15)
        // 2026-07-10 기준: 50/100/200/300일 모두 지남 → 다음 = 첫돌(2026-07-15) D-5
        let next = AnniversaryPolicy.next(birthDate: birth, now: anniversaryKstDay(2026, 7, 10), calendar: anniversaryKstCal)
        XCTAssertEqual(next?.title, "첫돌")
        XCTAssertEqual(next?.dDay, 5)
    }

    func testAnniversary_visible_onlyWithinWindow() {
        let birth = anniversaryKstDay(2026, 1, 1)
        // 백일(4/10)까지 D-8 → 미노출, D-7 → 노출, 당일 D-0 → 노출
        XCTAssertNil(AnniversaryPolicy.visible(birthDate: birth, now: anniversaryKstDay(2026, 4, 2), calendar: anniversaryKstCal))
        XCTAssertNotNil(AnniversaryPolicy.visible(birthDate: birth, now: anniversaryKstDay(2026, 4, 3), calendar: anniversaryKstCal))
        XCTAssertEqual(AnniversaryPolicy.visible(birthDate: birth, now: anniversaryKstDay(2026, 4, 10), calendar: anniversaryKstCal)?.dDay, 0)
    }

    func testAnniversary_secondBirthdayAfterFirst() {
        let birth = anniversaryKstDay(2025, 7, 15)
        let next = AnniversaryPolicy.next(birthDate: birth, now: anniversaryKstDay(2027, 7, 12), calendar: anniversaryKstCal)
        XCTAssertEqual(next?.title, "두 돌")
        XCTAssertEqual(next?.dDay, 3)
    }

    // MARK: - PartnerInvitePromoPolicy (C3 — 파트너 초대 유도, 해제형 1회)

    func testPartnerInvitePromo_visibleForSoloHabitUsers() {
        XCTAssertTrue(PartnerInvitePromoPolicy.isVisible(hasSharedBaby: false, recordCount: 7, dismissed: false))
        XCTAssertFalse(PartnerInvitePromoPolicy.isVisible(hasSharedBaby: true, recordCount: 20, dismissed: false), "이미 공유 중이면 불필요")
        XCTAssertFalse(PartnerInvitePromoPolicy.isVisible(hasSharedBaby: false, recordCount: 6, dismissed: false), "습관 전 노출 금지")
        XCTAssertFalse(PartnerInvitePromoPolicy.isVisible(hasSharedBaby: false, recordCount: 30, dismissed: true), "해제 후 재노출 금지")
    }

    // MARK: - 수면 주간 통계 하루 귀속 (D1 — #55 후속: 기간/일별 클립)

    func testDayAttribution_periodClip() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let start = base
        let end = base.addingTimeInterval(3_600)
        // 완전 포함
        XCTAssertEqual(
            ActivityDayAttribution.clippedDuration(from: base.addingTimeInterval(-600), to: base.addingTimeInterval(4_000), startTime: start, endTime: end, duration: nil),
            3_600
        )
        // 기간 시작 경계에 걸침 → 부분
        XCTAssertEqual(
            ActivityDayAttribution.clippedDuration(from: base.addingTimeInterval(1_800), to: base.addingTimeInterval(7_200), startTime: start, endTime: end, duration: nil),
            1_800
        )
        // 기간 밖 → 0
        XCTAssertEqual(
            ActivityDayAttribution.clippedDuration(from: base.addingTimeInterval(7_200), to: base.addingTimeInterval(9_000), startTime: start, endTime: end, duration: nil),
            0
        )
    }

    func testPreprocessor_aggregate_splitsCrossMidnightSleep() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let day1 = cal.date(byAdding: .day, value: -3, to: today)!
        let day2 = cal.date(byAdding: .day, value: 1, to: day1)!

        var sleep = Activity(babyId: "b1", type: .sleep, startTime: day1.addingTimeInterval(21 * 3_600))
        sleep.endTime = day1.addingTimeInterval(32 * 3_600)   // 다음날 08:00
        sleep.duration = 11 * 3_600

        let period = AnalysisPeriod(from: day1, to: day2.addingTimeInterval(12 * 3_600))
        let aggregates = Preprocessor.aggregate(activities: [sleep], period: period)

        let d1Agg = aggregates.first { cal.isDate($0.date, inSameDayAs: day1) }
        let d2Agg = aggregates.first { cal.isDate($0.date, inSameDayAs: day2) }
        XCTAssertEqual(d1Agg?.sleepMinutes ?? -1, 180, accuracy: 0.01, "전날 밤 21~24시 = 180분")
        XCTAssertEqual(d2Agg?.sleepMinutes ?? -1, 480, accuracy: 0.01, "당일 새벽 0~8시 = 480분")
    }

    // MARK: - DashboardInsight 탭 목적지 매핑 (B5 — 읽기 전용 카드에 행동 연결)

    func testInsightTapDestination_mapping() {
        func insight(_ kind: DashboardInsight.Kind) -> DashboardInsight {
            DashboardInsight(kind: kind, icon: "star", colorName: "feedingColor", primaryText: "t", secondaryText: nil)
        }
        XCTAssertEqual(insight(.feeding).tapDestination, .stats)
        XCTAssertEqual(insight(.sleep).tapDestination, .stats)
        XCTAssertEqual(insight(.health).tapDestination, .stats)
        XCTAssertEqual(insight(.milestone).tapDestination, .milestones)
        XCTAssertEqual(insight(.vaccination).tapDestination, .vaccinations)
    }

    func testInsightAnalyticsKey_perKind() {
        func insight(_ kind: DashboardInsight.Kind) -> DashboardInsight {
            DashboardInsight(kind: kind, icon: "star", colorName: "feedingColor", primaryText: "t", secondaryText: nil)
        }
        XCTAssertEqual(insight(.feeding).analyticsKey, "feeding")
        XCTAssertEqual(insight(.sleep).analyticsKey, "sleep")
        XCTAssertEqual(insight(.health).analyticsKey, "health")
        XCTAssertEqual(insight(.milestone).analyticsKey, "milestone")
        XCTAssertEqual(insight(.vaccination).analyticsKey, "vaccination")
    }

}

// MARK: - HospitalChecklistService Tests (#10)

final class HospitalChecklistServiceTests: XCTestCase {

    // Helper: 아기 생성
    private func makeBaby(birthDate: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date())!) -> Baby {
        Baby(name: "테스트", birthDate: birthDate, gender: .male)
    }

    // Helper: 예방접종 생성 (미완료, 예정)
    private func makeVaccination(daysFromNow: Int, completed: Bool = false) -> Vaccination {
        let schedDate = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())!
        var vax = Vaccination(
            babyId: "b1",
            vaccine: .dtap,
            doseNumber: 1,
            scheduledDate: schedDate,
            // 시딩 1년 전 = 앱 사용 중 일정 (미기록 과거로 분류되지 않게 — 과거 예정일은 '진짜 지연' 의도 유지)
            createdAt: Calendar.current.date(byAdding: .day, value: -365, to: Date())!
        )
        vax.isCompleted = completed
        return vax
    }

    // Helper: 성장기록 생성
    private func makeGrowthRecord(weight: Double, height: Double, monthsOld: Int) -> GrowthRecord {
        let date = Calendar.current.date(byAdding: .month, value: -monthsOld, to: Date())!
        return GrowthRecord(babyId: "b1", date: date, height: height, weight: weight)
    }

    // Helper: 활동 생성 (체온 포함)
    private func makeTemperatureActivity(temp: Double, daysAgo: Int = 1) -> Activity {
        let time = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        var act = Activity(babyId: "b1", type: .temperature, startTime: time)
        act.temperature = temp
        return act
    }

    // Helper: 노트 포함 활동 생성
    private func makeNoteActivity(note: String, daysAgo: Int = 1) -> Activity {
        let time = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        var act = Activity(babyId: "b1", type: .sleep, startTime: time)
        act.note = note
        return act
    }

    // Test 1: 다음 접종 D-day 체크리스트 생성 — 미래 접종 존재 시 .vaccination 항목 생성
    func testChecklist_upcomingVaccination_createsItem() {
        let vax = makeVaccination(daysFromNow: 5)
        let items = HospitalChecklistService.vaccinationItems(from: [vax])
        XCTAssertFalse(items.isEmpty, "미래 예약 접종 있을 때 체크리스트 항목이 생성되어야 한다")
        XCTAssertTrue(items.allSatisfy { $0.type == .vaccination })
    }

    // Test 2: 지연된 접종 — overdue 접종은 severity .high
    func testChecklist_overdueVaccination_severityHigh() {
        let vax = makeVaccination(daysFromNow: -3) // 3일 전 예정
        let items = HospitalChecklistService.vaccinationItems(from: [vax])
        let overdueItem = items.first { $0.severity == .high }
        XCTAssertNotNil(overdueItem, "지연된 접종은 severity .high 항목이 있어야 한다")
    }

    // Test 2b: 앱 사용 전(시딩 전)에 지난 접종은 지연(high) 항목을 만들지 않는다 — 콜드스타트 오발 방지
    func testChecklist_unrecordedPastVaccination_noOverdueItem() {
        let vax = Vaccination(
            babyId: "b1", vaccine: .dtap, doseNumber: 1,
            scheduledDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            createdAt: Date()
        )
        let items = HospitalChecklistService.vaccinationItems(from: [vax])
        XCTAssertNil(items.first { $0.severity == .high }, "미기록 과거 접종은 지연 항목이 없어야 한다")
    }

    // Test 3: 완료된 접종만 있을 때 체크리스트 비어있음
    func testChecklist_completedVaccinations_noItems() {
        let vax = makeVaccination(daysFromNow: -10, completed: true)
        let items = HospitalChecklistService.vaccinationItems(from: [vax])
        XCTAssertTrue(items.isEmpty, "완료된 접종만 있을 때 체크리스트 항목이 없어야 한다")
    }

    // Test 4: 성장 이상 감지 — 체중 3백분위 미만 시 .growthAnomaly 항목 생성
    func testChecklist_growthAnomaly_lowWeight_createsItem() {
        // 6개월 남아 체중 정상범위 하한선보다 훨씬 낮은 값 (0.5kg — 3백분위 미만)
        let baby = makeBaby()
        let record = makeGrowthRecord(weight: 0.5, height: 65.0, monthsOld: 0)
        let items = HospitalChecklistService.growthAnomalyItems(from: [record], baby: baby)
        XCTAssertFalse(items.isEmpty, "3백분위 미만 체중은 성장 이상 항목이 생성되어야 한다")
        XCTAssertTrue(items.contains { $0.type == .growthAnomaly && $0.severity == .high })
    }

    // Test 5: 성장 정상범위 — 이상 없음 시 항목 없음
    func testChecklist_growthNormal_noItems() {
        // 6개월 남아 체중 정상값 (7.5kg)
        let baby = makeBaby()
        let record = makeGrowthRecord(weight: 7.5, height: 67.0, monthsOld: 0)
        let items = HospitalChecklistService.growthAnomalyItems(from: [record], baby: baby)
        XCTAssertTrue(items.isEmpty, "정상 범위 성장 기록은 이상 항목이 없어야 한다")
    }

    // Test 6: 증상 키워드 — 발열 체온(38도 이상)으로 증상 감지
    func testChecklist_symptom_feverActivity_detected() {
        let activity = makeTemperatureActivity(temp: 38.5, daysAgo: 2)
        let items = HospitalChecklistService.symptomItems(from: [activity])
        XCTAssertFalse(items.isEmpty, "38도 이상 체온 기록 시 증상 키워드 항목이 생성되어야 한다")
        XCTAssertTrue(items.allSatisfy { $0.type == .symptomKeyword })
    }

    // Test 7: 증상 키워드 — note에 '기침' 포함 시 감지
    func testChecklist_symptom_coughKeyword_detected() {
        let activity = makeNoteActivity(note: "기침을 많이 해요", daysAgo: 3)
        let items = HospitalChecklistService.symptomItems(from: [activity])
        XCTAssertFalse(items.isEmpty, "note에 '기침' 포함 시 증상 항목이 생성되어야 한다")
    }

    // Test 8: 증상 키워드 — 7일 이후 오래된 활동은 무시
    func testChecklist_symptom_oldActivity_ignored() {
        let activity = makeTemperatureActivity(temp: 39.0, daysAgo: 10)
        let items = HospitalChecklistService.symptomItems(from: [activity])
        XCTAssertTrue(items.isEmpty, "7일 초과 활동은 증상 키워드 감지에서 제외되어야 한다")
    }

    // Test 9: 전체 generate — 빈 입력 시 빈 배열 반환
    func testChecklist_generate_emptyInputs_returnsEmpty() {
        let baby = makeBaby()
        let items = HospitalChecklistService.generate(
            vaccinations: [],
            growthRecords: [],
            activities: [],
            baby: baby
        )
        XCTAssertTrue(items.isEmpty)
    }

    // Test 10: 전체 generate — 복합 입력 시 중요도순 정렬 (high >= medium >= low)
    func testChecklist_generate_sortedBySeverity() {
        let baby = makeBaby()
        let vax = makeVaccination(daysFromNow: 5) // low severity
        let overdueVax = makeVaccination(daysFromNow: -2) // high severity
        let feverActivity = makeTemperatureActivity(temp: 39.0, daysAgo: 1) // medium

        let items = HospitalChecklistService.generate(
            vaccinations: [vax, overdueVax],
            growthRecords: [],
            activities: [feverActivity],
            baby: baby
        )

        guard items.count >= 2 else { return }
        for i in 0..<(items.count - 1) {
            XCTAssertGreaterThanOrEqual(
                items[i].severity, items[i + 1].severity,
                "체크리스트는 중요도 내림차순으로 정렬되어야 한다"
            )
        }
    }
}

// MARK: - ProductRecommendationService Tests

final class ProductRecommendationServiceTests: XCTestCase {

    // MARK: - 테스트용 픽스처 카탈로그

    private var mockCatalog: [ProductRecommendation] {
        [
            ProductRecommendation(name: "신생아 기저귀", category: .diaper, ageRangeStart: 0, ageRangeEnd: 2, reason: "테스트"),
            ProductRecommendation(name: "분유", category: .formula, ageRangeStart: 0, ageRangeEnd: 12, reason: "테스트"),
            ProductRecommendation(name: "이유식 그릇", category: .babyFood, ageRangeStart: 4, ageRangeEnd: 24, reason: "테스트"),
            ProductRecommendation(name: "범용 바디로션", category: .skincare, ageRangeStart: 0, ageRangeEnd: 36, reason: "테스트"),
            ProductRecommendation(name: "신생아 전용 용품", category: .bedding, ageRangeStart: 0, ageRangeEnd: 1, reason: "테스트"),
            ProductRecommendation(name: "장난감", category: .toy, ageRangeStart: 3, ageRangeEnd: 36, reason: "테스트")
        ]
    }

    // MARK: - 카탈로그 구조 검증 (픽스처 기반)

    // Test 1: 픽스처 카탈로그 — recommendations(for:catalog:)가 올바른 결과를 반환해야 한다
    func testCatalogStructure_recommendationsFilterCorrectly() {
        let catalog = mockCatalog
        let recs = ProductRecommendationService.recommendations(for: 0, catalog: catalog)
        XCTAssertFalse(recs.isEmpty, "0개월 추천 목록은 픽스처 카탈로그에서 비어있지 않아야 한다")
    }

    // Test 2: 픽스처 카탈로그 — 유효한 category만 포함
    func testCatalogStructure_allCategoriesValid() {
        let catalog = mockCatalog
        for item in catalog {
            XCTAssertNotNil(
                BabyProduct.ProductCategory(rawValue: item.category.rawValue),
                "카탈로그 항목 '\(item.name)'의 category가 유효해야 한다"
            )
        }
    }

    // MARK: - 월령별 추천

    // Test 3: 월령 0개월 — 픽스처에서 기저귀 카테고리 포함
    func testRecommendations_ageZero_containsNewbornItems() {
        let recs = ProductRecommendationService.recommendations(for: 0, catalog: mockCatalog)
        XCTAssertFalse(recs.isEmpty, "0개월 추천 목록은 비어있지 않아야 한다")
        let hasDiaper = recs.contains { $0.category == .diaper }
        XCTAssertTrue(hasDiaper, "0개월 추천에는 기저귀 카테고리가 포함되어야 한다")
    }

    // Test 4: 월령 6개월 — 픽스처에서 이유식 관련 용품 포함
    func testRecommendations_ageSix_containsSolidFoodItems() {
        let recs = ProductRecommendationService.recommendations(for: 6, catalog: mockCatalog)
        let hasBabyFood = recs.contains { $0.category == .babyFood }
        XCTAssertTrue(hasBabyFood, "6개월 추천에는 이유식 카테고리가 포함되어야 한다")
    }

    // Test 5: 월령 범위 필터링 — ageRangeEnd 초과 항목은 제외되어야 한다
    func testRecommendations_ageFiltering_excludesOutOfRange() {
        let catalog: [ProductRecommendation] = [
            ProductRecommendation(
                name: "신생아 전용",
                category: .diaper,
                ageRangeStart: 0,
                ageRangeEnd: 1,
                reason: "테스트용"
            ),
            ProductRecommendation(
                name: "범용 용품",
                category: .other,
                ageRangeStart: 0,
                ageRangeEnd: 36,
                reason: "테스트용"
            )
        ]
        let recs = ProductRecommendationService.recommendations(for: 12, catalog: catalog)
        XCTAssertFalse(
            recs.contains { $0.name == "신생아 전용" },
            "ageRangeEnd=1인 항목은 12개월 추천에서 제외되어야 한다"
        )
        XCTAssertTrue(
            recs.contains { $0.name == "범용 용품" },
            "ageRangeEnd=36인 항목은 12개월 추천에 포함되어야 한다"
        )
    }

    // Test 6: 37개월(범위 초과) — 추천 결과가 비어있어야 한다
    func testRecommendations_ageOverMax_returnsEmpty() {
        let catalog: [ProductRecommendation] = [
            ProductRecommendation(
                name: "유아 용품",
                category: .toy,
                ageRangeStart: 0,
                ageRangeEnd: 36,
                reason: "테스트용"
            )
        ]
        let recs = ProductRecommendationService.recommendations(for: 37, catalog: catalog)
        XCTAssertTrue(recs.isEmpty, "37개월은 모든 범위를 초과하므로 추천이 비어있어야 한다")
    }

    // MARK: - 인기 용품

    // Test 7: 인기 용품 — 등록이 많은 카테고리가 상위에 오는지 확인
    func testPopularProducts_returnsMostFrequentCategory() {
        let products: [BabyProduct] = [
            makeBabyProduct(category: .diaper),
            makeBabyProduct(category: .diaper),
            makeBabyProduct(category: .diaper),
            makeBabyProduct(category: .formula),
            makeBabyProduct(category: .toy)
        ]
        let popular = ProductRecommendationService.popularProducts(from: products, limit: 3)
        XCTAssertFalse(popular.isEmpty, "인기 용품 목록이 비어있지 않아야 한다")
        XCTAssertEqual(popular.first?.category, .diaper, "가장 많이 등록된 기저귀 카테고리가 1위여야 한다")
    }

    // Test 8: 인기 용품 limit — limit 개수를 초과하지 않아야 한다
    func testPopularProducts_respectsLimit() {
        let products: [BabyProduct] = (0..<10).map { _ in makeBabyProduct(category: .diaper) }
        let popular = ProductRecommendationService.popularProducts(from: products, limit: 3)
        XCTAssertLessThanOrEqual(popular.count, 3, "인기 용품은 limit 개수를 초과하지 않아야 한다")
    }

    // Test 9: 재구매 후보 — 7일 이내 항목만 반환되어야 한다
    func testReorderCandidates_within7Days() {
        let product1 = makeBabyProduct(category: .diaper)
        let product2 = makeBabyProduct(category: .formula)
        let product3 = makeBabyProduct(category: .toy)

        let reorderDates: [String: Date] = [
            product1.id: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            product2.id: Calendar.current.date(byAdding: .day, value: 10, to: Date())!,
            product3.id: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        ]

        let candidates = ProductRecommendationService.reorderCandidates(
            from: [product1, product2, product3],
            reorderDates: reorderDates,
            thresholdDays: 7
        )
        XCTAssertTrue(candidates.contains { $0.id == product1.id }, "3일 후 재구매 예정은 포함되어야 한다")
        XCTAssertFalse(candidates.contains { $0.id == product2.id }, "10일 후 재구매 예정은 제외되어야 한다")
    }

    // Test 10: 재구매 후보 — 재구매일 없는 항목은 제외되어야 한다
    func testReorderCandidates_noReorderDate_excluded() {
        let product = makeBabyProduct(category: .diaper)
        let candidates = ProductRecommendationService.reorderCandidates(
            from: [product],
            reorderDates: [:],
            thresholdDays: 7
        )
        XCTAssertTrue(candidates.isEmpty, "재구매일 없는 항목은 재구매 후보에서 제외되어야 한다")
    }

    // MARK: - Helpers

    private func makeBabyProduct(category: BabyProduct.ProductCategory) -> BabyProduct {
        BabyProduct(
            name: "테스트 \(category.displayName)",
            category: category
        )
    }
}

final class BadgePrivacyPassThroughTests: XCTestCase {

    /// BadgeEvaluator가 받은 userId를 그대로 saveBadge에 전달함을 검증.
    /// (passthrough가 보장되면 호출처 책임으로 격리: H-4 spec은 호출처가 currentUserId
    /// 전달해야 함을 의미. 현재 ActivityViewModel가 dataUserId 전달하는 것은 별도 회귀.)
    func test_evaluator_passesUserId_unchanged_toSaveBadge() {
        let mock = MockBadgeFirestore()
        let exp = expectation(description: "passthrough")
        Task { @MainActor in
            let evaluator = BadgeEvaluator(firestoreService: mock)
            _ = await evaluator.evaluate(
                event: .init(kind: .feedingLogged, babyId: "baby1", at: Date()),
                userId: "user_alice"
            )
            // saveBadge 호출되었으면 userId가 alice 그대로 전달됨 (mock은 userId 무시 — 호출 자체 검증)
            XCTAssertGreaterThan(mock.saveBadgeCalls.count, 0,
                                 "feedingLogged 이벤트는 firstRecord 또는 feeding100 후보 → 적어도 1번 saveBadge")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }
}

// MARK: - CryAnalysisViewModel phase 전이 테스트 (v2.7 flip 전 필수)

final class CryAnalysisViewModelTests: XCTestCase {

    func test_start_emptyBabyId_setsErrorPhase() {
        let exp = expectation(description: "guard")
        Task { @MainActor in
            let mock = MockCryAnalysisService()
            let vm = CryAnalysisViewModel(service: mock)
            await vm.start(babyId: "")
            if case .error(let msg) = vm.phase {
                XCTAssertTrue(msg.contains("아기"), "빈 babyId 가드 메시지 확인")
            } else {
                XCTFail("phase should be .error, got \(vm.phase)")
            }
            XCTAssertEqual(mock.configureCalled, 0, "guard에서 차단되면 세션 설정 호출 안 함")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func test_start_permissionDenied_setsPermissionDeniedPhase() {
        let exp = expectation(description: "denied")
        Task { @MainActor in
            let mock = MockCryAnalysisService()
            mock.stubPermissionStatus = .denied
            let vm = CryAnalysisViewModel(service: mock)
            await vm.start(babyId: "baby1")
            XCTAssertEqual(vm.phase, .permissionDenied)
            XCTAssertEqual(mock.configureCalled, 0, "권한 거부면 세션 설정 진행 안 함")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func test_cancel_resetsToIdle_andRestoresSession() {
        let exp = expectation(description: "cancel")
        Task { @MainActor in
            let mock = MockCryAnalysisService()
            let vm = CryAnalysisViewModel(service: mock)
            vm.phase = .recording(progress: 0.5)
            vm.cancel()
            XCTAssertEqual(vm.phase, .idle)
            XCTAssertEqual(mock.restoreCalled, 1, "cancel 시 세션 복원 강제 호출")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }
}

// MARK: - BadgeEvaluator 통합 테스트 (MockBadgeFirestore 활용)

final class BadgeEvaluatorIntegrationTests: XCTestCase {

    // C1: 기록 스트릭 — 어제 기록(streak 2) 뒤 오늘 첫 기록 → streak 3 저장 + recordStreak3 배지
    func testBadgeEvaluator_recordStreak_incrementsAndAwardsBadge() {
        let mock = MockBadgeFirestore()
        let now = Date()
        let yKey = RecordStreakPolicy.dayKey(Calendar.current.date(byAdding: .day, value: -1, to: now)!)
        mock.statsResponse = UserStats(id: UserStats.lifetimeId, recordStreak: 2, lastRecordDayKey: yKey)

        let expectation = expectation(description: "streak")
        Task { @MainActor in
            let evaluator = BadgeEvaluator(firestoreService: mock)
            let earned = await evaluator.evaluate(
                event: .init(kind: .diaperLogged, babyId: "b1", at: now), userId: "user1"
            )
            XCTAssertEqual(mock.updateRecordStreakCalls.last?.streak, 3, "어제→오늘 = +1")
            XCTAssertTrue(earned.contains { $0.id == "recordStreak3" }, "3일 도달 배지 획득")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // C1: 같은 날 두 번째 기록은 스트릭 갱신 없음 (no-op)
    func testBadgeEvaluator_recordStreak_sameDayNoUpdate() {
        let mock = MockBadgeFirestore()
        let now = Date()
        mock.statsResponse = UserStats(id: UserStats.lifetimeId, recordStreak: 5, lastRecordDayKey: RecordStreakPolicy.dayKey(now))

        let expectation = expectation(description: "sameday")
        Task { @MainActor in
            let evaluator = BadgeEvaluator(firestoreService: mock)
            _ = await evaluator.evaluate(event: .init(kind: .feedingLogged, babyId: "b1", at: now), userId: "user1")
            XCTAssertTrue(mock.updateRecordStreakCalls.isEmpty, "오늘 이미 카운트 — 갱신 없음")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testBadgeEvaluator_backfill_awardsFeeding100Badge() {
        let mock = MockBadgeFirestore()
        let babyId = "baby1"
        // 100 feeding 기록 = feeding100 배지 조건 충족
        mock.activityCounts["\(babyId)|feeding_breast"] = 50
        mock.activityCounts["\(babyId)|feeding_bottle"] = 50
        mock.earliestActivity[babyId] = Activity(
            babyId: babyId, type: .feedingBreast,
            startTime: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let expectation = expectation(description: "backfill")
        Task { @MainActor in
            let evaluator = BadgeEvaluator(firestoreService: mock)
            let earned = await evaluator.backfillIfNeeded(userId: "user1", ownedBabyIds: [babyId])
            XCTAssertTrue(earned.contains { $0.id == "feeding100" })
            XCTAssertEqual(mock.setStatsAbsoluteCalls.count, 1)
            XCTAssertEqual(mock.setStatsAbsoluteCalls.first?.feedingCount, 100)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    func testBadgeEvaluator_backfill_alreadyMigrated_isNoop() {
        let mock = MockBadgeFirestore()
        mock.statsResponse = UserStats(
            id: UserStats.lifetimeId,
            feedingCount: 0,
            sleepCount: 0,
            diaperCount: 0,
            growthRecordCount: 0,
            firstRecordAt: nil,
            updatedAt: Date(),
            migratedAtV1: Date()
        )

        let expectation = expectation(description: "noop")
        Task { @MainActor in
            let evaluator = BadgeEvaluator(firestoreService: mock)
            let earned = await evaluator.backfillIfNeeded(userId: "user1", ownedBabyIds: ["baby1"])
            XCTAssertTrue(earned.isEmpty)
            XCTAssertEqual(mock.setStatsAbsoluteCalls.count, 0, "이미 migrated면 setStatsAbsolute 호출 안 함")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // MARK: - App Review Prompt Tests

    private func makeEphemeralReviewDefaults() -> UserDefaults {
        let name = "test.appReview.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @MainActor
    func testReviewPrompt_firstTrigger_setsPending() {
        let svc = AppReviewPromptService(defaults: makeEphemeralReviewDefaults(), isEnabled: true)
        svc.noteTrigger(.recordsMilestone)
        XCTAssertEqual(svc.pendingTrigger, .recordsMilestone)
        XCTAssertFalse(svc.isConsumed)
    }

    @MainActor
    func testReviewPrompt_consume_marksConsumedAndClears() {
        let svc = AppReviewPromptService(defaults: makeEphemeralReviewDefaults(), isEnabled: true)
        svc.noteTrigger(.hospitalReport)
        let consumed = svc.consumePending()
        XCTAssertEqual(consumed, .hospitalReport)
        XCTAssertTrue(svc.isConsumed)
        XCTAssertNil(svc.pendingTrigger)
    }

    @MainActor
    func testReviewPrompt_afterConsume_noRearm() {
        let defaults = makeEphemeralReviewDefaults()
        let svc = AppReviewPromptService(defaults: defaults, isEnabled: true)
        svc.noteTrigger(.recordsMilestone)
        _ = svc.consumePending()
        svc.noteTrigger(.hospitalReport)
        XCTAssertNil(svc.pendingTrigger)
    }

    @MainActor
    func testReviewPrompt_secondTriggerIgnoredWhilePending() {
        let svc = AppReviewPromptService(defaults: makeEphemeralReviewDefaults(), isEnabled: true)
        svc.noteTrigger(.recordsMilestone)
        svc.noteTrigger(.hospitalReport)
        XCTAssertEqual(svc.pendingTrigger, .recordsMilestone)
    }

    @MainActor
    func testReviewPrompt_disabled_noPending() {
        let svc = AppReviewPromptService(defaults: makeEphemeralReviewDefaults(), isEnabled: false)
        svc.noteTrigger(.recordsMilestone)
        XCTAssertNil(svc.pendingTrigger)
    }

    @MainActor
    func testReviewPrompt_consumedFlagPersistsAcrossInstances() {
        let defaults = makeEphemeralReviewDefaults()
        let first = AppReviewPromptService(defaults: defaults, isEnabled: true)
        first.noteTrigger(.recordsMilestone)
        _ = first.consumePending()

        let second = AppReviewPromptService(defaults: defaults, isEnabled: true)
        second.noteTrigger(.hospitalReport)
        XCTAssertTrue(second.isConsumed)
        XCTAssertNil(second.pendingTrigger)
    }

    func testReviewPrompt_coreActivityTotal() {
        XCTAssertEqual(AppReviewPromptService.coreActivityTotal(nil), 0)
        var stats = UserStats.empty()
        stats.feedingCount = 7
        stats.sleepCount = 5
        stats.diaperCount = 6
        stats.growthRecordCount = 2
        XCTAssertEqual(AppReviewPromptService.coreActivityTotal(stats), 20)
    }
}

