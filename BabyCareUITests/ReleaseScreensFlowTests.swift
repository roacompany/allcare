import XCTest

/// 2.8.14 에서 손님 눈에 바뀌는 화면·동작을 실제 앱으로 잰다 — 그림 = /tmp/babycare_screenshots/release_2814
/// - 위젯 주소: 앱이 꺼진 채 눌렀을 때(`app.open` = 그 주소로 앱을 띄운다) · 다른 칸에 있을 때
///   (🩸 2026-11-14: 수면 위젯이 수유 칸을 열고, 요약·성장 위젯은 앱만 열고, 꺼진 앱에선 늘 홈이었다)
/// - 가족 초대 받는 칸: 영문 자판 · 소문자로 쳐도 대문자 코드
/// - 이유식 가이드: 후기 단계 그림(iOS 17 에 없는 이름이라 빈칸이던 것을 바꿈)
/// CI 는 UI 시험을 안 태운다 — 올리기 전에 직접 돌린다(시뮬레이터 주소 열기 `simctl openurl` 은 확인 창에 막힌다).
final class ReleaseScreensFlowTests: XCTestCase {

    private let dir = "/tmp/babycare_screenshots/release_2814"

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    /// 기기 화면 전체를 찍는다 — 자판까지 담으려고(앱 창만 찍으면 자판이 빠질 수 있다).
    private func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeApp(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"] + extra
        return app
    }

    /// 기록 시트의 칸 막대에서 그 칸이 골라졌나(칸 단추는 고르면 isSelected 를 단다 · 홈의 같은 이름 단추는 안 단다).
    private func selectedRecordingTab(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@ AND selected == true", title)).firstMatch
    }

    // MARK: - 위젯 주소 — 앱이 꺼진 채(가장 흔한 경우)

    func test_coldStart_recordWidgets_openTheirCategory() throws {
        for (path, tab) in [("record/sleep", "수면"), ("record/diaper", "기저귀"), ("record/feeding", "수유")] {
            let app = makeApp()
            app.open(try XCTUnwrap(URL(string: "babycare://\(path)")))
            XCTAssertTrue(selectedRecordingTab(app, tab).waitForExistence(timeout: 15),
                          "꺼진 앱에서 \(path) 위젯이 「\(tab)」 칸을 안 열었다")
            shot("cold_\(path.replacingOccurrences(of: "/", with: "_"))")
            app.terminate()
        }
    }

    func test_coldStart_growthWidget_opensGrowth() throws {
        let app = makeApp()
        app.open(try XCTUnwrap(URL(string: "babycare://health/growth")))
        XCTAssertTrue(app.navigationBars["성장 기록"].waitForExistence(timeout: 15), "꺼진 앱에서 성장 위젯이 성장 기록을 안 열었다")
        shot("cold_health_growth")
        app.terminate()
    }

    // MARK: - 위젯 주소 — 다른 칸에 있을 때

    func test_warm_summaryAndGrowthWidgets_fromCalendar() throws {
        let app = makeApp(["UI_TESTING_TAB=1"]) // 캘린더에서 시작
        app.launch()
        let home = app.tabBars.buttons["홈"]
        XCTAssertTrue(home.waitForExistence(timeout: 15))
        XCTAssertFalse(home.isSelected, "시작이 캘린더가 아니면 이 시험은 아무것도 재지 않는다")

        app.open(try XCTUnwrap(URL(string: "babycare://dashboard")))
        XCTAssertTrue(app.tabBars.buttons["홈"].waitForExistence(timeout: 10))
        let homeSelected = expectation(for: NSPredicate(format: "selected == true"), evaluatedWith: app.tabBars.buttons["홈"])
        wait(for: [homeSelected], timeout: 10)
        shot("warm_dashboard_home")

        app.open(try XCTUnwrap(URL(string: "babycare://health/growth")))
        XCTAssertTrue(app.navigationBars["성장 기록"].waitForExistence(timeout: 15), "성장 위젯이 성장 기록을 안 열었다")
        shot("warm_health_growth")
    }

    // MARK: - 가족 초대 받는 칸

    func test_inviteCodeField_asciiKeyboard_uppercasesTypedCode() throws {
        let app = makeApp()
        app.launch()
        openSettings(app)
        let row = app.staticTexts["가족 공유"]
        for _ in 0..<4 where !row.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let field = app.textFields["6자리 코드"]
        for _ in 0..<4 where !(field.exists && field.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(field.waitForExistence(timeout: 10), "초대 코드 칸을 못 찾았다")
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "자판이 안 떴다")
        field.typeText("ab2345")
        XCTAssertEqual(field.value as? String, "AB2345", "소문자로 친 코드가 대문자 코드가 안 됐다")
        shot("invite_code_field_keyboard")
    }

    // MARK: - 이유식 가이드 — 후기 단계 그림

    func test_babyFoodGuide_showsLateStage() throws {
        let app = makeApp()
        app.launch()
        openHealth(app)
        shot("more_health")
        let guide = app.staticTexts["이유식 가이드"]
        for _ in 0..<5 where !guide.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        guide.tap()
        let late = app.staticTexts["후기 이유식"]
        for _ in 0..<5 where !late.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(late.waitForExistence(timeout: 10), "후기 이유식 단계를 못 찾았다")
        shot("baby_food_guide_late")
    }

    // MARK: - 길 찾기(여행 칸이 켜진 판 = 건강·설정이 「더 보기」 안)

    private func openMore(_ app: XCUIApplication) {
        let more = app.tabBars.buttons["더 보기"]
        XCTAssertTrue(more.waitForExistence(timeout: 15))
        let health = app.buttons["건강"].firstMatch
        // 막 켜진 직후의 첫 누름이 먹지 않을 때가 있다(build-gotchas) — 목록이 안 보이면 다시 누른다
        for _ in 0..<3 where !health.exists {
            more.tap()
            _ = health.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(health.exists, "「더 보기」 목록이 안 열렸다")
    }

    private func openHealth(_ app: XCUIApplication) {
        openMore(app)
        app.buttons["건강"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["건강"].waitForExistence(timeout: 10))
    }

    private func openSettings(_ app: XCUIApplication) {
        openMore(app)
        app.buttons["설정"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 10))
    }
}
