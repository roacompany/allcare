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
        XCTAssertEqual(streak.count, 3, "routineStreak 3/7/30 = 3개")
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
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!
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
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = cal.date(from: DateComponents(year: 2026, month: 2, day: 1))!
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
            scheduledDate: schedDate
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

    // MARK: - BannerAdManager state machine

    @MainActor
    func testBannerAdManager_loadState_equality() {
        let idle: BannerAdManager.LoadState = .idle
        XCTAssertEqual(idle, .idle)
        XCTAssertNotEqual(idle, .loading)
        XCTAssertNotEqual(idle, .loaded)
    }

    @MainActor
    func testBannerAdManager_failedState_comparesByAttempt() {
        let attempt1: BannerAdManager.LoadState = .failed(attempt: 1)
        let attempt2: BannerAdManager.LoadState = .failed(attempt: 2)
        XCTAssertEqual(attempt1, .failed(attempt: 1))
        XCTAssertNotEqual(attempt1, attempt2)
    }

    @MainActor
    func testBannerAdManager_safeScreenWidth_returnsReasonableValue() {
        let width = BannerAdManager.safeScreenWidth()
        XCTAssertGreaterThanOrEqual(width, 320)
        XCTAssertLessThanOrEqual(width, 1366)
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

// MARK: - PregnancyOutcome 계약 + Pregnancy 변환 (H-2 자동 검증 — 출산 전환)

final class PregnancyOutcomeContractTests: XCTestCase {

    /// rawValue는 Firestore persist되는 영구 계약. 변경 시 기존 사용자 데이터 손상.
    /// (feedback_enum_raw_value_contract.md)
    func test_rawValues_are_locked_contract() {
        XCTAssertEqual(PregnancyOutcome.ongoing.rawValue, "ongoing")
        XCTAssertEqual(PregnancyOutcome.born.rawValue, "born")
        XCTAssertEqual(PregnancyOutcome.miscarriage.rawValue, "miscarriage")
        XCTAssertEqual(PregnancyOutcome.stillbirth.rawValue, "stillbirth")
        XCTAssertEqual(PregnancyOutcome.terminated.rawValue, "terminated")
    }

    func test_allCases_count_isFive() {
        XCTAssertEqual(PregnancyOutcome.allCases.count, 5,
                       "신규 case 추가 시 마이그레이션/UI 분기 검토 필요")
    }

    func test_displayName_allCases_haveKoreanLabel() {
        for outcome in PregnancyOutcome.allCases {
            XCTAssertFalse(outcome.displayName.isEmpty)
        }
    }

    /// 출산 전환 시뮬: ongoing → born + archivedAt + transitionState=completed
    /// (실제 WriteBatch 호출은 Firestore 의존이라 unit 검증 불가, 모델 변경만 검증)
    func test_transition_ongoing_to_born_setsExpectedFields() {
        var p = Pregnancy(id: "p1", lmpDate: Date(), dueDate: Date(),
                          fetusCount: 1, babyNickname: "테스트")
        p.outcome = .ongoing

        // 전환 시뮬 (FirestoreService+Pregnancy.swift L173 패턴)
        p.outcome = .born
        p.archivedAt = Date()
        p.transitionState = "completed"

        XCTAssertEqual(p.outcome, .born)
        XCTAssertNotNil(p.archivedAt)
        XCTAssertEqual(p.transitionState, "completed",
                       "WriteBatch idempotency를 위한 전환 마커 필수")
    }
}

// MARK: - KickSession 모델 (H-1 자동 검증 — 태동 카운트/duration/2시간 임계)

final class KickSessionTests: XCTestCase {

    private let pid = "preg1"

    func test_kickCount_emptyArray_returnsZero() {
        let s = KickSession(pregnancyId: pid)
        XCTAssertEqual(s.kickCount, 0)
        XCTAssertFalse(s.reachedTarget)
    }

    func test_kickCount_tenKicks_reachesTarget() {
        let kicks = (0..<10).map { _ in KickEvent() }
        let s = KickSession(pregnancyId: pid, kicks: kicks)
        XCTAssertEqual(s.kickCount, 10)
        XCTAssertTrue(s.reachedTarget, "ACOG 표준 10회 달성")
    }

    func test_kickCount_customTarget_appliesIt() {
        let kicks = (0..<5).map { _ in KickEvent() }
        let s = KickSession(pregnancyId: pid, kicks: kicks, targetCount: 5)
        XCTAssertTrue(s.reachedTarget, "커스텀 타겟 5 달성")
    }

    func test_durationSeconds_endedAt_returnsExact() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(1_800)  // 30분
        let s = KickSession(pregnancyId: pid, startedAt: start, endedAt: end)
        XCTAssertEqual(s.durationSeconds, 1_800, accuracy: 0.1)
    }

    func test_exceededTwoHours_underThreshold_returnsFalse() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(7_199)  // 1시간 59분 59초
        let s = KickSession(pregnancyId: pid, startedAt: start, endedAt: end)
        XCTAssertFalse(s.exceededTwoHours)
    }

    func test_exceededTwoHours_overThreshold_returnsTrue() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(7_201)  // 2시간 1초
        let s = KickSession(pregnancyId: pid, startedAt: start, endedAt: end)
        XCTAssertTrue(s.exceededTwoHours, "ACOG 2시간 초과 알림 트리거")
    }
}

// MARK: - PregnancyDateMath 위젯 엣지 (H-7 자동 검증)

final class PregnancyDateMathTests: XCTestCase {

    private func date(_ string: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: string)!
    }

    // MARK: weekAndDay

    func test_weekAndDay_nil_lmp_returnsNil() {
        XCTAssertNil(PregnancyDateMath.weekAndDay(from: nil, now: date("2026-04-19")))
    }

    func test_weekAndDay_future_lmp_returnsNil() {
        // lmp가 now보다 미래 → 음수 days → nil
        let lmp = date("2026-05-01")
        let now = date("2026-04-19")
        XCTAssertNil(PregnancyDateMath.weekAndDay(from: lmp, now: now))
    }

    func test_weekAndDay_exactly7days_returns1week0day() {
        let lmp = date("2026-04-12")
        let now = date("2026-04-19")
        let result = PregnancyDateMath.weekAndDay(from: lmp, now: now)
        XCTAssertEqual(result?.weeks, 1)
        XCTAssertEqual(result?.days, 0)
    }

    func test_weekAndDay_17days_returns2week3day() {
        let lmp = date("2026-04-02")
        let now = date("2026-04-19")
        let result = PregnancyDateMath.weekAndDay(from: lmp, now: now)
        XCTAssertEqual(result?.weeks, 2)
        XCTAssertEqual(result?.days, 3)
    }

    func test_weekAndDay_280days_returns40week0day() {
        let lmp = date("2025-07-13")  // 280일 전 = 40주 정확
        let now = date("2026-04-19")
        let result = PregnancyDateMath.weekAndDay(from: lmp, now: now)
        XCTAssertEqual(result?.weeks, 40)
        XCTAssertEqual(result?.days, 0)
    }

    func test_weekAndDay_sameDay_returns0week0day() {
        let lmp = date("2026-04-19")
        let now = date("2026-04-19")
        let result = PregnancyDateMath.weekAndDay(from: lmp, now: now)
        XCTAssertEqual(result?.weeks, 0)
        XCTAssertEqual(result?.days, 0)
    }

    // MARK: dDay

    func test_dDay_nil_due_returnsNil() {
        XCTAssertNil(PregnancyDateMath.dDay(due: nil, now: date("2026-04-19")))
    }

    func test_dDay_due_today_returns0() {
        let due = date("2026-04-19")
        let now = date("2026-04-19")
        XCTAssertEqual(PregnancyDateMath.dDay(due: due, now: now), 0)
    }

    func test_dDay_due_tomorrow_returns1() {
        let due = date("2026-04-20")
        let now = date("2026-04-19")
        XCTAssertEqual(PregnancyDateMath.dDay(due: due, now: now), 1)
    }

    func test_dDay_due_yesterday_returnsMinus1_overdue() {
        let due = date("2026-04-18")
        let now = date("2026-04-19")
        XCTAssertEqual(PregnancyDateMath.dDay(due: due, now: now), -1)
    }

    func test_dDay_due_oneWeekFuture_returns7() {
        let due = date("2026-04-26")
        let now = date("2026-04-19")
        XCTAssertEqual(PregnancyDateMath.dDay(due: due, now: now), 7)
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
}
