import XCTest
@testable import BabyCare

/// forward-compat `.unknown` 온도 누수 + 분석 phantom-zero 회귀 방지 (2026-06-10 감사 #1/#4/#10).
final class AnalysisUnknownLeakTests: XCTestCase {

    private let cal = Calendar.current

    // MARK: - #1/#4 .unknown 형제 온도 누수 차단 (공유 헬퍼)

    func testTemperatureActivities_excludesUnknownSentinelAndNonTemperatureTypes() {
        let realTemp = Activity(babyId: "b", type: .temperature, temperature: 38.0)
        var unknownTemp = Activity(babyId: "b", type: .unknown)
        unknownTemp.temperature = 41.0    // 미래 스키마가 .unknown 으로 디코드되며 보존한 형제 온도
        let bottle = Activity(babyId: "b", type: .feedingBottle, amount: 100)

        let result = [realTemp, unknownTemp, bottle].temperatureActivities

        XCTAssertEqual(result.map(\.id), [realTemp.id],
                       "체온 집계는 .temperature 기록만 — .unknown 형제 온도(41.0)·타 타입 제외")
    }

    // MARK: - #1 일별 집계 avgTemperature 가 .unknown 온도를 포함하면 안 됨

    func testAggregate_dailyAvgTemperature_excludesUnknownSentinel() {
        let day = cal.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let realTemp = Activity(babyId: "b", type: .temperature,
                                startTime: day.addingTimeInterval(3600), temperature: 38.0)
        var unknownTemp = Activity(babyId: "b", type: .unknown, startTime: day.addingTimeInterval(7200))
        unknownTemp.temperature = 41.0
        let period = AnalysisPeriod(from: day, to: day.addingTimeInterval(86_399))

        let aggs = Preprocessor.aggregate(activities: [realTemp, unknownTemp], period: period, ageInDaysAtEnd: 200)

        let dayAgg = aggs.first { cal.isDate($0.date, inSameDayAs: day) }
        XCTAssertEqual(dayAgg?.avgTemperature, 38.0,
                       "avgTemperature 는 .temperature 기록만 — .unknown 41.0 이 섞이면 발열 오탐(PatternClassifier)")
    }

    // MARK: - #10 선행 결측일 phantom-zero baseline 오염 차단

    func testAggregate_leadingNoDataDays_areNotEmittedAsPhantomZeroAggregates() {
        let day0 = cal.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let day2 = cal.date(byAdding: .day, value: 2, to: day0)!
        let day4 = cal.date(byAdding: .day, value: 4, to: day0)!
        // 데이터는 day2 하루만 — day0, day1 은 데이터 시작 전 선행 결측일.
        let feed = Activity(babyId: "b", type: .feedingBottle,
                            startTime: day2.addingTimeInterval(3600), amount: 100)
        let period = AnalysisPeriod(from: day0, to: day4)

        let aggs = Preprocessor.aggregate(activities: [feed], period: period, ageInDaysAtEnd: 200)

        XCTAssertNil(aggs.first { $0.date < day2 && $0.isMissingData == false },
                     "데이터 시작 전 선행 결측일이 isMissingData=false 0집계로 박제되면 baseline(μ/σ) 오염")
        XCTAssertEqual(aggs.first?.date, day2,
                       "첫 집계는 실제 데이터가 있는 첫 날이어야 한다")
    }
}
