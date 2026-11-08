import XCTest

/// 빈 여행에 일정을 처음부터 끝까지 손님처럼 넣고, 완성된 일정표를 읽는다.
/// 🩸 2026-11-06 빌드 113: 칸은 전부 재고 올렸는데 완성된 일정표는 안 봐서 「체크인 → 렌터카 → 출발」로 나갔다.
/// 시간표·지도만 고정하고(UI_TESTING_TRIP_EMPTY) 나머지는 전부 실제 화면을 누른다. 그림 = /tmp/babycare_screenshots/whole
final class TripWholeTripFlowTests: XCTestCase {
    private let dir = "/tmp/babycare_screenshots/whole"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    /// 시험 여행은 사흘 뒤 출발 — 날짜 칩 글자(「5.10(월)」).
    private func dayChip(_ offset: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M.d(E)"
        return f.string(from: Calendar.current.date(byAdding: .day, value: 3 + offset, to: Date()) ?? Date())
    }

    private func openEmptyTrip() -> XCUIApplication { openTrip("UI_TESTING_TRIP_EMPTY") }

    private func openTrip(_ kind: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_WITH_TRIP", kind]
        app.launch()
        let bar = app.tabBars.containing(.button, identifier: "더 보기").firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 20))
        let plan = app.buttons["travel.tab.plan"].firstMatch
        for _ in 0..<3 where !plan.exists {
            bar.buttons["여행"].tap()
            _ = plan.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(plan.exists, "여행 공간이 안 열린다")
        return app
    }

    private func tap(_ target: XCUIElement, until result: XCUIElement, _ failure: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(target.waitForExistence(timeout: 10), "누를 곳이 없다: \(failure)", file: file, line: line)
        for _ in 0..<3 where !result.exists {
            target.tap()
            _ = result.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(result.exists, failure, file: file, line: line)
    }

    /// 사라질 때까지 기다린다 — waitForExistence 는 지금 있으면 바로 참이라 닫히는 것을 못 잰다.
    private func gone(_ element: XCUIElement, timeout: TimeInterval = 4) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while element.exists, Date() < end { Thread.sleep(forTimeInterval: 0.2) }
        return !element.exists
    }

    private func reveal(_ app: XCUIApplication, _ element: XCUIElement) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
    }

    private func chip(_ app: XCUIApplication, _ label: String, at index: Int = 0, file: StaticString = #filePath, line: UInt = #line) {
        let c = app.buttons.matching(identifier: label).element(boundBy: index)
        XCTAssertTrue(c.waitForExistence(timeout: 5), "칩이 없다: \(label) \(index)", file: file, line: line)
        reveal(app, c)
        c.tap()
    }

    /// 「입력」을 눌러 시각 고르기 창을 열고 고른 뒤 「확인」.
    private func setTime(_ app: XCUIApplication, _ title: String, _ hour: Int, _ minute: Int, file: StaticString = #filePath, line: UInt = #line) {
        let input = app.buttons["time.\(title).input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5), "「\(title)」 입력이 없다", file: file, line: line)
        reveal(app, input)
        input.tap()
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.element(boundBy: 1).waitForExistence(timeout: 5), "시각 고르기가 안 열린다: \(title)", file: file, line: line)
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: String(format: "%02d", hour))
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: String(format: "%02d", minute))
        app.buttons["time.confirm"].firstMatch.tap()
        XCTAssertTrue(gone(wheels.element(boundBy: 1)), "시각 고르기가 안 닫힌다: \(title)", file: file, line: line)
    }

    private func save(_ app: XCUIApplication, _ title: String, action: String = "추가", file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[action].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), file: file, line: line)
        // 시각 고르기가 닫히는 순간에는 잠깐 꺼져 있다.
        let end = Date().addingTimeInterval(3)
        while !button.isEnabled, Date() < end { Thread.sleep(forTimeInterval: 0.2) }
        XCTAssertTrue(button.isEnabled, "「\(action)」이 안 눌린다: \(title)", file: file, line: line)
        button.tap()
        XCTAssertTrue(gone(app.navigationBars[title]), "창이 안 닫힌다: \(title)", file: file, line: line)
    }

    private func openEntry(_ app: XCUIApplication, _ kind: String) {
        let add = app.buttons["\(kind) 추가"].firstMatch
        tap(app.buttons["travel.tab.bookings"].firstMatch, until: add, "예약 칸에 「\(kind) 추가」가 없다")
        tap(add, until: app.navigationBars["\(kind) 추가"], "「\(kind) 추가」 창이 안 열린다")
    }

    private func addFlight(_ app: XCUIApplication, _ number: String, day: Int, fill: () -> Void = {}) {
        openEntry(app, "항공편")
        app.textFields.firstMatch.tap()
        app.typeText(number + "\n")
        chip(app, dayChip(day))
        XCTAssertTrue(app.staticTexts["인천공항 시간표에서 찾았어요"].waitForExistence(timeout: 8), "\(number) 를 시간표에서 못 찾는다")
        fill()
        save(app, "항공편 추가")
    }

    private func pickHotel(_ app: XCUIApplication, _ name: String) {
        app.buttons["숙소 검색"].firstMatch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.typeText(name)
        let typed = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "\(name), 직접 입력")).firstMatch
        XCTAssertTrue(typed.waitForExistence(timeout: 5), "직접 입력 줄이 없다")
        typed.tap()
    }

    private func enterEverything(_ app: XCUIApplication) {
        addFlight(app, "KE999", day: 0) { setTime(app, "간사이공항 도착", 17, 0) }
        addFlight(app, "KE998", day: 4)  // 간사이 출발 시각은 일부러 비운다

        openEntry(app, "숙소")
        pickHotel(app, "교토 숙소")
        chip(app, dayChip(0), at: 0)
        setTime(app, "체크인 시작", 15, 0)
        setTime(app, "체크인 마감", 22, 0)
        chip(app, dayChip(2), at: 1)
        setTime(app, "시각", 10, 0)
        save(app, "숙소 추가")

        openEntry(app, "숙소")
        pickHotel(app, "오사카 숙소")
        chip(app, dayChip(2), at: 0)
        setTime(app, "체크인 시작", 15, 0)
        chip(app, dayChip(4), at: 1)  // 체크아웃 시각은 일부러 비운다
        save(app, "숙소 추가")

        openEntry(app, "렌터카")
        app.textFields["업체 이름"].firstMatch.tap()
        app.typeText("시험 렌터카\n")
        chip(app, "간사이공항", at: 0)
        setTime(app, "인수 시각", 18, 0)
        chip(app, "간사이공항", at: 1)
        setTime(app, "반납 시각", 10, 0)
        shot(app, "rental")
        save(app, "렌터카 추가")
    }

    private func openDay(_ app: XCUIApplication, _ number: Int) {
        let add = app.buttons["일정 추가"].firstMatch
        if !add.exists { tap(app.buttons["travel.tab.plan"].firstMatch, until: add, "일정 칸이 안 열린다") }
        let chip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(number)일차")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()
        Thread.sleep(forTimeInterval: 0.6)
    }

    /// 글자가 위에서 아래로 이 순서로 보이나.
    private func assertReads(_ app: XCUIApplication, _ texts: [String], file: StaticString = #filePath, line: UInt = #line) {
        var bottom = -CGFloat.infinity
        for text in texts {
            let element = app.staticTexts[text].firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 8), "안 보인다: \(text)", file: file, line: line)
            XCTAssertGreaterThan(element.frame.minY, bottom, "순서가 틀리다: \(text)", file: file, line: line)
            bottom = element.frame.minY
        }
    }

    /// 스크롤하며 글자가 이 차례로 나오나 — 긴 하루는 한 화면에 안 들어온다.
    private func assertReadsDown(_ app: XCUIApplication, _ texts: [String], name: String, file: StaticString = #filePath, line: UInt = #line) {
        var page = 0
        shot(app, "\(name)_\(page)")
        for text in texts {
            let element = app.staticTexts[text].firstMatch
            var tries = 0
            while !(element.exists && element.isHittable) && tries < 8 {
                app.swipeUp(velocity: .slow)
                Thread.sleep(forTimeInterval: 0.4)
                tries += 1
                page += 1
                shot(app, "\(name)_\(page)")
            }
            XCTAssertTrue(element.exists, "안 보인다: \(text)", file: file, line: line)
        }
    }

    // 아기 기록까지 있는 여행 — 손님이 실제로 보는 일정표(시안 일정 판).
    func testFullDayReadsLikeTheDesign() throws {
        let app = openTrip("UI_TESTING_TRIP_FULL")
        openDay(app, 1)
        XCTAssertTrue(app.staticTexts["깬 뒤 바로, 이후 약 3시간 50분마다"].waitForExistence(timeout: 8), "아기 줄이 안 나온다")
        assertReadsDown(app, ["깬 뒤 바로, 이후 약 3시간 50분마다", "7일 중 6일, 탑승 시간과 겹쳐요", "인천 출발 KE999", "비행 중이에요",
                              "간사이 도착, 입국", "렌터카 인수", "교토 숙소까지 차로 약 1시간 36분, 구글지도 기준", "운전 중이에요",
                              "교토 숙소 도착", "밤잠 시간과 맞닿아요", "숙소 도착 뒤"], name: "full1")
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        openDay(app, 5)
        XCTAssertTrue(app.staticTexts["깬 뒤 바로, 이후 약 3시간 50분마다"].waitForExistence(timeout: 8))
        assertReadsDown(app, ["오사카 숙소 체크아웃", "간사이공항까지 차로 약 44분, 구글지도 기준", "최근 7일 동안 매일, 운전 시간과 겹쳐요",
                              "렌터카 반납", "간사이 출발 KE998", "인천 도착"], name: "full5")
        app.buttons["travel.tab.home"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["밤잠 20:10과 맞닿아요"].waitForExistence(timeout: 8), "홈 아이 칩이 안 맞는다")
        shot(app, "full_home")
        app.buttons["travel.tab.bookings"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)
        assertReadsDown(app, ["간사이공항 도착", "렌터카 인수", "밤잠 시간과 맞닿아요", "교토 숙소 도착"], name: "full_bookings")
    }

    // 🩸 「입력」만 누르고 고르지 않으면 아무 시각도 저장되지 않는다(처음 값이 저장되던 길).
    func testCancellingTheTimePickerSavesNothing() throws {
        let app = openEmptyTrip()
        openEntry(app, "숙소")
        let input = app.buttons["time.체크인 시작.input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        let cancel = app.buttons["취소"].firstMatch
        XCTAssertTrue(app.pickerWheels.element(boundBy: 1).waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(gone(app.pickerWheels.element(boundBy: 1)), "시각 고르기가 안 닫힌다")
        XCTAssertEqual(input.label, "체크인 시작 입력", "취소했는데 시각이 들어갔다")
    }

    func testEnteringTheWholeTripReadsLikeARealTrip() throws {
        let app = openEmptyTrip()
        enterEverything(app)

        openDay(app, 1)
        shot(app, "day1")
        assertReads(app, ["인천 출발 KE999", "간사이 도착, 입국", "렌터카 인수", "교토 숙소까지 차로 약 1시간 36분, 구글지도 기준", "교토 숙소 도착"])
        assertReads(app, ["15:10", "17:00", "18:00", "19:36"])
        XCTAssertTrue(app.staticTexts["빨라야"].exists)
        XCTAssertTrue(app.staticTexts["체크인 15:00~22:00"].exists)
        XCTAssertTrue(app.staticTexts["교토 숙소"].exists, "오늘 밤 숙소가 안 보인다")

        openDay(app, 2)
        shot(app, "day2")
        XCTAssertTrue(app.staticTexts["교토 숙소"].waitForExistence(timeout: 5), "묵는 날에 숙소가 안 보인다")

        openDay(app, 3)
        shot(app, "day3")
        assertReads(app, ["교토 숙소 체크아웃", "오사카 숙소까지 차로 약 1시간 6분, 구글지도 기준", "오사카 숙소 체크인"])

        openDay(app, 4)
        shot(app, "day4")
        XCTAssertTrue(app.staticTexts["오사카 숙소"].waitForExistence(timeout: 5), "묵는 날에 숙소가 안 보인다")

        openDay(app, 5)
        shot(app, "day5_open")
        assertReads(app, ["오사카 숙소 체크아웃", "간사이공항까지 차로 약 44분, 구글지도 기준", "렌터카 반납", "간사이 출발 KE998", "인천 도착"])
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "미정")).count, 2, "체크아웃·출발 시각이 미정이어야 한다")
        XCTAssertFalse(app.staticTexts["00:00"].exists, "🩸 00:00 이 나오면 안 된다")

        let prep = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "오는 편 마감: 출발 시각을 넣으면 나와요")).firstMatch
        tap(app.buttons["travel.tab.prep"].firstMatch, until: prep, "준비 칸에 아직 못 낸 마감이 안 보인다")
        shot(app, "prep_open")

        // 일정에서 바로 시각을 넣으면 일정과 마감이 같이 맞춰진다.
        openDay(app, 5)
        let fill = app.buttons.matching(identifier: "itinerary.fillTime").element(boundBy: 1)
        tap(fill, until: app.navigationBars["항공편 수정"], "「시각 넣기」가 그 예약을 안 연다")
        XCTAssertTrue(app.staticTexts["인천공항 시간표에서 찾았어요"].waitForExistence(timeout: 8))
        setTime(app, "간사이공항 출발", 11, 55)
        save(app, "항공편 수정", action: "저장")
        XCTAssertTrue(app.staticTexts["11:55"].waitForExistence(timeout: 5), "넣은 시각이 일정에 안 나온다")
        shot(app, "day5_filled")

        let deadline = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "오는 편 마감 ")).firstMatch
        tap(app.buttons["travel.tab.prep"].firstMatch, until: deadline, "오는 편 마감이 안 생긴다")
        shot(app, "prep_filled")

        let going = app.staticTexts["간사이공항 도착"].firstMatch
        tap(app.buttons["travel.tab.bookings"].firstMatch, until: going, "가는 편이 가는 날 줄에 없다")
        assertReads(app, ["간사이공항 도착", "렌터카 인수", "교토 숙소 도착"])
        shot(app, "bookings")

        let next = app.staticTexts["KE999 인천 → 간사이"].firstMatch
        tap(app.buttons["travel.tab.home"].firstMatch, until: next, "홈 다음 일정이 안 맞는다")
        assertReads(app, ["KE999 인천 → 간사이", "렌터카 인수", "교토 숙소 도착"])
        shot(app, "home")
    }
}
