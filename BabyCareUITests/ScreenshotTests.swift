import XCTest

final class ScreenshotTests: XCTestCase {

    private let screenshotDir = "/tmp/babycare_screenshots"

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(
            atPath: screenshotDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
        continueAfterFailure = false
    }

    // MARK: - Main screenshot suite

    @MainActor
    func testCaptureAllScreenshots() throws {
        // Tab 0: Dashboard (홈)
        captureTab(tab: 0, name: "01_dashboard", waitSeconds: 3)

        // Tab 1: Calendar (캘린더)
        captureTab(tab: 1, name: "02_calendar", waitSeconds: 3)

        // Tab 3: Health (건강) — main health view
        captureTab(tab: 3, name: "03_health", waitSeconds: 3)

        // Tab 4: Settings (설정)
        captureTab(tab: 4, name: "04_settings", waitSeconds: 2)
    }

    // MARK: - Health sub-screens

    @MainActor
    func testHealthSubScreens() throws {
        // Vaccination (예방접종)
        captureHealthSubScreen(
            buttonLabel: "예방접종",
            name: "05_health_vaccination"
        )

        // Growth records (성장기록) — accessible via 성장 button in HealthView
        captureHealthSubScreen(
            buttonLabel: "성장",
            name: "06_health_growth"
        )

        // Allergy (알레르기)
        captureHealthSubScreen(
            buttonLabel: "알레르기",
            name: "07_health_allergy"
        )
    }

    // MARK: - Recording sheet

    @MainActor
    func testRecordingSheet() throws {
        let app = launchApp(tab: 0)
        dismissSystemDialogs(app: app)

        // Tap the center "+" tab (tag 2) to open RecordingView sheet
        let tabBar = app.tabBars.firstMatch
        // The plus button is the middle tab item ("기록하기")
        let plusButton = tabBar.buttons["기록하기"]
        if plusButton.waitForExistence(timeout: 5) {
            plusButton.tap()
            Thread.sleep(forTimeInterval: 1.5)
            captureScreen(app: app, name: "08_recording_sheet")
        } else {
            // Fallback: tap by index (middle of 5 tabs = index 2)
            let buttons = tabBar.buttons
            if buttons.count >= 3 {
                buttons.element(boundBy: 2).tap()
                Thread.sleep(forTimeInterval: 1.5)
                captureScreen(app: app, name: "08_recording_sheet")
            }
        }
        app.terminate()
    }

    // MARK: - Growth percentile chart

    @MainActor
    func testGrowthPercentileChart() throws {
        let app = launchApp(tab: 3)
        dismissSystemDialogs(app: app)
        Thread.sleep(forTimeInterval: 2)

        // Navigate to Growth sub-screen inside HealthView
        // Look for "성장" button/cell in the health tab
        let growthButton = app.buttons["성장"]
        let growthCell = app.cells.containing(.staticText, identifier: "성장").firstMatch
        if growthButton.waitForExistence(timeout: 4) {
            growthButton.tap()
        } else if growthCell.waitForExistence(timeout: 2) {
            growthCell.tap()
        }
        Thread.sleep(forTimeInterval: 2)
        captureScreen(app: app, name: "09_growth_percentile_chart")
        app.terminate()
    }
}

// MARK: - Private helpers

extension ScreenshotTests {

    /// Launch the app pointing to a specific tab index.
    @MainActor
    @discardableResult
    private func launchApp(tab: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_TAB=\(tab)"]
        app.launch()
        return app
    }

    /// Dismiss common system / app dialogs that block screenshots.
    @MainActor
    private func dismissSystemDialogs(app: XCUIApplication) {
        // Springboard system dialogs (notification permission, etc.)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["허용", "Allow", "OK"] {
            let btn = springboard.buttons[label]
            if btn.waitForExistence(timeout: 2) {
                btn.tap()
            }
        }

        // In-app confirmation dialogs
        for label in ["확인", "OK", "닫기"] {
            let btn = app.buttons[label]
            if btn.waitForExistence(timeout: 2) {
                btn.tap()
            }
        }
    }

    /// Core screenshot helper: captures, saves as PNG, and attaches to test report.
    @MainActor
    private func captureScreen(app: XCUIApplication, name: String) {
        let screenshot = app.windows.firstMatch.screenshot()

        // Attach to Xcode test results
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Write to disk
        let path = "\(screenshotDir)/\(name).png"
        let url = URL(fileURLWithPath: path)
        do {
            try screenshot.pngRepresentation.write(to: url)
            print("[Screenshot] Saved: \(path)")
        } catch {
            XCTFail("[Screenshot] Failed to save \(name): \(error)")
        }
    }

    /// Launch app on a tab, dismiss dialogs, wait, capture, and terminate.
    @MainActor
    private func captureTab(tab: Int, name: String, waitSeconds: TimeInterval) {
        let app = launchApp(tab: tab)
        dismissSystemDialogs(app: app)
        Thread.sleep(forTimeInterval: waitSeconds)
        captureScreen(app: app, name: name)
        app.terminate()
    }

    /// Launch on Health tab (3), wait for load, tap a named button, and capture.
    @MainActor
    private func captureHealthSubScreen(buttonLabel: String, name: String) {
        let app = launchApp(tab: 3)
        dismissSystemDialogs(app: app)
        Thread.sleep(forTimeInterval: 2.5)

        // Try button first, then static text cell
        let button = app.buttons[buttonLabel]
        let cell = app.cells.containing(.staticText, identifier: buttonLabel).firstMatch
        if button.waitForExistence(timeout: 4) {
            button.tap()
        } else if cell.waitForExistence(timeout: 2) {
            cell.tap()
        } else {
            // Just capture Health main view as fallback
            print("[Screenshot] '\(buttonLabel)' not found, capturing Health main view instead.")
        }

        Thread.sleep(forTimeInterval: 2)
        captureScreen(app: app, name: name)
        app.terminate()
    }
}
