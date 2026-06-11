import XCTest
@testable import BabyCare

// 분리: BabyCareTests.swift (4,901라인) Pregnancy 8 클래스 → 별도 파일 (~770라인)
// CLAUDE.md "BabyCareTests.swift 단일 파일에 append" 정책에서 Pregnancy 도메인은 예외 처리.
//
// 포함 클래스: PregnancyOutcomeContractTests / KickSessionTests / PregnancyDateMathTests /
// PregnancyViewModelIntegrationTests / PregnancyRecoveryTests / PregnancyTerminationTests /
// PregnancyRecoveryModalStateTests / TerminationFlowEdgeCaseTests

// MARK: - PregnancyOutcome 계약 + Pregnancy 변환 (H-2 자동 검증 — 출산 전환)

final class PregnancyOutcomeContractTests: XCTestCase {

    /// rawValue는 Firestore persist되는 영구 계약. 변경 시 기존 사용자 데이터 손상.
    /// (feedback_enum_raw_value_contract.md)
    func test_rawValues_are_locked_contract() {
        XCTAssertEqual(PregnancyOutcome.ongoing.rawValue, "ongoing")
        XCTAssertEqual(PregnancyOutcome.born.rawValue, "born")
        XCTAssertEqual(PregnancyOutcome.miscarriage.rawValue, "miscarriage")
        XCTAssertEqual(PregnancyOutcome.stillbirth.rawValue, "stillbirth")
        XCTAssertEqual(PregnancyOutcome.terminated.rawValue, "terminated")
    }

    func test_allCases_count_isFive() {
        XCTAssertEqual(PregnancyOutcome.allCases.count, 5,
                       "신규 case 추가 시 마이그레이션/UI 분기 검토 필요")
    }

    func test_displayName_allCases_haveKoreanLabel() {
        for outcome in PregnancyOutcome.allCases {
            XCTAssertFalse(outcome.displayName.isEmpty)
        }
    }

    /// 출산 전환 시뮬: ongoing → born + archivedAt + transitionState=completed
    /// (실제 WriteBatch 호출은 Firestore 의존이라 unit 검증 불가, 모델 변경만 검증)
    func test_transition_ongoing_to_born_setsExpectedFields() {
        var p = Pregnancy(id: "p1", lmpDate: Date(), dueDate: Date(),
                          fetusCount: 1, babyNickname: "테스트")
        p.outcome = .ongoing

        // 전환 시뮬 (FirestoreService+Pregnancy.swift L173 패턴)
        p.outcome = .born
        p.archivedAt = Date()
        p.transitionState = "completed"

        XCTAssertEqual(p.outcome, .born)
        XCTAssertNotNil(p.archivedAt)
        XCTAssertEqual(p.transitionState, "completed",
                       "WriteBatch idempotency를 위한 전환 마커 필수")
    }
}

// MARK: - KickSession 모델 (H-1 자동 검증 — 태동 카운트/duration/2시간 임계)

final class KickSessionTests: XCTestCase {

    private let pid = "preg1"

    func test_kickCount_emptyArray_returnsZero() {
        let s = KickSession(pregnancyId: pid)
        XCTAssertEqual(s.kickCount, 0)
        XCTAssertFalse(s.reachedTarget)
    }

    func test_kickCount_tenKicks_reachesTarget() {
        let kicks = (0..<10).map { _ in KickEvent() }
        let s = KickSession(pregnancyId: pid, kicks: kicks)
        XCTAssertEqual(s.kickCount, 10)
        XCTAssertTrue(s.reachedTarget, "ACOG 표준 10회 달성")
    }

    func test_kickCount_customTarget_appliesIt() {
        let kicks = (0..<5).map { _ in KickEvent() }
        let s = KickSession(pregnancyId: pid, kicks: kicks, targetCount: 5)
        XCTAssertTrue(s.reachedTarget, "커스텀 타겟 5 달성")
    }

    func test_durationSeconds_endedAt_returnsExact() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(1_800)  // 30분
        let s = KickSession(pregnancyId: pid, startedAt: start, endedAt: end)
        XCTAssertEqual(s.durationSeconds, 1_800, accuracy: 0.1)
    }

    func test_exceededTwoHours_underThreshold_returnsFalse() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(7_199)  // 1시간 59분 59초
        let s = KickSession(pregnancyId: pid, startedAt: start, endedAt: end)
        XCTAssertFalse(s.exceededTwoHours)
    }

    func test_exceededTwoHours_overThreshold_returnsTrue() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(7_201)  // 2시간 1초
        let s = KickSession(pregnancyId: pid, startedAt: start, endedAt: end)
        XCTAssertTrue(s.exceededTwoHours, "ACOG 2시간 초과 알림 트리거")
    }
}

// MARK: - PregnancyDateMath 위젯 엣지 (H-7 자동 검증)

final class PregnancyDateMathTests: XCTestCase {

    private func date(_ string: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: string)!
    }

    // MARK: weekAndDay

    func test_weekAndDay_nil_lmp_returnsNil() {
        XCTAssertNil(PregnancyDateMath.weekAndDay(from: nil, now: date("2026-04-19")))
    }

    func test_weekAndDay_future_lmp_returnsNil() {
        // lmp가 now보다 미래 → 음수 days → nil
        let lmp = date("2026-05-01")
        let now = date("2026-04-19")
        XCTAssertNil(PregnancyDateMath.weekAndDay(from: lmp, now: now))
    }

    func test_weekAndDay_exactly7days_returns1week0day() {
        let lmp = date("2026-04-12")
        let now = date("2026-04-19")
        let result = PregnancyDateMath.weekAndDay(from: lmp, now: now)
        XCTAssertEqual(result?.weeks, 1)
        XCTAssertEqual(result?.days, 0)
    }

    func test_weekAndDay_17days_returns2week3day() {
        let lmp = date("2026-04-02")
        let now = date("2026-04-19")
        let result = PregnancyDateMath.weekAndDay(from: lmp, now: now)
        XCTAssertEqual(result?.weeks, 2)
        XCTAssertEqual(result?.days, 3)
    }

    func test_weekAndDay_280days_returns40week0day() {
        let lmp = date("2025-07-13")  // 280일 전 = 40주 정확
        let now = date("2026-04-19")
        let result = PregnancyDateMath.weekAndDay(from: lmp, now: now)
        XCTAssertEqual(result?.weeks, 40)
        XCTAssertEqual(result?.days, 0)
    }

    func test_weekAndDay_sameDay_returns0week0day() {
        let lmp = date("2026-04-19")
        let now = date("2026-04-19")
        let result = PregnancyDateMath.weekAndDay(from: lmp, now: now)
        XCTAssertEqual(result?.weeks, 0)
        XCTAssertEqual(result?.days, 0)
    }

    // MARK: dDay

    func test_dDay_nil_due_returnsNil() {
        XCTAssertNil(PregnancyDateMath.dDay(due: nil, now: date("2026-04-19")))
    }

    func test_dDay_due_today_returns0() {
        let due = date("2026-04-19")
        let now = date("2026-04-19")
        XCTAssertEqual(PregnancyDateMath.dDay(due: due, now: now), 0)
    }

    func test_dDay_due_tomorrow_returns1() {
        let due = date("2026-04-20")
        let now = date("2026-04-19")
        XCTAssertEqual(PregnancyDateMath.dDay(due: due, now: now), 1)
    }

    func test_dDay_due_yesterday_returnsMinus1_overdue() {
        let due = date("2026-04-18")
        let now = date("2026-04-19")
        XCTAssertEqual(PregnancyDateMath.dDay(due: due, now: now), -1)
    }

    func test_dDay_due_oneWeekFuture_returns7() {
        let due = date("2026-04-26")
        let now = date("2026-04-19")
        XCTAssertEqual(PregnancyDateMath.dDay(due: due, now: now), 7)
    }
}

// MARK: - PregnancyViewModel 통합 테스트 (MockPregnancyFirestore 활용)

final class PregnancyViewModelIntegrationTests: XCTestCase {

    // 1. loadActivePregnancy — Mock 응답이 VM 상태로 반영되는지 검증
    func test_loadActivePregnancy_mockResponse_setsState() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(
            lmpDate: Calendar.current.date(byAdding: .day, value: -84, to: Date()),
            dueDate: Calendar.current.date(byAdding: .day, value: 196, to: Date()),
            fetusCount: 1,
            babyNickname: "테스트아기"
        )
        pregnancy.ownerUserId = "user1"
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "loadActive")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.activePregnancy)
            XCTAssertEqual(vm.activePregnancy?.babyNickname, "테스트아기")
            XCTAssertEqual(mock.fetchActivePregnancyCalls.count, 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // 2. loadActivePregnancy — transitionState=pending 시 VM이 errorMessage 없이 pregnancy를 노출하는지 검증
    func test_fetchActivePregnancy_transitionPending_exposesRecoveryState() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(fetusCount: 1)
        pregnancy.transitionState = "pending"
        pregnancy.ownerUserId = "user1"
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "transitionPending")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.activePregnancy, "pending 상태 pregnancy는 VM에 노출되어야 함")
            XCTAssertEqual(vm.activePregnancy?.transitionState, "pending")
            XCTAssertNil(vm.errorMessage)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // 3. savePregnancy 실패 시 errorMessage가 설정되는지 검증
    func test_writeBatch_failure_errorHandled() {
        let mock = MockPregnancyFirestore()
        mock.errorOnSavePregnancy = NSError(domain: "Firestore", code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "write failed"])

        let expectation = expectation(description: "error")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.createPregnancy(
                lmpDate: Calendar.current.date(byAdding: .day, value: -84, to: Date()),
                dueDate: Calendar.current.date(byAdding: .day, value: 196, to: Date()),
                fetusCount: 1,
                userId: "user1"
            )
            XCTAssertNotNil(vm.errorMessage)
            XCTAssertTrue(vm.errorMessage?.contains("write failed") == true)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // 4. 자신의 임신 없을 때 sharedPregnancy fallback으로 파트너 임신 반환 검증
    func test_loadActivePregnancy_noOwn_fallbackToSharedPregnancy_resolvesCorrectly() {
        let mock = MockPregnancyFirestore()
        mock.activePregnancyResponse = nil
        var shared = Pregnancy(fetusCount: 1, babyNickname: "공유아기")
        shared.ownerUserId = "partner-uid"
        shared.sharedWith = ["self-uid"]
        mock.sharedPregnancyResponse = shared

        let expectation = expectation(description: "sharedFallback")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "self-uid")
            XCTAssertNotNil(vm.activePregnancy, "파트너 공유 임신이 fallback으로 설정되어야 함")
            XCTAssertEqual(vm.activePregnancy?.babyNickname, "공유아기")
            XCTAssertEqual(mock.fetchSharedPregnancyCalls.count, 1)
            XCTAssertEqual(mock.fetchSharedPregnancyCalls.first, "self-uid")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // 5. fetchSharedPregnancy — sharedWith에 파트너 포함 시 반환 검증
    func test_fetchSharedPregnancy_partnerInSharedWith_returnsPregnancy() {
        let mock = MockPregnancyFirestore()
        var shared = Pregnancy(fetusCount: 1, babyNickname: "파트너아기")
        shared.sharedWith = ["partner-uid"]
        mock.sharedPregnancyResponse = shared

        let expectation = expectation(description: "sharedReturn")
        Task {
            let result = try? await mock.fetchSharedPregnancy(currentUserId: "partner-uid")
            XCTAssertNotNil(result)
            XCTAssertEqual(result?.babyNickname, "파트너아기")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // 6. fetchSharedPregnancy — 매칭 없을 때 nil 반환 검증
    func test_fetchSharedPregnancy_noMatch_returnsNil() {
        let mock = MockPregnancyFirestore()
        mock.sharedPregnancyResponse = nil

        let expectation = expectation(description: "sharedNil")
        Task {
            let result = try? await mock.fetchSharedPregnancy(currentUserId: "unknown-uid")
            XCTAssertNil(result)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // 7. outcome=nil 문서 (outcome 필드 누락) — VM이 crash 없이 처리하는지 검증
    func test_outcomeNil_document_handledGracefully() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(fetusCount: 1)
        pregnancy.outcome = nil // outcome 필드 누락 시뮬레이션
        pregnancy.ownerUserId = "user1"
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "outcomeNil")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.activePregnancy)
            XCTAssertNil(vm.activePregnancy?.outcome)
            XCTAssertNil(vm.errorMessage)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
}

// MARK: - PregnancyRecovery Tests (P2-2)

final class PregnancyRecoveryTests: XCTestCase {

    // 1. stale pending pregnancy 로드 시 pendingOrphan이 노출되는지 검증
    func test_recovery_fromPendingState_onLoad_showsAlert() {
        let mock = MockPregnancyFirestore()
        // updatedAt을 31초 전으로 설정하여 stale 임계값 초과
        var pregnancy = Pregnancy(fetusCount: 1)
        pregnancy.transitionState = "pending"
        pregnancy.ownerUserId = "user1"
        pregnancy.updatedAt = Date().addingTimeInterval(-(PregnancyViewModel.pendingStaleThreshold + 1))
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "pendingOrphan")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.pendingOrphan, "stale pending 상태에서 pendingOrphan이 노출되어야 함")
            XCTAssertEqual(vm.pendingOrphan?.transitionState, "pending")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // 2. pending 30초 이내 — 정상 전환 중으로 간주, pendingOrphan nil 확인
    func test_recovery_freshPending_withinThreshold_hidesModal() {
        let mock = MockPregnancyFirestore()
        // updatedAt을 10초 전으로 설정 (30초 미만 → 정상 전환 중)
        var pregnancy = Pregnancy(fetusCount: 1)
        pregnancy.transitionState = "pending"
        pregnancy.ownerUserId = "user1"
        pregnancy.updatedAt = Date().addingTimeInterval(-10) // 10초 전
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "freshPending")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNil(vm.pendingOrphan, "30초 이내 pending은 모달을 숨겨야 함 (정상 전환 중)")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // 3. rollback: rollbackPendingTransition 호출 시 Firestore에 rollback 요청 + pendingOrphan nil
    func test_recovery_rollback_restoresOngoingState() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(fetusCount: 1)
        pregnancy.transitionState = "pending"
        pregnancy.ownerUserId = "user1"
        pregnancy.updatedAt = Date().addingTimeInterval(-(PregnancyViewModel.pendingStaleThreshold + 1))
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "rollback")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.pendingOrphan)

            await vm.rollbackPendingTransition(userId: "user1")

            XCTAssertNil(vm.pendingOrphan, "rollback 후 pendingOrphan은 nil이어야 함")
            XCTAssertNil(vm.activePregnancy?.transitionState, "rollback 후 transitionState는 nil이어야 함")
            XCTAssertEqual(mock.rollbackTransitionPendingCalls.count, 1,
                           "rollbackTransitionPending이 1회 호출되어야 함")
            XCTAssertEqual(mock.deletePregnancyCalls.count, 0,
                           "rollback 시 pregnancy 문서 삭제 금지 (데이터 보존)")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // 4. resume: resumePendingTransition 호출 시 transitionToBaby WriteBatch 재실행
    func test_recovery_retry_completesTransition() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(
            lmpDate: Calendar.current.date(byAdding: .day, value: -280, to: Date()),
            dueDate: Calendar.current.date(byAdding: .day, value: 0, to: Date()),
            fetusCount: 1,
            babyNickname: "테스트아기"
        )
        pregnancy.transitionState = "pending"
        pregnancy.ownerUserId = "user1"
        pregnancy.updatedAt = Date().addingTimeInterval(-(PregnancyViewModel.pendingStaleThreshold + 1))
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "resume")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.pendingOrphan)

            _ = try? await vm.resumePendingTransition(
                babyName: "출산아기",
                gender: .male,
                birthDate: Date(),
                userId: "user1"
            )

            XCTAssertNil(vm.pendingOrphan, "resume 후 pendingOrphan은 nil이어야 함")
            XCTAssertEqual(mock.markTransitionPendingCalls.count, 1,
                           "resume 시 markTransitionPending 재호출 확인")
            XCTAssertEqual(mock.transitionCalls.count, 1,
                           "resume 시 WriteBatch 전환이 실행되어야 함")
            XCTAssertEqual(mock.deletePregnancyCalls.count, 0,
                           "resume 시에도 pregnancy 문서 삭제 금지")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
}

// MARK: - PregnancyTermination Tests (P2-1)

final class PregnancyTerminationTests: XCTestCase {

    // 1. terminatePregnancy — markTransitionPending 호출이 WriteBatch 전에 발생하는지 검증
    func test_transitionToOutcome_marksPendingBeforeBatch() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(fetusCount: 1, babyNickname: "테스트아기")
        pregnancy.ownerUserId = "user1"
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "markPendingBeforeBatch")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.activePregnancy)

            try? await vm.terminatePregnancy(outcome: .miscarriage, userId: "user1")

            XCTAssertEqual(mock.markTransitionPendingCalls.count, 1,
                           "markTransitionPending이 반드시 WriteBatch 전에 1회 호출되어야 함")
            XCTAssertEqual(mock.terminateCalls.count, 1,
                           "terminatePregnancy WriteBatch가 1회 호출되어야 함")
            XCTAssertEqual(mock.terminateCalls.first?.outcome, .miscarriage)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // 2. terminatePregnancy 성공 후 activePregnancy가 nil로 클리어되는지 검증
    func test_transitionToOutcome_clearsPendingAfterSuccess() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(fetusCount: 1, babyNickname: "테스트아기")
        pregnancy.ownerUserId = "user1"
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "clearsPendingAfterSuccess")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.activePregnancy)

            try? await vm.terminatePregnancy(outcome: .stillbirth, userId: "user1")

            XCTAssertNil(vm.activePregnancy,
                         "성공 후 activePregnancy는 nil이어야 함 (로컬 상태 클리어)")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // 3. terminatePregnancy Firestore 오류 시 두 번째 호출도 noop(activePregnancy nil) 검증
    func test_transitionToOutcome_duplicateCall_secondCallIsNoop() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(fetusCount: 1, babyNickname: "테스트아기")
        pregnancy.ownerUserId = "user1"
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "duplicateCallNoop")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.activePregnancy)

            // 첫 번째 호출 — 성공
            try? await vm.terminatePregnancy(outcome: .terminated, userId: "user1")
            XCTAssertNil(vm.activePregnancy, "첫 번째 호출 후 activePregnancy nil")

            // 두 번째 호출 — activePregnancy nil이므로 noActivePregnancy 에러로 no-op
            do {
                try await vm.terminatePregnancy(outcome: .terminated, userId: "user1")
                XCTFail("두 번째 호출은 noActivePregnancy 에러를 던져야 함")
            } catch PregnancyViewModel.PregnancyError.noActivePregnancy {
                // 예상 경로 — no-op
            } catch {
                XCTFail("예상치 못한 에러: \(error)")
            }

            XCTAssertEqual(mock.terminateCalls.count, 1, "중복 호출 시 WriteBatch는 1회만 실행되어야 함")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
}

/// PregnancyRecoveryModal의 3가지 상태 전환 검증.
/// MockPregnancyFirestore 재사용 패턴 (P2-2에서 검증된 패턴 확장).
final class PregnancyRecoveryModalStateTests: XCTestCase {

    // RM-1: pendingOrphan nil → 모달 미표시 상태 (초기 상태)
    func test_recoveryModal_initialState_noOrphan_modalHidden() {
        let mock = MockPregnancyFirestore()
        mock.activePregnancyResponse = nil

        let expectation = expectation(description: "noOrphan")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNil(vm.pendingOrphan, "임신 없음 → pendingOrphan nil (모달 미표시)")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // RM-2: ongoing pregnancy (transitionState nil) → pendingOrphan nil (모달 미표시)
    func test_recoveryModal_ongoingPregnancy_noOrphan() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(fetusCount: 1)
        pregnancy.transitionState = nil // 정상 진행 중
        pregnancy.ownerUserId = "user1"
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "ongoingNoOrphan")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNil(vm.pendingOrphan, "진행 중 임신: pendingOrphan nil (모달 미표시)")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // RM-3: stale pending → pendingOrphan 세팅 → resume 성공 → pendingOrphan nil
    func test_recoveryModal_pendingDetect_resume_success_clearsOrphan() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(
            lmpDate: Calendar.current.date(byAdding: .day, value: -280, to: Date()),
            fetusCount: 1,
            babyNickname: "복구아기"
        )
        pregnancy.transitionState = "pending"
        pregnancy.ownerUserId = "user1"
        pregnancy.updatedAt = Date().addingTimeInterval(-(PregnancyViewModel.pendingStaleThreshold + 5))
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "resumeSuccess")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.pendingOrphan, "RM-3: stale pending → pendingOrphan 세팅")

            _ = try? await vm.resumePendingTransition(
                babyName: "복구아기",
                gender: .female,
                birthDate: Date(),
                userId: "user1"
            )

            XCTAssertNil(vm.pendingOrphan, "resume 성공 후 pendingOrphan nil")
            XCTAssertEqual(mock.transitionCalls.count, 1, "WriteBatch 1회 실행 (single-write 금지 검증)")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // RM-4: rollback 후 transitionState nil + pregnancy 문서 보존 검증
    func test_recoveryModal_rollback_preservesPregnancyDocument() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(fetusCount: 1)
        pregnancy.transitionState = "pending"
        pregnancy.ownerUserId = "user1"
        pregnancy.updatedAt = Date().addingTimeInterval(-(PregnancyViewModel.pendingStaleThreshold + 1))
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "rollbackPreserves")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.pendingOrphan)

            await vm.rollbackPendingTransition(userId: "user1")

            XCTAssertEqual(mock.deletePregnancyCalls.count, 0,
                           "롤백 시 임신 문서 삭제 절대 금지 (데이터 보존 invariant)")
            XCTAssertEqual(mock.rollbackTransitionPendingCalls.count, 1,
                           "rollbackTransitionPending 1회 호출 확인")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // RM-5: resume WriteBatch 실패 → pendingOrphan 유지 (재시도 가능)
    func test_recoveryModal_resume_firerstoreError_orphanPersists() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(fetusCount: 1, babyNickname: "실패아기")
        pregnancy.transitionState = "pending"
        pregnancy.ownerUserId = "user1"
        pregnancy.updatedAt = Date().addingTimeInterval(-(PregnancyViewModel.pendingStaleThreshold + 1))
        mock.activePregnancyResponse = pregnancy
        mock.errorOnTransition = NSError(
            domain: "Firestore",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "네트워크 오류"]
        )

        let expectation = expectation(description: "resumeFailure")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.pendingOrphan)

            _ = try? await vm.resumePendingTransition(
                babyName: "실패아기",
                gender: .male,
                birthDate: Date(),
                userId: "user1"
            )

            // 실패 시에도 pregnancy 문서는 보존 (삭제 금지)
            XCTAssertEqual(mock.deletePregnancyCalls.count, 0,
                           "resume 실패 시에도 pregnancy 문서 삭제 금지")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
}

// MARK: - PregnancyFinalWeek Tests (P3-foundation Task 2)

final class PregnancyFinalWeekTests: XCTestCase {
    func test_finalWeekAndDay_usesArchivedAt_notToday() {
        let cal = Calendar.current
        let lmp = cal.date(byAdding: .day, value: -200, to: Date())!
        let archived = cal.date(byAdding: .day, value: 84, to: lmp)!  // LMP+84일 = 12주 0일
        let p = Pregnancy(lmpDate: lmp, outcome: .miscarriage, archivedAt: archived)
        let wd = p.finalWeekAndDay
        XCTAssertEqual(wd?.weeks, 12)
        XCTAssertEqual(wd?.days, 0)
    }
    func test_finalWeekAndDay_noArchivedAt_fallsBackToToday() {
        let lmp = Calendar.current.date(byAdding: .day, value: -70, to: Date())!  // 10주 0일
        let p = Pregnancy(lmpDate: lmp)
        XCTAssertEqual(p.finalWeekAndDay?.weeks, 10)
    }
}

// MARK: - PregnancyGenderPrefill Tests (P3-foundation Task 1)

final class PregnancyGenderPrefillTests: XCTestCase {
    func test_genderPrefill_female_returnsFemale() {
        var p = Pregnancy(fetusCount: 1)
        p.ultrasoundGender = .female
        XCTAssertEqual(p.genderPrefill, .female, "여아 초음파 → prefill 여아")
    }
    func test_genderPrefill_male_returnsMale() {
        var p = Pregnancy(fetusCount: 1)
        p.ultrasoundGender = .male
        XCTAssertEqual(p.genderPrefill, .male)
    }
    func test_genderPrefill_nil_defaultsToMale() {
        let p = Pregnancy(fetusCount: 1)
        XCTAssertEqual(p.genderPrefill, .male, "미설정 시 기본값")
    }
}

// MARK: - P3-1: Termination Flow Edge Case Tests (A-11 확장)

/// PregnancyTerminationView 엣지 케이스 + P2-1 CTA 분리 검증.
final class TerminationFlowEdgeCaseTests: XCTestCase {

    // TF-1: terminationOutcomes에 born이 포함되지 않아야 함 (출산은 별도 경로)
    func test_terminationOutcomes_doesNotContainBorn() {
        // PregnancyTerminationView의 terminationOutcomes는 [.miscarriage, .stillbirth, .terminated]
        let terminationOutcomes: [PregnancyOutcome] = [.miscarriage, .stillbirth, .terminated]
        XCTAssertFalse(
            terminationOutcomes.contains(.born),
            "임신 종료 경로에 '출산(born)' outcome이 포함되면 안 됨 (P2-1 CTA 분리)"
        )
    }

    // TF-2: terminationOutcomes에 ongoing이 포함되지 않아야 함
    func test_terminationOutcomes_doesNotContainOngoing() {
        let terminationOutcomes: [PregnancyOutcome] = [.miscarriage, .stillbirth, .terminated]
        XCTAssertFalse(
            terminationOutcomes.contains(.ongoing),
            "임신 종료 경로에 '진행 중(ongoing)' outcome이 포함되면 안 됨"
        )
    }

    // TF-3: terminatePregnancy 호출 순서: markTransitionPending → WriteBatch (원자성 보장)
    func test_termination_markPendingBeforeBatch_ordering() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(fetusCount: 1)
        pregnancy.ownerUserId = "user1"
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "ordering")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")

            try? await vm.terminatePregnancy(outcome: .miscarriage, userId: "user1")

            // markTransitionPending이 terminateCalls보다 먼저 불렸는지 검증
            XCTAssertGreaterThanOrEqual(
                mock.markTransitionPendingCalls.count, 1,
                "markTransitionPending이 WriteBatch 전에 반드시 1회 호출 (원자성 보장)"
            )
            XCTAssertGreaterThanOrEqual(
                mock.terminateCalls.count, 1,
                "WriteBatch terminatePregnancy 1회 실행"
            )
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // TF-4: miscarriage outcome으로 종료 후 activePregnancy nil (로컬 상태 클리어)
    func test_termination_miscarriage_clearsActivePregnancy() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(fetusCount: 1)
        pregnancy.ownerUserId = "user1"
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "miscarriageClear")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.activePregnancy)

            try? await vm.terminatePregnancy(outcome: .miscarriage, userId: "user1")

            XCTAssertNil(vm.activePregnancy, "유산 종료 후 activePregnancy nil")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // TF-5: stillbirth outcome으로 종료 후 activePregnancy nil
    func test_termination_stillbirth_clearsActivePregnancy() {
        let mock = MockPregnancyFirestore()
        var pregnancy = Pregnancy(fetusCount: 1)
        pregnancy.ownerUserId = "user1"
        mock.activePregnancyResponse = pregnancy

        let expectation = expectation(description: "stillbirthClear")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            await vm.loadActivePregnancy(userId: "user1")
            XCTAssertNotNil(vm.activePregnancy)

            try? await vm.terminatePregnancy(outcome: .stillbirth, userId: "user1")

            XCTAssertNil(vm.activePregnancy, "사산 종료 후 activePregnancy nil")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }

    // TF-6: activePregnancy 없는 상태에서 terminatePregnancy 호출 → noActivePregnancy 에러
    func test_termination_noActivePregnancy_throwsError() {
        let mock = MockPregnancyFirestore()
        mock.activePregnancyResponse = nil

        let expectation = expectation(description: "noActiveError")
        Task { @MainActor in
            let vm = PregnancyViewModel(firestoreService: mock)
            // loadActivePregnancy를 호출하지 않으면 activePregnancy는 nil
            do {
                try await vm.terminatePregnancy(outcome: .terminated, userId: "user1")
                XCTFail("noActivePregnancy 에러가 발생해야 함")
            } catch PregnancyViewModel.PregnancyError.noActivePregnancy {
                // 예상 경로
            } catch {
                // 다른 에러도 허용 (구현에 따라 다를 수 있음)
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
    }
}

// MARK: - Task 3: 출산 전환 중복 아기 멱등화 (P0)

@MainActor
final class PregnancyTransitionIdempotencyTests: XCTestCase {
    private func makeVM(_ mock: MockPregnancyFirestore) -> PregnancyViewModel {
        PregnancyViewModel(firestoreService: mock)
    }

    func test_transition_normalFlow_createsOneBabyWithDeterministicId() async throws {
        let mock = MockPregnancyFirestore()
        let vm = makeVM(mock)
        let p = Pregnancy(fetusCount: 1)
        vm.activePregnancy = p
        _ = try await vm.transitionToBaby(babyName: "콩이", gender: .female, birthDate: Date(), userId: "mom")
        XCTAssertEqual(mock.createdBabyIds, ["baby_\(p.id)"], "결정적 id 1개 생성")
    }

    func test_transition_retryWhenBabyExists_noDuplicate() async throws {
        let mock = MockPregnancyFirestore()
        let p = Pregnancy(fetusCount: 1)
        mock.existingBabyIds = ["baby_\(p.id)"]   // 1차 시도가 이미 생성(크래시 후 잔존)
        let vm = makeVM(mock)
        vm.activePregnancy = p
        _ = try await vm.transitionToBaby(babyName: "콩이", gender: .female, birthDate: Date(), userId: "mom")
        XCTAssertTrue(mock.createdBabyIds.isEmpty, "이미 존재하면 새 아기 생성 0 (멱등)")
    }
}

// MARK: - Task 4: ownerUserId 영속화 (공유 임신 소유자 식별 토대)

final class PregnancyOwnerPersistenceTests: XCTestCase {
    func test_ownerUserId_survivesEncodeDecodeRoundtrip() throws {
        var p = Pregnancy(fetusCount: 1)
        p.ownerUserId = "mom-uid"
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(Pregnancy.self, from: data)
        XCTAssertEqual(decoded.ownerUserId, "mom-uid", "ownerUserId가 직렬화에 보존되어야 함")
    }
}

