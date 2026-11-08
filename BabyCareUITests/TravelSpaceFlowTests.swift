import XCTest

/// 여행 공간(설계 2026-11-05 §2 · §7) — 아래 바 「여행」으로 열고 왼쪽 아래 「←」로 닫는다 · 「더 보기」 안의 건강·설정.
/// 로그인 없이 UI_TESTING 으로 돈다(여행 목록은 서버가 막아 빈/오류 화면 — 여기서는 길만 잰다).
final class TravelSpaceFlowTests: XCTestCase {
    private let dir = "/tmp/babycare_screenshots"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    private func babyCareBar(_ app: XCUIApplication) -> XCUIElement {
        app.tabBars.containing(.button, identifier: "더 보기").firstMatch
    }

    /// 여행 공간 아래 바는 직접 그린 바다(시스템 탭 바 아님) — 칸은 식별자로 찾는다.
    private func travelTab(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.buttons["travel.tab.\(id)"].firstMatch
    }

    func testTravelTabOpensSpaceAndBabyCareButtonCloses() throws {
        let app = launch()
        let bar = babyCareBar(app)
        XCTAssertTrue(bar.waitForExistence(timeout: 20))
        XCTAssertTrue(bar.buttons["여행"].exists)
        XCTAssertFalse(bar.buttons["건강"].exists, "건강은 더 보기 안으로")
        XCTAssertFalse(bar.buttons["설정"].exists, "설정은 더 보기 안으로")
        shot(app, "flow_babycare_bar")

        bar.buttons["여행"].tap()
        XCTAssertTrue(travelTab(app, "home").waitForExistence(timeout: 10))
        for id in ["home", "plan", "bookings", "prep"] {
            XCTAssertTrue(travelTab(app, id).exists, id)
        }
        XCTAssertTrue(travelTab(app, "home").isSelected, "처음엔 홈")
        let back = app.buttons["베이비케어로 돌아가기"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        // 전체 화면 아래에 베이비케어 바가 남아 있어도(시스템 표시 방식) 손님은 누를 수 없어야 한다 — 가려졌나로 잰다.
        XCTAssertFalse(babyCareBar(app).buttons["더 보기"].isHittable, "여행 공간이 떠 있는 동안 베이비케어 바는 가려진다")
        shot(app, "flow_travel_space")

        travelTab(app, "prep").tap()
        XCTAssertTrue(travelTab(app, "prep").isSelected)
        XCTAssertTrue(back.exists)
        shot(app, "flow_travel_prep_tab")
        back.tap()

        XCTAssertTrue(babyCareBar(app).waitForExistence(timeout: 5))
        XCTAssertFalse(travelTab(app, "home").exists)
        shot(app, "flow_back_to_babycare")
    }

    func testMoreShowsHealthAndSettingsWithBackButton() throws {
        let app = launch()
        let bar = babyCareBar(app)
        XCTAssertTrue(bar.waitForExistence(timeout: 20))
        let more = bar.buttons["더 보기"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        // 막 켜진 직후(홈이 자리 잡는 중)의 탭은 칸 바꾸기가 먹지 않을 때가 있다 → 목록이 안 보이면 한 번 더 누른다.
        let health = app.buttons["건강"].firstMatch
        for _ in 0..<3 where !health.exists {
            more.tap()
            _ = health.waitForExistence(timeout: 3)
        }
        shot(app, "flow_more_after_tap")
        XCTAssertTrue(health.exists)
        XCTAssertTrue(app.buttons["설정"].firstMatch.exists)
        shot(app, "flow_more_list")

        health.tap()
        XCTAssertTrue(app.navigationBars["건강"].waitForExistence(timeout: 5))
        let back = app.navigationBars.buttons["더 보기"]
        XCTAssertTrue(back.exists)
        shot(app, "flow_more_health")
        back.tap()

        let settings = app.buttons["설정"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["여행 준비"].exists, "설정의 여행 준비 줄은 뺐다")
        shot(app, "flow_more_settings")
        app.navigationBars.buttons["더 보기"].tap()
        XCTAssertTrue(app.buttons["건강"].firstMatch.waitForExistence(timeout: 5))
    }
}
