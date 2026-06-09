import XCTest
@testable import BabyCare

/// 인사이트/발열 정합 회귀 방지 (2026-06-10 감사 #11 Z-score 자기오염 / #18 stale 발열 윈도우).
final class ActivityInsightTests: XCTestCase {

    // MARK: - #11 현재 분석 주차를 Z-score 기준선에서 제외

    func testExcludingWeek_removesCurrentWeekFromHistory() {
        let week1 = WeeklyMetricSnapshot(weekKey: "2024W01", weekStartDate: Date(), metrics: ["feeding.count": 8])
        let week2 = WeeklyMetricSnapshot(weekKey: "2024W02", weekStartDate: Date(), metrics: ["feeding.count": 9])
        let current = WeeklyMetricSnapshot(weekKey: "2024W03", weekStartDate: Date(), metrics: ["feeding.count": 99])

        let history = [current, week2, week1].excludingWeek("2024W03")

        XCTAssertEqual(history.map(\.weekKey), ["2024W02", "2024W01"],
                       "현재 분석 주차(2024W03)는 Z-score 기준선에서 제외되어야 한다 (자기오염 #11)")
    }

    // MARK: - #18 방금 저장한 체온이 발열 추세 윈도우에 포함

    @MainActor
    func testRegisterTemperature_includesJustSavedReadingInFeverTrend() {
        let vm = ActivityViewModel()
        let now = Date()
        vm.recentTemperatureActivities = [
            Activity(babyId: "b", type: .temperature, startTime: now.addingTimeInterval(-3600), temperature: 38.5)
        ]
        XCTAssertFalse(vm.isFeverTrendDetected, "직전 1회만으로는 발열 추세 아님")

        let justSaved = Activity(babyId: "b", type: .temperature, startTime: now, temperature: 39.0)
        let trend = vm.registerTemperature(justSaved)

        XCTAssertTrue(trend, "방금 저장한 발열이 24h 윈도우에 포함돼 2회 → 추세 감지 (#18)")
        XCTAssertEqual(vm.recentTemperatureActivities.count, 2, "방금 저장한 체온이 윈도우에 추가되어야 한다")
    }
}
