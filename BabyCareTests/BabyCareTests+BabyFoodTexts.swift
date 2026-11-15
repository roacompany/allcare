import XCTest
@testable import BabyCare

/// 고객이 보는 이유식 가이드 글 — 2026-11-15 관리자 「콘텐츠 관리」를 앱 글로 맞추다 찾은 두 곳(PO 「고칩니다」).
/// 고치기 전: 4~5개월 아기 머리글이 「지금은 준비 단계 (4~5개월, WHO 6개월 권장) 단계예요」(「단계」 두 번 · 괄호) ·
/// 꿀 경고가 「유아 보톨리즘」(병 이름 표기는 보툴리즘).
final class BabyFoodTextsTests: XCTestCase {

    /// 「지금은 … 단계예요」에 「단계」가 한 번만 · 괄호 없음 — 첫 단계 이름엔 이미 「단계」와 괄호가 들어 있다. 나머지 단계 글은 그대로.
    func test_currentHeadline_saysStageOnce() {
        for stage in BabyFoodStage.allCases {
            let headline = stage.currentHeadline
            XCTAssertEqual(headline.components(separatedBy: "단계").count - 1, 1, "「단계」가 겹친다: \(headline)")
            XCTAssertFalse(headline.contains("("), "머리글에 괄호가 있다: \(headline)")
        }
        XCTAssertEqual(BabyFoodStage.early.currentHeadline, "지금은 준비 단계예요")
        XCTAssertEqual(BabyFoodStage.earlyMid.currentHeadline, "지금은 초기~중기 이유식 단계예요")
        XCTAssertEqual(BabyFoodStage.toddler.currentHeadline, "지금은 유아식 단계예요")
    }

    /// 꿀 경고 — 병 이름은 「보툴리즘」(「보톨리즘」 오타였다).
    func test_honeyWarning_spellsBotulism() {
        XCTAssertTrue(BabyFoodGuideData.honeyWarning.contains("보툴리즘"), BabyFoodGuideData.honeyWarning)
        XCTAssertFalse(BabyFoodGuideData.honeyWarning.contains("보톨리즘"), BabyFoodGuideData.honeyWarning)
    }
}
