import XCTest

/// 임신 모드 진입 플로우 E2E — 빌드 56의 실제 버그(AddBabyView orphan)
/// 같은 회귀를 막기 위한 핵심 어설션.
final class PregnancyFlowTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Onboarding (empty state)

    /// 첫 사용자: 아기 없음 → onboardingView → "아기 등록하기" 버튼 노출
    @MainActor
    func test_onboarding_emptyState_showsRegisterButton() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_NO_BABY"]
        app.launch()

        let registerButton = app.buttons["아기 등록하기"]
        XCTAssertTrue(
            registerButton.waitForExistence(timeout: 5),
            "onboardingView의 '아기 등록하기' 버튼이 노출되어야 함"
        )
    }

    /// onboarding → "아기 등록하기" 탭 → AddBabyView 열림 → "아직 태어나지 않았나요?" 진입점 가시
    @MainActor
    func test_onboarding_addBaby_showsPregnancyEntry() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_NO_BABY"]
        app.launch()

        let registerButton = app.buttons["아기 등록하기"]
        XCTAssertTrue(registerButton.waitForExistence(timeout: 5))
        registerButton.tap()

        // AddBabyView 열린 뒤 임신 진입점 체크
        let pregnancyEntry = app.buttons["pregnancyEntryButton"]
        XCTAssertTrue(
            pregnancyEntry.waitForExistence(timeout: 3),
            "AddBabyView에 임신 모드 진입점 '아직 태어나지 않았나요?'이 노출되어야 함 (빌드 56 회귀 방지)"
        )
    }

    // MARK: - Settings path (existing user)

    /// 기존 아기 있음 → 설정 탭 → "아기 추가" → AddBabyView → 임신 진입점 확인
    @MainActor
    func test_settings_addBaby_showsPregnancyEntry() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_TAB=4"] // 설정 탭
        app.launch()

        // "아기 추가" 행 탭
        let addBabyRow = app.buttons["settingsAddBabyButton"]
        XCTAssertTrue(
            addBabyRow.waitForExistence(timeout: 5),
            "설정 탭에 '아기 추가' 행 존재해야 함"
        )
        addBabyRow.tap()

        let pregnancyEntry = app.buttons["pregnancyEntryButton"]
        XCTAssertTrue(
            pregnancyEntry.waitForExistence(timeout: 3),
            "설정→아기 추가 경로에서도 임신 모드 진입점 노출되어야 함"
        )
    }

    // MARK: - Pregnancy entry opens registration view

    /// 임신 진입점 탭 → PregnancyRegistrationView 열림 (navigationTitle "임신 등록")
    @MainActor
    func test_pregnancyEntry_opensRegistrationView() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_NO_BABY"]
        app.launch()

        app.buttons["아기 등록하기"].tap()

        let pregnancyEntry = app.buttons["pregnancyEntryButton"]
        XCTAssertTrue(pregnancyEntry.waitForExistence(timeout: 3))
        pregnancyEntry.tap()

        // navigationTitle "임신 등록" 확인
        let title = app.navigationBars["임신 등록"]
        XCTAssertTrue(
            title.waitForExistence(timeout: 3),
            "임신 진입점 탭 시 PregnancyRegistrationView (title='임신 등록')가 열려야 함"
        )
    }

    // MARK: - ContentView gating

    /// UI_TESTING 기본 모드 (mock baby 있음) → mainTabView 진입 확인
    @MainActor
    func test_appLaunch_withMockBaby_showsMainTab() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()

        // 탭바 존재 확인 (홈/기록/+/건강/설정)
        let homeTab = app.tabBars.buttons["홈"]
        XCTAssertTrue(
            homeTab.waitForExistence(timeout: 5),
            "mock baby 있을 때 mainTabView(홈 탭) 노출되어야 함"
        )
    }
}
