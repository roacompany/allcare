import XCTest
@testable import BabyCare

/// 계정 전환/로그아웃 시 사용자 스코프 상태 초기화 회귀 테스트 (버그①: 이전 계정 기록 잔존).
final class AccountResetTests: XCTestCase {

    // MARK: - BabyViewModel.reset

    @MainActor
    func test_babyReset_clearsBabiesAndSelection() {
        let vm = BabyViewModel()
        vm.babies = [Baby(name: "A", birthDate: Date(), gender: .male)]
        vm.selectedBaby = vm.babies.first
        vm.errorMessage = "stale"

        vm.reset()

        XCTAssertTrue(vm.babies.isEmpty)
        XCTAssertNil(vm.selectedBaby)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - resolveSelection (stale selectedBaby 방지)

    @MainActor
    func test_resolveSelection_keepsValidCurrent() {
        let a = Baby(name: "A", birthDate: Date(), gender: .male)
        let b = Baby(name: "B", birthDate: Date(), gender: .female)
        let picked = BabyViewModel.resolveSelection(current: a, in: [a, b])
        XCTAssertEqual(picked?.id, a.id)
    }

    @MainActor
    func test_resolveSelection_replacesStaleWithFirst() {
        // 이전 계정의 selectedBaby(old)가 새 계정 목록에 없음 → 새 목록 첫 아기로 교체
        let old = Baby(name: "이전계정아기", birthDate: Date(), gender: .male)
        let new1 = Baby(name: "새계정아기1", birthDate: Date(), gender: .female)
        let new2 = Baby(name: "새계정아기2", birthDate: Date(), gender: .male)
        let picked = BabyViewModel.resolveSelection(current: old, in: [new1, new2])
        XCTAssertEqual(picked?.id, new1.id)
        XCTAssertNotEqual(picked?.id, old.id)
    }

    @MainActor
    func test_resolveSelection_nilCurrentPicksFirst() {
        let a = Baby(name: "A", birthDate: Date(), gender: .male)
        XCTAssertEqual(BabyViewModel.resolveSelection(current: nil, in: [a])?.id, a.id)
    }

    @MainActor
    func test_resolveSelection_emptyListReturnsNil() {
        let a = Baby(name: "A", birthDate: Date(), gender: .male)
        XCTAssertNil(BabyViewModel.resolveSelection(current: a, in: []))
    }

    // MARK: - PregnancyViewModel.reset

    @MainActor
    func test_pregnancyReset_clearsAllCollections() {
        let vm = PregnancyViewModel()
        vm.activePregnancy = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "t")
        vm.kickSessions = [KickSession(pregnancyId: "p1")]
        vm.vitalEntries = [PregnancyVitalEntry(pregnancyId: "p1", glucose: 90)]
        vm.contractionSessions = [ContractionSession(pregnancyId: "p1")]
        vm.errorMessage = "stale"

        vm.reset()

        XCTAssertNil(vm.activePregnancy)
        XCTAssertTrue(vm.kickSessions.isEmpty)
        XCTAssertTrue(vm.vitalEntries.isEmpty)
        XCTAssertTrue(vm.contractionSessions.isEmpty)
        XCTAssertNil(vm.currentKickSession)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - OfflineQueue.clear (cross-account replay 차단)

    @MainActor
    func test_offlineQueueClear_emptiesQueue() {
        let queue = OfflineQueue()
        queue.clear()  // 선행 상태 제거(테스트 격리)
        queue.enqueue(PendingOperation(
            id: "op1", timestamp: Date(), type: .create,
            collectionPath: "users/old/babies", documentId: "d1", jsonData: nil
        ))
        XCTAssertEqual(queue.pendingCount, 1)

        queue.clear()

        XCTAssertEqual(queue.pendingCount, 0)
        XCTAssertTrue(queue.operations.isEmpty)
    }
}
