import XCTest
@testable import BabyCare

/// 통합 기록 P0 — ActivityDraft / ActivityDraftBuilder 순수 로직 단위 테스트.
/// 자체 클래스(도메인 분리 파일) — BabyCareTests.swift 첫 클래스 append 트랩 회피.
final class ActivityDraftBuilderTests: XCTestCase {

    // MARK: - Task 1: ActivityDraft

    func test_draft_defaults() {
        let d = ActivityDraft(babyId: "b1", type: .feedingBreast)
        XCTAssertEqual(d.feedingContent, .formula)
        XCTAssertFalse(d.wasManuallyAdjusted)
        XCTAssertEqual(d.amountText, "")
    }

    // MARK: - Task 2: Builder — 타입별 필드 + 검증

    func test_build_bottle_requiresValidAmount() {
        var d = ActivityDraft(babyId: "b", type: .feedingBottle)
        d.amountText = "0"
        XCTAssertEqual(ActivityDraftBuilder.build(d), .failure(.invalidAmount(isPumping: false)))
        d.amountText = "120"
        let ok = try? ActivityDraftBuilder.build(d).get()
        XCTAssertEqual(ok?.amount, 120)
        XCTAssertEqual(ok?.feedingContent, .formula)
    }

    func test_build_breast_appliesSideAndDuration() {
        var d = ActivityDraft(babyId: "b", type: .feedingBreast)
        d.side = .right
        d.duration = 600
        d.startTime = Date(timeIntervalSince1970: 1000)
        let a = try? ActivityDraftBuilder.build(d).get()
        XCTAssertEqual(a?.side, .right)
        XCTAssertEqual(a?.duration, 600)
    }

    func test_build_temperature_boundaries() {
        var d = ActivityDraft(babyId: "b", type: .temperature)
        d.temperatureText = "50"
        XCTAssertEqual(ActivityDraftBuilder.build(d), .failure(.invalidTemperature))
        d.temperatureText = "37.2"
        XCTAssertEqual((try? ActivityDraftBuilder.build(d).get())?.temperature, 37.2)
    }

    func test_build_sleep_rejectsOver24h() {
        var d = ActivityDraft(babyId: "b", type: .sleep)
        d.duration = 90000
        d.wasManuallyAdjusted = false
        XCTAssertEqual(ActivityDraftBuilder.build(d), .failure(.sleepTooLong))
    }

    func test_build_pumping_amountAndSide() {
        var d = ActivityDraft(babyId: "b", type: .feedingPumping)
        d.amountText = "80"
        d.side = .both
        let a = try? ActivityDraftBuilder.build(d).get()
        XCTAssertEqual(a?.amount, 80)
        XCTAssertEqual(a?.side, .both)
    }

    func test_build_pumping_invalidAmount_pumpingMessage() {
        var d = ActivityDraft(babyId: "b", type: .feedingPumping)
        d.amountText = ""
        let result = ActivityDraftBuilder.build(d)
        XCTAssertEqual(result, .failure(.invalidAmount(isPumping: true)))
        if case .failure(let err) = result {
            XCTAssertTrue(err.message.contains("유축량"))   // 문구 보존(수유량 아님)
        }
    }

    func test_build_diaperDirty_stoolFields() {
        var d = ActivityDraft(babyId: "b", type: .diaperDirty)
        d.stoolColor = .yellow
        d.hasRash = true
        let a = try? ActivityDraftBuilder.build(d).get()
        XCTAssertEqual(a?.stoolColor, .yellow)
        XCTAssertEqual(a?.hasRash, true)
    }

    func test_build_unknown_fails() {
        let d = ActivityDraft(babyId: "b", type: .unknown)
        XCTAssertEqual(ActivityDraftBuilder.build(d), .failure(.unknownType))
    }

    func test_build_manualTimeAdjustment_setsStartAndEnd() {
        var d = ActivityDraft(babyId: "b", type: .sleep)
        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 4600)
        d.wasManuallyAdjusted = true
        d.startTime = start
        d.endTime = end
        d.duration = 3600
        let a = try? ActivityDraftBuilder.build(d).get()
        XCTAssertEqual(a?.startTime, start)
        XCTAssertEqual(a?.endTime, end)
        XCTAssertEqual(a?.duration, 3600)
    }

    // MARK: - Task 3: commit / persist (유축 타입 = 배지 훅 우회 → Firestore 비결합)

    @MainActor
    func test_commit_pumping_success_insertsAndSaves() async {
        let mock = MockActivityFirestore()
        let vm = ActivityViewModel(firestoreService: mock)
        var d = ActivityDraft(babyId: "b", type: .feedingPumping)
        d.amountText = "80"; d.side = .both
        let saved = await vm.commit(draft: d, userId: "owner", currentUserId: "me")
        XCTAssertEqual(saved?.amount, 80)
        XCTAssertEqual(saved?.createdBy, "me")   // 배지 path와 별개로 createdBy=본인
        XCTAssertEqual(vm.todayActivities.first?.amount, 80)
        XCTAssertEqual(mock.saveActivityCalls.count, 1)
        XCTAssertNil(vm.errorMessage)
    }

    @MainActor
    func test_commit_buildFailure_setsError_noSave() async {
        let mock = MockActivityFirestore()
        let vm = ActivityViewModel(firestoreService: mock)
        var d = ActivityDraft(babyId: "b", type: .feedingPumping)
        d.amountText = "0"   // 검증 실패
        let saved = await vm.commit(draft: d, userId: "u", currentUserId: "u")
        XCTAssertNil(saved)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(mock.saveActivityCalls.count, 0)
    }

    @MainActor
    func test_commit_offlineFallback_keepsActivity() async {
        let mock = MockActivityFirestore()
        mock.errorOnSave = NSError(domain: "test", code: 1)
        let vm = ActivityViewModel(firestoreService: mock)
        var d = ActivityDraft(babyId: "b", type: .feedingPumping)
        d.amountText = "80"; d.side = .both
        let saved = await vm.commit(draft: d, userId: "u", currentUserId: "u")
        XCTAssertNotNil(saved)                       // 큐잉 = 사용자 관점 성공
        XCTAssertEqual(vm.todayActivities.count, 1)  // 롤백 안 됨(오프라인 큐잉)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - Task 4: makeDraft

    @MainActor
    func test_makeDraft_capturesFormState() {
        let vm = ActivityViewModel(firestoreService: MockActivityFirestore())
        vm.selectedSide = .right
        vm.note = "hi"
        let d = vm.makeDraft(type: .feedingBreast, babyId: "b")
        XCTAssertEqual(d.side, .right)
        XCTAssertEqual(d.type, .feedingBreast)
        XCTAssertEqual(d.note, "hi")
    }

    @MainActor
    func test_makeDraft_manualAdjust_usesManualStart() {
        let vm = ActivityViewModel(firestoreService: MockActivityFirestore())
        let t = Date(timeIntervalSince1970: 5000)
        vm.isTimeAdjusted = true
        vm.manualStartTime = t
        let d = vm.makeDraft(type: .diaperWet, babyId: "b")
        XCTAssertEqual(d.startTime, t)
        XCTAssertTrue(d.wasManuallyAdjusted)
    }

    // MARK: - Task 5: 풀폼 saveActivity 위임 (중복 경고 보존 + 저장/리셋)

    @MainActor
    func test_saveActivity_duplicate_setsWarning() async {
        let vm = ActivityViewModel(firestoreService: MockActivityFirestore())
        var existing = Activity(babyId: "b", type: .diaperWet)
        existing.startTime = Date()
        vm.todayActivities = [existing]
        vm.isTimeAdjusted = true
        vm.manualStartTime = existing.startTime   // 동일 시각 → 중복
        await vm.saveActivity(userId: "u", currentUserId: "u", babyId: "b", type: .diaperWet)
        XCTAssertTrue(vm.showDuplicateWarning)
    }

    @MainActor
    func test_saveActivity_fullForm_pumping_savesAndResets() async {
        let mock = MockActivityFirestore()
        let vm = ActivityViewModel(firestoreService: mock)
        vm.amount = "90"
        vm.selectedSide = .both
        await vm.saveActivity(userId: "u", currentUserId: "me", babyId: "b", type: .feedingPumping)
        XCTAssertEqual(mock.saveActivityCalls.first?.amount, 90)
        XCTAssertEqual(vm.amount, "")   // resetForm 호출 확인
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - P1: RecordEntryRule (instant vs detail)

    func test_recordEntryRule_instantTypes() {
        // 입력 불필요 = 원탭 즉시(모유수유·이유식 포함 — 예전 그리드 속도)
        let instant: [Activity.ActivityType] = [.feedingBreast, .feedingSolid, .feedingSnack, .diaperWet, .diaperDirty, .diaperBoth, .bath]
        for t in instant {
            XCTAssertEqual(RecordEntryRule.mode(for: t), .instant, "\(t) should be instant")
        }
    }

    func test_recordEntryRule_detailTypes() {
        // 양·타이머·값 필요한 것만 시트
        let detail: [Activity.ActivityType] = [.feedingBottle, .feedingPumping, .sleep, .temperature, .medication]
        for t in detail {
            XCTAssertEqual(RecordEntryRule.mode(for: t), .detail, "\(t) should be detail")
        }
    }
}
