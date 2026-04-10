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
}
