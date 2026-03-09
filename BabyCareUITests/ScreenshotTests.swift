import XCTest

final class ScreenshotTests: XCTestCase {

    @MainActor
    func testTakeScreenshots() throws {
        let dir = "/tmp/babycare_real_screenshots"
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true, attributes: nil)

        // 1) 대시보드 (홈, tab 0)
        launchAndCapture(tab: 0, name: "01_dashboard")

        // 2) 건강 (tab 3)
        launchAndCapture(tab: 3, name: "02_health")

        // 3) 기록/캘린더 (tab 1)
        launchAndCapture(tab: 1, name: "03_calendar")
    }

    @MainActor
    private func launchAndCapture(tab: Int, name: String) {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_TAB=\(tab)"]
        app.launch()

        // 알림 권한 다이얼로그 처리
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowBtn = springboard.buttons["허용"]
        if allowBtn.waitForExistence(timeout: 3) {
            allowBtn.tap()
        }

        // 앱 내 "확인" 다이얼로그 처리
        let confirmButton = app.buttons["확인"]
        if confirmButton.waitForExistence(timeout: 3) {
            confirmButton.tap()
        }

        Thread.sleep(forTimeInterval: 2)

        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let path = "/tmp/babycare_real_screenshots/\(name).png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
        print("📸 스크린샷 저장: \(path)")

        app.terminate()
    }
}
