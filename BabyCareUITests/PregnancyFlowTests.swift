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

    // MARK: - Cancel & dismiss behaviors

    /// PregnancyRegistrationView "취소" 탭 → sheet 닫힘, AddBabyView 유지
    @MainActor
    func test_pregnancyRegistration_cancel_returnsToAddBabyView() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_NO_BABY"]
        app.launch()

        app.buttons["아기 등록하기"].tap()
        let entry = app.buttons["pregnancyEntryButton"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.tap()

        // 임신 등록 navigation bar 확인
        let title = app.navigationBars["임신 등록"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))

        // 취소 탭
        title.buttons["취소"].tap()

        // AddBabyView (아기 등록) 네비게이션 바가 여전히 보여야 함
        let addBabyTitle = app.navigationBars["아기 등록"]
        XCTAssertTrue(
            addBabyTitle.waitForExistence(timeout: 3),
            "임신 등록 취소 후 AddBabyView로 돌아와야 함"
        )
    }

    /// AddBabyView "취소" 탭 → onboarding으로 돌아옴
    @MainActor
    func test_addBabyView_cancel_returnsToOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_NO_BABY"]
        app.launch()

        app.buttons["아기 등록하기"].tap()
        XCTAssertTrue(app.navigationBars["아기 등록"].waitForExistence(timeout: 3))

        app.navigationBars["아기 등록"].buttons["취소"].tap()

        let registerButton = app.buttons["아기 등록하기"]
        XCTAssertTrue(
            registerButton.waitForExistence(timeout: 3),
            "AddBabyView 취소 후 onboarding으로 돌아와야 함"
        )
    }

    // MARK: - PregnancyRegistration form elements

    /// PregnancyRegistrationView 핵심 form 요소 노출 확인
    @MainActor
    func test_pregnancyRegistration_formElements_present() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_NO_BABY"]
        app.launch()

        app.buttons["아기 등록하기"].tap()
        app.buttons["pregnancyEntryButton"].tap()

        XCTAssertTrue(app.navigationBars["임신 등록"].waitForExistence(timeout: 3))

        // 주요 form 요소 — 면책 배너 텍스트, 저장 버튼
        let disclaimer = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '일반적인 참고 자료'")
        ).firstMatch
        XCTAssertTrue(
            disclaimer.waitForExistence(timeout: 2),
            "면책 배너 노출되어야 함"
        )

        // 저장 버튼 존재
        let save = app.navigationBars["임신 등록"].buttons["저장"]
        XCTAssertTrue(save.exists, "저장 버튼 노출되어야 함")
    }
}
