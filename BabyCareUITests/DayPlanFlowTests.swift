import XCTest

/// 「우리 하루」 시간표 — 설정에서 들어가 짜는 화면까지 실제로 닿는지.
/// ⚠️ 저장·삭제의 **왕복**(Firestore)은 여기서 못 잰다 — `UI_TESTING` 은 인증을 흉내만 내서
///    규칙(`request.auth.uid == userId`)이 쓰기를 막는다. 넣고 지우는 **규칙**은 단위 테스트가 잰다
///    (`PlanEntryMutationTests`). 여기서는 **닿는지 · 그려지는지 · 열리는지**를 잰다.
final class DayPlanFlowTests: XCTestCase {

    private let screenshotDir = "/tmp/babycare_screenshots"

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(
            atPath: screenshotDir, withIntermediateDirectories: true, attributes: nil
        )
        // 실패해도 뒷단계 스크린샷을 남긴다 — 실패한 화면이 증거다.
        continueAfterFailure = true
    }

    @MainActor
    func testSettingsReachesDayPlanAndOpensTheSheet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_TAB=4"]
        app.launch()
        dismissDialogs(app)
        Thread.sleep(forTimeInterval: 2)

        // 1. 설정에 진입점이 있다 · 2. 눌러서 목록 화면으로 들어간다
        //    (중첩 NavigationStack 이면 여기서 깨진다)
        let opened = openDayPlan(app)
        capture(app, "10_settings_to_dayplan")
        XCTAssertTrue(opened, "설정에서 「우리 하루」로 들어가지 못했다")
        // `UI_TESTING` 은 인증을 흉내만 내서 Firestore 읽기가 거부된다 —
        // 즉 이 경로는 **불러오기 실패** 상태다. 그때 화면이 「없어요」라고 말하면 거짓이다.
        XCTAssertTrue(
            app.staticTexts["시간표를 불러오지 못했어요"].waitForExistence(timeout: 5),
            "불러오기가 실패했는데 실패 상태가 안 보인다"
        )
        XCTAssertFalse(
            app.staticTexts["아직 짜 둔 것이 없어요"].exists,
            "못 불러온 것을 「없어요」라고 말하고 있다"
        )
        XCTAssertTrue(app.buttons["다시 시도"].exists, "되돌아갈 길(다시 시도)이 없다")
        capture(app, "11_dayplan_load_failed")

        // 3. 「시간표에 추가」 가 시트를 연다
        XCTAssertTrue(
            tapUntil(app, label: "시간표에 추가", until: app.staticTexts["고정 시각"]),
            "「시간표에 추가」를 눌러도 시트가 열리지 않는다"
        )
        capture(app, "12_dayplan_sheet")

        // 4. 세 방식이 모두 보인다
        for kind in ["첫 기록부터 주기", "고정 시각", "앞 일 뒤에 이어서"] {
            XCTAssertTrue(
                app.staticTexts[kind].waitForExistence(timeout: 3),
                "시트에 「\(kind)」 가 없다"
            )
        }
        // 5. 제목이 비었으면 저장이 안 눌린다
        let save = app.buttons["시간표에 넣기"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 3), "저장 버튼이 없다")
        XCTAssertFalse(save.isEnabled, "제목이 비었는데 저장이 눌린다")

        app.terminate()
    }

    // MARK: - Helpers

    /// 설정에서 「우리 하루」를 찾아 눌러 목록 화면까지 연다.
    /// 🩸 한 번의 tap 이 안 먹는 일이 있었다(시뮬레이터 · 목록이 아직 정착 중) — 눌린 걸
    ///    「내비게이션 바가 떴나」로 확인하고, 안 떴으면 다시 누른다. 통과가 들쭉날쭉하면 게이트가 아니다.
    @MainActor
    private func openDayPlan(_ app: XCUIApplication) -> Bool {
        for attempt in 0..<4 {
            let row = findDayPlanRow(app)
            if row.exists && row.isHittable {
                row.tap()
            } else if row.exists {
                row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            } else {
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }
            if app.navigationBars["우리 하루"].waitForExistence(timeout: 5) { return true }
            print("[DayPlan] tap \(attempt + 1) 회차가 안 먹었다 — 다시 시도")
            Thread.sleep(forTimeInterval: 1)
        }
        return false
    }

    /// 라벨로 누르고, **결과가 나타날 때까지** 다시 누른다.
    /// 🩸 SwiftUI List 안의 `.buttonStyle(.plain)` 행은 첫 tap 이 흘러가는 일이 있다.
    @MainActor
    private func tapUntil(_ app: XCUIApplication, label: String, until target: XCUIElement) -> Bool {
        for attempt in 0..<4 {
            let cell = app.cells.containing(.staticText, identifier: label).firstMatch
            let button = app.buttons[label].firstMatch
            let element = cell.exists ? cell : button
            guard element.waitForExistence(timeout: 3) else { return false }
            if element.isHittable {
                element.tap()
            } else {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            if target.waitForExistence(timeout: 4) { return true }
            print("[DayPlan] 「\(label)」 tap \(attempt + 1) 회차가 안 먹었다 — 다시 시도")
            Thread.sleep(forTimeInterval: 1)
        }
        return false
    }

    @MainActor
    private func findDayPlanRow(_ app: XCUIApplication) -> XCUIElement {
        for _ in 0..<6 {
            let cell = app.cells.containing(.staticText, identifier: "우리 하루").firstMatch
            if cell.exists { return cell }
            let button = app.buttons["우리 하루"].firstMatch
            if button.exists { return button }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        return app.cells.containing(.staticText, identifier: "우리 하루").firstMatch
    }

    @MainActor
    private func dismissDialogs(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["허용", "Allow", "OK"] {
            let btn = springboard.buttons[label]
            if btn.waitForExistence(timeout: 2) { btn.tap() }
        }
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "\(screenshotDir)/\(name).png"))
    }
}
