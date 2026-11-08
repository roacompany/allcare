import XCTest

/// 장소 검색(캔버스 Search-Move · Search-Hotel) — 손님처럼 눌러서 넣는 창까지 가고, 실제 자판을 띄워 잰다.
/// 🩸 2026-11-06 빌드 111·112: 후보를 칸 바로 밑에 그려서 아래쪽 칸은 후보 전부가 자판 밑이었다.
///    정지 그림 대조와 단위 시험은 자판이 없어 못 봤고, 흐름 시험은 여행이 없어 넣는 창에 못 갔다.
/// 공항 후보로 재는 까닭: 앱이 아는 목록이라 지도 응답(네트워크)이 없어도 늘 나온다.
final class TripPlaceSearchFlowTests: XCTestCase {
    private let dir = "/tmp/babycare_screenshots"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    private func travelTab(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.buttons["travel.tab.\(id)"].firstMatch
    }

    /// 로그인 없이 시험 여행으로 여행 공간을 연다.
    private func openTravel() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_WITH_TRIP"]
        app.launch()
        let bar = app.tabBars.containing(.button, identifier: "더 보기").firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 20))
        // 막 켜진 직후(홈이 자리 잡는 중)의 탭은 먹지 않을 때가 있다 → 안 열리면 한 번 더 누른다.
        let plan = travelTab(app, "plan")
        for _ in 0..<3 where !plan.exists {
            bar.buttons["여행"].tap()
            _ = plan.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(plan.exists, "여행 공간이 안 열린다")
        return app
    }

    /// 누르고 결과가 안 보이면 다시 누른다 — 칸을 막 바꾼 직후의 탭은 먹지 않을 때가 있다(TravelSpaceFlowTests 와 같은 처리).
    /// 세 번 눌러도 안 되면 실제 결함이다.
    private func tap(_ target: XCUIElement, until result: XCUIElement, _ failure: String,
                     file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(target.waitForExistence(timeout: 10), "누를 곳이 없다: \(failure)", file: file, line: line)
        for _ in 0..<3 where !result.exists {
            target.tap()
            _ = result.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(result.exists, failure, file: file, line: line)
    }

    private func openMoveEntry(_ app: XCUIApplication) {
        let add = app.buttons["일정 추가"].firstMatch
        tap(travelTab(app, "plan"), until: add, "일정 칸에 「일정 추가」가 없다")
        tap(add, until: app.navigationBars["일정 추가"], "「일정 추가」 창이 안 열린다")
    }

    private func openBookingEntry(_ app: XCUIApplication, _ kind: String) {
        let add = app.buttons["\(kind) 추가"].firstMatch
        tap(travelTab(app, "bookings"), until: add, "예약 칸에 「\(kind) 추가」가 없다")
        tap(add, until: app.navigationBars["\(kind) 추가"], "「\(kind) 추가」 창이 안 열린다")
    }

    /// n 번째 「다른 곳 찾기」를 누른다(0 = 위쪽 칸 · 1 = 아래쪽 칸).
    private func tapFindElsewhere(_ app: XCUIApplication, at index: Int) {
        let chip = app.buttons.matching(identifier: "다른 곳 찾기").element(boundBy: index)
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "「다른 곳 찾기」 \(index) 가 없다")
        for _ in 0..<4 where !chip.isHittable { app.swipeUp() }
        chip.tap()
    }

    private func keyboard(_ app: XCUIApplication) -> XCUIElement {
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "찾기를 눌렀는데 자판이 안 올라온다")
        return keyboard
    }

    /// 후보 줄 — 「제목, 부제」로 읽힌다. 칩(「간사이공항」)·뒤쪽 창의 소요 시간 단추(「직접 입력, 감소」)와 안 헷갈리게 찾는다.
    private func row(_ app: XCUIApplication, _ subtitle: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", subtitle)).firstMatch
    }

    /// 손님이 볼 수 있나 — 있기만 한 게 아니라 자판 위에서 눌린다.
    private func assertAboveKeyboard(_ element: XCUIElement, _ keyboard: XCUIElement, _ what: String,
                                     file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(what) 후보가 없다", file: file, line: line)
        XCTAssertLessThanOrEqual(element.frame.maxY, keyboard.frame.minY, "\(what) 후보가 자판에 가렸다", file: file, line: line)
        XCTAssertTrue(element.isHittable, "\(what) 후보를 누를 수 없다", file: file, line: line)
    }

    // 일정 추가의 아래쪽 칸(도착지) — 빌드 112 에서 후보 전부가 자판 밑이던 자리.
    func testMoveLowerFieldCandidatesStayAboveTheKeyboardAndPickedAirportIsSelected() throws {
        let app = openTravel()
        openMoveEntry(app)
        shot(app, "place_move_entry")
        tapFindElsewhere(app, at: 1)
        let keys = keyboard(app)
        app.typeText("간사이")
        let airport = row(app, "関西国際空港")
        assertAboveKeyboard(airport, keys, "공항")
        assertAboveKeyboard(row(app, "간사이, 직접 입력"), keys, "직접 입력")
        shot(app, "place_move_search_kansai")
        airport.tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 1), "고른 뒤에는 자판이 내려간다")
        let picked = app.buttons.matching(identifier: "간사이공항").element(boundBy: 1)
        XCTAssertTrue(picked.waitForExistence(timeout: 5))
        XCTAssertTrue(picked.isSelected, "도착지에 고른 공항이 칩으로 선택돼야 한다")
        shot(app, "place_move_after_pick")
    }

    // 렌터카의 맨 아래 장소 칸(반납 장소) — 넣는 창이 가장 길어서 칸이 제일 아래에 있다.
    func testRentalReturnFieldCandidatesStayAboveTheKeyboard() throws {
        let app = openTravel()
        openBookingEntry(app, "렌터카")
        shot(app, "place_rental_entry")
        tapFindElsewhere(app, at: 1)
        let keys = keyboard(app)
        app.typeText("간사이")
        assertAboveKeyboard(row(app, "関西国際空港"), keys, "공항")
        shot(app, "place_rental_search_kansai")
    }

    // 지도에 없는 곳도 넣을 수 있고, 고른 곳이 칩으로 보인다.
    func testTypedPlaceBecomesASelectedChip() throws {
        let app = openTravel()
        openMoveEntry(app)
        tapFindElsewhere(app, at: 0)
        _ = keyboard(app)
        app.typeText("친척 집")
        let typed = row(app, "친척 집, 직접 입력")
        XCTAssertTrue(typed.waitForExistence(timeout: 5))
        typed.tap()
        let chip = app.buttons.matching(identifier: "친척 집").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "적어서 고른 곳이 칩으로 안 보인다")
        XCTAssertTrue(chip.isSelected)
        shot(app, "place_move_typed_chip")
    }

    // 숙소 칸은 누르면 찾기 화면 · 주소 칸은 없다(시안 Entry-Hotel).
    func testHotelFieldOpensSearchAndTypedNameComesBack() throws {
        let app = openTravel()
        openBookingEntry(app, "숙소")
        XCTAssertFalse(app.textFields["주소"].exists, "시안에 없는 주소 칸이 남아 있다")
        shot(app, "place_hotel_entry")
        let field = app.buttons["숙소 검색"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "「숙소 검색」 칸이 없다")
        field.tap()
        let keys = keyboard(app)
        app.typeText("간사이")
        let typed = row(app, "간사이, 직접 입력")
        assertAboveKeyboard(typed, keys, "직접 입력")
        XCTAssertFalse(row(app, "関西国際空港").exists, "숙소 찾기에 공항이 나오면 안 된다")
        shot(app, "place_hotel_search")
        typed.tap()
        let picked = app.buttons["간사이"].firstMatch
        XCTAssertTrue(picked.waitForExistence(timeout: 5), "고른 숙소 이름이 칸에 안 보인다")
        XCTAssertTrue(app.buttons["추가"].firstMatch.isEnabled, "숙소 이름이 들어갔는데 추가를 못 누른다")
        shot(app, "place_hotel_after_pick")
        // 다시 누르면 그 이름으로 열려 고칠 수 있다.
        picked.tap()
        XCTAssertTrue(row(app, "간사이, 직접 입력").waitForExistence(timeout: 5), "다시 열었는데 고른 이름이 없다")
    }

    // 숙소 찾기에는 숙소만 — 2026-11-06 실측: 「교토역」에 주차장·술집이 호텔보다 먼저 나왔다(시안 Search-Hotel 은 숙소만).
    // 지도 응답이 있어야 잴 수 있다 — 없으면 초록이 아니라 건너뜀으로 남긴다.
    func testHotelSearchOffersLodgingOnly() throws {
        let app = openTravel()
        openBookingEntry(app, "숙소")
        app.buttons["숙소 검색"].firstMatch.tap()
        _ = keyboard(app)
        app.typeText("교토역")
        try XCTSkipUnless(row(app, "〒").waitForExistence(timeout: 10), "지도 응답이 없다 — 네트워크가 있을 때만 잰다")
        Thread.sleep(forTimeInterval: 2)
        shot(app, "place_hotel_search_kyoto")
        XCTAssertFalse(row(app, "주차장").exists, "숙소 찾기에 주차장이 나온다")
        XCTAssertFalse(row(app, "술집").exists, "숙소 찾기에 술집이 나온다")
        XCTAssertTrue(row(app, "호텔").exists, "숙소 찾기에 호텔이 없다")
    }

    // 자판의 검색 키 — 자판을 내려 후보를 끝까지 보게 한다.
    func testSearchKeyLowersTheKeyboardAndKeepsTheCandidates() throws {
        let app = openTravel()
        openMoveEntry(app)
        tapFindElsewhere(app, at: 0)
        _ = keyboard(app)
        app.typeText("간사이\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "검색 키를 눌러도 자판이 안 내려간다")
        XCTAssertTrue(row(app, "関西国際空港").isHittable, "자판을 내렸더니 후보가 사라졌다")
    }

    // ✕ — 글자와 후보를 비우고 바로 다시 칠 수 있다.
    func testClearButtonEmptiesTheFieldAndTypingContinues() throws {
        let app = openTravel()
        openMoveEntry(app)
        tapFindElsewhere(app, at: 0)
        _ = keyboard(app)
        app.typeText("간사이")
        XCTAssertTrue(row(app, "関西国際空港").waitForExistence(timeout: 5))
        app.buttons["지우기"].firstMatch.tap()
        XCTAssertTrue(row(app, "関西国際空港").waitForNonExistence(timeout: 3), "지웠는데 후보가 남았다")
        app.typeText("나리타")
        XCTAssertTrue(row(app, "成田国際空港").waitForExistence(timeout: 5), "지운 뒤 다시 칠 수 없다")
    }

    // MARK: - 입력 화면의 글자 칸 전부 — 실제 자판을 띄워 치고, 칸이 자판에 안 가리는지 잰다.

    private func typeInField(_ app: XCUIApplication, placeholder: String, _ text: String, shotName: String) {
        let field = app.textFields[placeholder].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "「\(placeholder)」 칸이 없다")
        field.tap()
        let keys = keyboard(app)
        app.typeText(text)
        XCTAssertLessThanOrEqual(field.frame.maxY, keys.frame.minY, "「\(placeholder)」 칸이 자판에 가렸다")
        Thread.sleep(forTimeInterval: 1.5) // 화면이 자리 잡은 뒤의 그림을 남긴다.
        shot(app, shotName)
    }

    func testFlightNumberFieldStaysAboveTheKeyboard() throws {
        let app = openTravel()
        openBookingEntry(app, "항공편")
        typeInField(app, placeholder: "KE725", "OZ112", shotName: "entry_flight_typing")
    }

    func testRentalCompanyFieldStaysAboveTheKeyboard() throws {
        let app = openTravel()
        openBookingEntry(app, "렌터카")
        typeInField(app, placeholder: "업체 이름", "시험 렌터카", shotName: "entry_rental_typing")
    }

    func testTripEditCityFieldStaysAboveTheKeyboard() throws {
        let app = openTravel()
        let edit = app.buttons["travel.editTrip"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "홈에 「수정」이 없다")
        edit.tap()
        XCTAssertTrue(app.navigationBars["여행 수정"].waitForExistence(timeout: 5))
        app.buttons["도시 추가"].firstMatch.tap()
        typeInField(app, placeholder: "도시 이름", "후쿠오카", shotName: "entry_trip_edit_typing")
    }

    // 2026-11-06 실측: 「도시 추가」로 칸이 늘면 달력(지연 그리기)이 화면 밖으로 밀려 높이를 짐작하고, 「여행 기간」이 회색 띠 위로 올라탔다.
    func testTripEditPeriodKeepsItsPlaceWhenACityFieldOpens() throws {
        let app = openTravel()
        let edit = app.buttons["travel.editTrip"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "홈에 「수정」이 없다")
        edit.tap()
        XCTAssertTrue(app.navigationBars["여행 수정"].waitForExistence(timeout: 5))
        app.buttons["도시 추가"].firstMatch.tap()
        _ = keyboard(app)
        Thread.sleep(forTimeInterval: 1.5)
        let lastChip = app.buttons["요코하마"].firstMatch
        let period = app.staticTexts["여행 기간"].firstMatch
        XCTAssertTrue(lastChip.waitForExistence(timeout: 5))
        XCTAssertTrue(period.waitForExistence(timeout: 5))
        // 칸 아래 여백 16 + 띠 8 + 칸 위 여백 16 = 40
        XCTAssertGreaterThanOrEqual(period.frame.minY - lastChip.frame.maxY, 36, "「여행 기간」이 위 칸·띠로 올라탔다")
    }

    // 취소하면 고른 값이 그대로다.
    func testCancelKeepsTheEarlierChoice() throws {
        let app = openTravel()
        openMoveEntry(app)
        let first = app.buttons.matching(identifier: "간사이공항").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertTrue(first.isSelected)
        tapFindElsewhere(app, at: 0)
        _ = keyboard(app)
        app.typeText("다른 곳")
        // 뒤쪽 창도 조회에 잡힌다 — 찾기 창이 사라졌는지로 잰다.
        let search = app.navigationBars["출발지"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.buttons["취소"].tap()
        XCTAssertTrue(search.waitForNonExistence(timeout: 5), "취소했는데 찾기 화면이 안 닫혔다")
        XCTAssertTrue(first.isSelected, "찾기를 취소했는데 고른 곳이 풀렸다")
    }

    // 고른 칩을 다시 누르면 비운다 — 렌터카 장소는 안 넣어도 되는 칸이고 글자 칸이 없어 비울 길이 이것뿐이다.
    func testTappingTheSelectedChipClearsIt() throws {
        let app = openTravel()
        openBookingEntry(app, "렌터카")
        let chip = app.buttons.matching(identifier: "간사이공항").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()
        XCTAssertTrue(chip.isSelected)
        chip.tap()
        XCTAssertFalse(chip.isSelected, "고른 칩을 다시 눌러도 안 비워진다")
    }

    // 고른 곳을 보여 주는 자리는 칩뿐이다 — 긴 이름도 화면 안에 있어야 한다.
    func testLongPickedNameStaysInsideTheScreen() throws {
        let app = openTravel()
        openMoveEntry(app)
        tapFindElsewhere(app, at: 0)
        _ = keyboard(app)
        let long = "오사카 국제공항 남쪽 터미널 출발 게이트 앞 아기 휴게실 옆 편의점 맞은편 안내 데스크"
        app.typeText(long)
        let typed = row(app, "\(long), 직접 입력")
        XCTAssertTrue(typed.waitForExistence(timeout: 5))
        typed.tap()
        let chip = app.buttons.matching(identifier: long).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "긴 이름이 칩으로 안 보인다")
        // 좌우 여백 16 안에 있어야 한다(화면 끝에 닿으면 더 긴 이름은 잘린다).
        XCTAssertLessThanOrEqual(chip.frame.maxX, app.windows.firstMatch.frame.maxX - 15, "긴 이름 칩이 여백을 넘었다")
        shot(app, "place_move_long_chip")
    }

    // 고른 두 곳이 일정에 실제로 남는다(넣는 창 → 저장 → 일정 칸).
    func testAddedMoveShowsUpInThePlan() throws {
        let app = openTravel()
        openMoveEntry(app)
        app.buttons.matching(identifier: "시험 숙소").element(boundBy: 0).tap()
        tapFindElsewhere(app, at: 1)
        _ = keyboard(app)
        app.typeText("간사이")
        let airport = row(app, "関西国際空港")
        XCTAssertTrue(airport.waitForExistence(timeout: 10))
        airport.tap()
        let add = app.buttons["추가"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        shot(app, "place_move_before_add")
        add.tap()
        XCTAssertTrue(app.navigationBars["일정 추가"].waitForNonExistence(timeout: 5), "「추가」를 눌렀는데 창이 안 닫혔다")
        Thread.sleep(forTimeInterval: 1)
        shot(app, "place_move_after_add")
        let line = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "시험 숙소 → 간사이공항")).firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5), "넣은 일정이 일정 칸에 안 보인다")
    }

    // 저장된 숙소를 고치러 열면 칸에 그 이름이 있다.
    func testSavedHotelOpensWithItsNameInTheField() throws {
        let app = openTravel()
        // 홈·일정 칸에도 같은 제목이 있다 — 예약 칸으로 넘어간 뒤 지금 보이는 줄을 누른다.
        tap(travelTab(app, "bookings"), until: app.buttons["숙소 추가"].firstMatch, "예약 칸이 안 열린다")
        // 사이 이동 글자(「시험 숙소까지 …」)와 안 헷갈리게 줄 제목만 찾는다.
        let hotels = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ AND NOT (label CONTAINS %@)", "시험 숙소", "까지"))
        XCTAssertTrue(hotels.firstMatch.waitForExistence(timeout: 5), "예약 칸에 숙소가 없다")
        for _ in 0..<3 where !hotels.allElementsBoundByIndex.contains(where: { $0.isHittable && $0.frame.maxY < 700 }) { app.swipeUp() }
        let hotel = try XCTUnwrap(hotels.allElementsBoundByIndex.first { $0.isHittable && $0.frame.maxY < 700 }, "보이는 숙소 줄이 없다")
        // 🩸 2026-11-06: 제목 바로 밑 지도 링크가 탭을 끌어가 제목을 눌러도 지도가 열렸다 — 손가락처럼 제목 좌표를 누른다.
        let edit = app.navigationBars["숙소 수정"]
        for _ in 0..<3 where !edit.exists {
            hotel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            _ = edit.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(edit.exists, "숙소 줄을 눌렀는데 수정 창이 안 열린다")
        XCTAssertTrue(app.buttons["시험 숙소"].firstMatch.waitForExistence(timeout: 5), "수정 창 칸에 숙소 이름이 없다")
    }

    // 🩸 2026-11-06: 줄 안의 지도 링크가 줄 전체의 탭을 가져가 수정이 안 열렸다 → 링크는 제 자리만 눌린다. 링크 자체는 여전히 지도를 연다.
    func testMapLinkInTheRowStillOpensMaps() throws {
        let app = openTravel()
        let link = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "시험 숙소 구글지도에서 열기")).firstMatch
        tap(travelTab(app, "bookings"), until: link, "예약 칸에 숙소 지도 링크가 없다")
        link.tap()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10), "지도 링크를 눌렀는데 지도가 안 열린다")
    }

    // MARK: - 지도 후보를 누르는 길 — 지도 응답이 있어야 잰다(없으면 초록이 아니라 건너뜀).

    func testPickingAMapCandidateBecomesASelectedChip() throws {
        let app = openTravel()
        openMoveEntry(app)
        tapFindElsewhere(app, at: 0)
        _ = keyboard(app)
        app.typeText("후시미")
        let candidate = row(app, "후시미구, 일본 교토부")
        try XCTSkipUnless(candidate.waitForExistence(timeout: 10), "지도 응답이 없다 — 네트워크가 있을 때만 잰다")
        candidate.tap()
        let chip = app.buttons.matching(identifier: "후시미구").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "지도에서 고른 곳이 칩으로 안 보인다")
        XCTAssertTrue(chip.isSelected)
    }

    func testPickingAMapHotelFillsTheField() throws {
        let app = openTravel()
        openBookingEntry(app, "숙소")
        app.buttons["숙소 검색"].firstMatch.tap()
        _ = keyboard(app)
        app.typeText("호텔닛코오사카")
        let candidate = row(app, "〒542")
        try XCTSkipUnless(candidate.waitForExistence(timeout: 10), "지도 응답이 없다 — 네트워크가 있을 때만 잰다")
        candidate.tap()
        XCTAssertTrue(app.navigationBars["숙소"].waitForNonExistence(timeout: 15), "지도 후보를 눌렀는데 찾기 화면이 안 닫혔다")
        let filled = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "닛코")).firstMatch
        XCTAssertTrue(filled.waitForExistence(timeout: 5), "지도에서 고른 숙소가 칸에 안 보인다")
        XCTAssertTrue(app.buttons["추가"].firstMatch.isEnabled)
    }

    // 다시 열어도 지도가 또 찾아 준다(같은 글자를 다시 넣으면 지도가 새로 안 물을 수 있다).
    func testReopenedHotelSearchAsksTheMapAgain() throws {
        let app = openTravel()
        openBookingEntry(app, "숙소")
        app.buttons["숙소 검색"].firstMatch.tap()
        _ = keyboard(app)
        app.typeText("호텔닛코오사카")
        try XCTSkipUnless(row(app, "〒542").waitForExistence(timeout: 10), "지도 응답이 없다 — 네트워크가 있을 때만 잰다")
        row(app, "호텔닛코오사카, 직접 입력").tap()
        let field = app.buttons["호텔닛코오사카"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        XCTAssertTrue(row(app, "〒542").waitForExistence(timeout: 10), "다시 열었더니 지도 후보가 안 뜬다")
    }
}
