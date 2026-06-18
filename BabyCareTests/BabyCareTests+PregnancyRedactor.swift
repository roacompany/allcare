import XCTest
@testable import BabyCare

/// `PregnancyRedactor` 순수 로직 단위 테스트.
/// Sentry 어댑터(`BabyCareApp` `#if !DEBUG`)는 이 타입에 위임하므로,
/// 여기서 redact 계약을 검증하면 실제 유출 방어 깊이를 보장한다 (safety.md).
final class PregnancyRedactorTests: XCTestCase {

    // MARK: - containsKeyword(_:)

    func testContainsKeyword_englishCaseInsensitive() {
        XCTAssertTrue(PregnancyRedactor.containsKeyword("User opened Pregnancy tab"))
        XCTAssertTrue(PregnancyRedactor.containsKeyword("KICK counted at 12:00"))
        XCTAssertTrue(PregnancyRedactor.containsKeyword("prenatal visit booked"))
        XCTAssertTrue(PregnancyRedactor.containsKeyword("EDD recalculated"))
    }

    func testContainsKeyword_korean() {
        XCTAssertTrue(PregnancyRedactor.containsKeyword("임신 주차 계산 실패"))
        XCTAssertTrue(PregnancyRedactor.containsKeyword("태동 세션 저장"))
    }

    func testContainsKeyword_nonPregnancyIsFalse() {
        XCTAssertFalse(PregnancyRedactor.containsKeyword("feeding 200ml saved"))
        XCTAssertFalse(PregnancyRedactor.containsKeyword("수유 기록 저장"))
        XCTAssertFalse(PregnancyRedactor.containsKeyword(""))
    }

    // MARK: - scrub(_:)

    func testScrub_replacesPregnancyStringValue_preservesOthers() {
        let out = PregnancyRedactor.scrub(["note": "edd is 2026-01-01", "ml": "200"])
        XCTAssertEqual(out["note"] as? String, PregnancyRedactor.placeholder)
        XCTAssertEqual(out["ml"] as? String, "200")
    }

    func testScrub_redactsValueWhenKeyIsPregnancyKeyword() {
        let out = PregnancyRedactor.scrub(["pregnancyId": "abc123", "babyId": "xyz"])
        XCTAssertEqual(out["pregnancyId"] as? String, PregnancyRedactor.placeholder)
        XCTAssertEqual(out["babyId"] as? String, "xyz")
    }

    func testScrub_recursesIntoNestedDictAndArray() {
        let out = PregnancyRedactor.scrub([
            "ctx": ["kick": "true", "safe": "ok"],
            "list": ["임신", "feeding"]
        ])
        let ctx = out["ctx"] as? [String: Any]
        XCTAssertEqual(ctx?["kick"] as? String, PregnancyRedactor.placeholder) // key match
        XCTAssertEqual(ctx?["safe"] as? String, "ok")
        let list = out["list"] as? [Any]
        XCTAssertEqual(list?[0] as? String, PregnancyRedactor.placeholder)     // value match
        XCTAssertEqual(list?[1] as? String, "feeding")
    }

    func testScrub_preservesNonStringScalars() {
        let out = PregnancyRedactor.scrub(["count": 42, "flag": true])
        XCTAssertEqual(out["count"] as? Int, 42)
        XCTAssertEqual(out["flag"] as? Bool, true)
    }

    // MARK: - containsKeyword(inDict:)

    func testContainsInDict_trueForNestedValueAndArray() {
        XCTAssertTrue(PregnancyRedactor.containsKeyword(inDict: ["a": ["b": "태동 detected"]]))
        XCTAssertTrue(PregnancyRedactor.containsKeyword(inDict: ["tags": ["x", "lmp"]]))
        XCTAssertTrue(PregnancyRedactor.containsKeyword(inDict: ["pregnancyWeek": 12])) // key match
    }

    func testContainsInDict_falseForCleanData() {
        XCTAssertFalse(PregnancyRedactor.containsKeyword(inDict: ["screen": "feeding", "n": 3]))
        XCTAssertFalse(PregnancyRedactor.containsKeyword(inDict: [:]))
    }
}
