import UIKit
import XCTest
@testable import BabyCare

/// SF Symbols — 없는 이름은 오류 없이 빈칸으로 그려진다(빌드·시험 모두 초록). 이 기기(시험 시뮬레이터)에서 실제로 그려지나 본다.
/// 고치기 전: 후기 이유식 아이콘 「bowl.fill」 이 어느 판에도 없어 빈칸이었다(2026-11-14).
/// (코드에 글자로 적힌 이름은 `scripts/symbols_check.py` 가 지원 판 iOS 17 기준으로 따로 본다.)
final class SFSymbolsTests: XCTestCase {

    private func assertRenders(_ names: [String], _ kind: String,
                               file: StaticString = #filePath, line: UInt = #line) {
        for name in names {
            XCTAssertNotNil(UIImage(systemName: name), "\(kind) 아이콘 「\(name)」 이 빈칸으로 그려진다", file: file, line: line)
        }
    }

    /// 아이콘 이름을 내는 열거형 — 모든 값의 아이콘이 그려진다(열거형 값을 다 돈다 · 이름을 적지 않는다).
    func test_everyEnumIcon_rendersOnThisDevice() {
        assertRenders(BabyFoodStage.allCases.map(\.icon), "이유식 단계")
        assertRenders(Activity.ActivityType.allCases.map(\.icon), "기록 종류")
        assertRenders(Activity.FoodReaction.allCases.map(\.icon), "이유식 반응")
        assertRenders(Activity.StoolConsistency.allCases.map(\.icon), "대변 상태")
        assertRenders(Activity.SleepQualityType.allCases.map(\.icon), "잠 질")
        assertRenders(Activity.SleepMethodType.allCases.map(\.icon), "재우는 방법")
        assertRenders(BabyProduct.ProductCategory.allCases.map(\.icon), "용품 분류")
        assertRenders(FoodSafetyStatus.allCases.map(\.icon), "음식 안전")
        assertRenders(HospitalVisit.VisitType.allCases.map(\.icon), "병원 방문")
        assertRenders(Milestone.MilestoneCategory.allCases.map(\.icon), "발달 영역")
    }

    func test_fallback_prefersNewerWhenThisDeviceHasIt() {
        XCTAssertEqual(SFSymbolFallback.prefer("heart.fill", else: "star.fill"), "heart.fill")
    }

    /// 이 기기에 없는 새 이름이면 옛 이름으로 — iOS 17 기기에서 iOS 18 이름이 빈칸이 되지 않게.
    func test_fallback_usesOlderWhenNewerIsMissing() {
        XCTAssertEqual(SFSymbolFallback.prefer("no.such.symbol.babycare", else: "heart.fill"), "heart.fill")
    }

    func test_fallback_resultAlwaysRenders() {
        let name = SFSymbolFallback.prefer("heart.text.clipboard.fill", else: "heart.text.square.fill")
        XCTAssertNotNil(UIImage(systemName: name))
    }
}
