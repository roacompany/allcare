import XCTest
@testable import BabyCare

/// 수유 패턴 집계 회귀 방지 (2026-06-10 감사 #14 모유 병수유를 분유로 오집계).
final class FeedingPatternTests: XCTestCase {

    func testBreastVsBottleRatio_breastMilkBottleCountsAsBreastMilkNotFormula() {
        let now = Date()
        let start = now.addingTimeInterval(-6 * 86_400)
        let directBreast = Activity(babyId: "b", type: .feedingBreast, startTime: now.addingTimeInterval(-3600))
        var formulaBottle = Activity(babyId: "b", type: .feedingBottle, startTime: now.addingTimeInterval(-7200), amount: 100)
        formulaBottle.feedingContent = .formula
        var breastMilkBottle = Activity(babyId: "b", type: .feedingBottle, startTime: now.addingTimeInterval(-10800), amount: 80)
        breastMilkBottle.feedingContent = .breastMilk
        // nil content = 분유(하위호환)
        let nilContentBottle = Activity(babyId: "b", type: .feedingBottle, startTime: now.addingTimeInterval(-14400), amount: 90)

        let report = PatternAnalysisService.analyze(
            activities: [directBreast, formulaBottle, breastMilkBottle, nilContentBottle],
            period: "주간", startDate: start, endDate: now
        )

        XCTAssertEqual(report.feeding.breastVsBottleRatio.breast, 2,
                       "모유 = 직수 1 + 유축 모유 병수유 1 (#14)")
        XCTAssertEqual(report.feeding.breastVsBottleRatio.bottle, 2,
                       "분유 = formula bottle 1 + nil(분유) 1 — 모유 병수유는 제외 (#14)")
    }
}
