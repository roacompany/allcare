import XCTest
@testable import BabyCare

/// 위젯 → 앱 주소 약속. 위젯은 `WidgetLink` 표의 주소만 쓰고, 앱은 그 주소를 전부 풀어야 한다.
/// 고치기 전: 「오늘 요약」·성장·임신 위젯 주소를 앱이 몰라 눌러도 앱만 열렸고(dashboard·health/growth·pregnancy),
/// 수면·기저귀 단추는 칸을 버려 늘 수유 칸으로 열렸다(2026-07-12 c3896ce 이후 — 그때 기록 화면이 칸 없는 런처였다).
final class WidgetLinkTests: XCTestCase {

    /// 표에 있는 모든 위젯 주소는 앱에서 어딘가로 열린다(앱만 열리고 끝나는 주소가 없다).
    func test_everyWidgetLink_opensSomewhereInTheApp() {
        for link in WidgetLink.allCases {
            XCTAssertNotNil(DeepLinkRouter.destination(from: link.url), "앱이 모르는 위젯 주소: \(link.rawValue)")
        }
    }

    /// 수유·수면·기저귀 단추는 그 칸으로 기록하기를 연다.
    func test_recordLinks_openTheirOwnSection() {
        XCTAssertEqual(DeepLinkRouter.destination(from: WidgetLink.recordFeeding.url)?.recordingCategory, .feeding)
        XCTAssertEqual(DeepLinkRouter.destination(from: WidgetLink.recordSleep.url)?.recordingCategory, .sleep)
        XCTAssertEqual(DeepLinkRouter.destination(from: WidgetLink.recordDiaper.url)?.recordingCategory, .diaper)
    }

    /// 칸 없는 기록하기는 칸을 고르지 않는다.
    func test_plainRecordLink_choosesNoSection() {
        let destination = DeepLinkRouter.destination(from: WidgetLink.record.url)
        XCTAssertEqual(destination, .record)
        XCTAssertNil(destination?.recordingCategory)
    }

    func test_todaySummaryLink_opensHome() {
        XCTAssertEqual(DeepLinkRouter.destination(from: WidgetLink.home.url), .home)
    }

    func test_growthLink_opensGrowth() {
        XCTAssertEqual(DeepLinkRouter.destination(from: WidgetLink.growth.url), .growth)
    }

    /// 임신 화면은 꺼져 있다(FeatureFlags.pregnancyModeEnabled) — 임신 위젯은 홈으로.
    func test_pregnancyLink_opensHome() {
        XCTAssertEqual(DeepLinkRouter.destination(from: WidgetLink.pregnancy.url), .home)
    }

    /// 다른 앱의 주소나 모르는 주소는 무시한다.
    func test_foreignOrUnknownLinks_areIgnored() {
        XCTAssertNil(DeepLinkRouter.destination(from: URL(string: "https://example.com/record")!))
        XCTAssertNil(DeepLinkRouter.destination(from: URL(string: "babycare://nowhere")!))
    }
}
