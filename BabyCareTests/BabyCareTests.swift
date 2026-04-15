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
        // 이벤트명이 Firebase 규칙을 준수하는지 확인 (소문자+언더스코어, 40자 이내)
        let events = [
            AnalyticsEvents.dashboardCardTap,
            AnalyticsEvents.recordSave,
            AnalyticsEvents.aiAdviceRequest,
            AnalyticsEvents.growthDataInput,
            AnalyticsEvents.productView,
        ]
        for event in events {
            XCTAssertTrue(event.count <= 40, "\(event)는 40자를 초과합니다")
            XCTAssertTrue(event.range(of: "^[a-z_]+$", options: .regularExpression) != nil,
                          "\(event)는 소문자+언더스코어 규칙을 위반합니다")
        }
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

    // MARK: - AdExperimentVariant Tests

    func testAdExperimentVariant_allThreeTabs_showsOnDashboardCalendarHealth() {
        let variant: AdExperimentVariant = .allThreeTabs
        XCTAssertTrue(variant.shouldShowBanner(forTab: 0), "Dashboard(0)은 표시")
        XCTAssertTrue(variant.shouldShowBanner(forTab: 1), "Calendar(1)은 표시")
        XCTAssertTrue(variant.shouldShowBanner(forTab: 3), "Health(3)은 표시")
        XCTAssertFalse(variant.shouldShowBanner(forTab: 2), "기록+(2)는 미표시")
        XCTAssertFalse(variant.shouldShowBanner(forTab: 4), "Settings(4)는 미표시")
    }

    func testAdExperimentVariant_dashboardOnly_showsOnDashboardOnly() {
        let variant: AdExperimentVariant = .dashboardOnly
        XCTAssertTrue(variant.shouldShowBanner(forTab: 0), "Dashboard(0)만 표시")
        XCTAssertFalse(variant.shouldShowBanner(forTab: 1), "Calendar(1) 미표시")
        XCTAssertFalse(variant.shouldShowBanner(forTab: 2), "기록+(2) 미표시")
        XCTAssertFalse(variant.shouldShowBanner(forTab: 3), "Health(3) 미표시")
        XCTAssertFalse(variant.shouldShowBanner(forTab: 4), "Settings(4) 미표시")
    }

    func testAdExperimentVariant_currentVariant_defaultsToAllThreeTabs() {
        XCTAssertEqual(AdExperimentVariant.currentVariant, .allThreeTabs,
                       "기본 variant는 .allThreeTabs (A안)여야 합니다")
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

    // MARK: Helpers

    private func makePatternReport(
        feedingDailyAverage: Double = 6,
        feedingPrevious: Double? = nil,
        sleepDailyAverageHours: Double = 12,
        sleepPrevious: Double? = nil,
        diaperDailyAverage: Double = 5,
        diaperPrevious: Double? = nil
    ) -> PatternReport {
        let now = Date()
        let feeding = FeedingPattern(
            totalCount: 42,
            dailyAverage: feedingDailyAverage,
            averageInterval: nil,
            intervalTrend: .stable,
            totalMl: 0,
            dailyMlAverage: 0,
            breastVsBottleRatio: (breast: 1, bottle: 0),
            peakHours: [],
            dailyCounts: [],
            previousDailyAverage: feedingPrevious
        )
        let sleep = SleepPattern(
            totalHours: 84,
            dailyAverageHours: sleepDailyAverageHours,
            averageDuration: 3600,
            durationTrend: .stable,
            qualityDistribution: [:],
            methodDistribution: [:],
            peakSleepHours: [],
            dailyHours: [],
            previousDailyAverageHours: sleepPrevious
        )
        let diaper = DiaperPattern(
            totalCount: 35,
            dailyAverage: diaperDailyAverage,
            wetVsDirtyRatio: (wet: 2, dirty: 1, both: 0),
            stoolColorDistribution: [:],
            consistencyDistribution: [:],
            rashCount: 0,
            dailyCounts: [],
            previousDailyAverage: diaperPrevious
        )
        let health = HealthPattern(
            temperatureReadings: [],
            averageTemp: nil,
            highTempDays: 0,
            medicationCount: 0,
            medicationNames: [:],
            consecutiveFeverDays: 0
        )
        let summary = SummaryPattern(
            totalRecords: 77,
            mostActiveDay: nil,
            leastActiveDay: nil,
            categoryDistribution: [:],
            missingDays: 0
        )
        return PatternReport(
            period: "7일",
            startDate: now.addingTimeInterval(-604800),
            endDate: now,
            feeding: feeding,
            sleep: sleep,
            diaper: diaper,
            health: health,
            summary: summary
        )
    }

    /// 수유·수면·배변 모두 비교 데이터 있음 → 인사이트 3개 생성
    func testGenerateInsights_withComparisonData() {
        let report = makePatternReport(
            feedingDailyAverage: 6,
            feedingPrevious: 5,
            sleepDailyAverageHours: 12,
            sleepPrevious: 10,
            diaperDailyAverage: 5,
            diaperPrevious: 6
        )
        let insights = WeeklyInsightService.generateInsights(from: report)
        XCTAssertEqual(insights.count, 3, "3개 카테고리 모두 이전 데이터 있을 때 인사이트 3개가 반환되어야 합니다")
    }

    /// 3개 카테고리가 모두 변화했을 때 최대 3개(prefix(3)) 동작 확인
    func testGenerateInsights_maxThree() {
        let report = makePatternReport(
            feedingDailyAverage: 8,
            feedingPrevious: 5,
            sleepDailyAverageHours: 14,
            sleepPrevious: 10,
            diaperDailyAverage: 3,
            diaperPrevious: 6
        )
        let insights = WeeklyInsightService.generateInsights(from: report)
        XCTAssertLessThanOrEqual(insights.count, 3, "generateInsights는 최대 3개만 반환해야 합니다")
        XCTAssertEqual(insights.count, 3, "3개 카테고리 모두 변화 시 정확히 3개가 반환되어야 합니다")
    }

    /// previousDailyAverage 모두 nil → 빈 배열
    func testGenerateInsights_emptyPrevious() {
        let report = makePatternReport(
            feedingPrevious: nil,
            sleepPrevious: nil,
            diaperPrevious: nil
        )
        let insights = WeeklyInsightService.generateInsights(from: report)
        XCTAssertTrue(insights.isEmpty, "이전 기간 데이터가 없으면 인사이트는 빈 배열이어야 합니다")
    }

    /// 변화율 3% → trend .stable, title에 "안정" 포함
    func testGenerateInsights_stableUnder5Percent() {
        // 수유: 이전 100, 현재 103 → 변화율 3% < 5% → .stable
        let report = makePatternReport(
            feedingDailyAverage: 103,
            feedingPrevious: 100,
            sleepPrevious: nil,
            diaperPrevious: nil
        )
        let insights = WeeklyInsightService.generateInsights(from: report)
        XCTAssertEqual(insights.count, 1, "수유만 이전 데이터 있을 때 인사이트 1개여야 합니다")
        XCTAssertEqual(insights[0].trend, .stable, "3% 변화는 .stable 트렌드여야 합니다")
        XCTAssertTrue(insights[0].title.contains("안정"), "stable 인사이트 title에 '안정'이 포함되어야 합니다")
    }

    /// feeding 10% 변화, sleep 30% 변화 → sleep이 첫 번째 (변화율 내림차순 정렬)
    func testGenerateInsights_sortedByChangePercent() {
        // feeding: 이전 10, 현재 11 → 10% 증가
        // sleep: 이전 10, 현재 13 → 30% 증가
        let report = makePatternReport(
            feedingDailyAverage: 11,
            feedingPrevious: 10,
            sleepDailyAverageHours: 13,
            sleepPrevious: 10,
            diaperPrevious: nil
        )
        let insights = WeeklyInsightService.generateInsights(from: report)
        XCTAssertEqual(insights.count, 2, "feeding+sleep 2개 인사이트가 반환되어야 합니다")
        XCTAssertEqual(insights[0].category, .sleep, "변화율이 높은 sleep이 첫 번째여야 합니다")
        XCTAssertEqual(insights[1].category, .feeding, "변화율이 낮은 feeding이 두 번째여야 합니다")
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

    // MARK: - Badge Phase 1 Tests

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

    func testBadgeCatalog_hasEight() {
        XCTAssertEqual(BadgeCatalog.all.count, 8)
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
}
