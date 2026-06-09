import XCTest
@testable import BabyCare

/// 임신 가족공유 데이터 정합 회귀 방지 (2026-06-10 감사 #3 owner resolution / #16 kick history / #19 owner routing).
@MainActor
final class PregnancySharedDataTests: XCTestCase {

    // MARK: - #3 공유 임신 소유자 경로 추출

    func testOwnerUserId_fromValidPregnancyPath_extractsOwner() {
        let path = "\(FirestoreCollections.users)/OWNER123/\(FirestoreCollections.pregnancies)/PID9"
        XCTAssertEqual(FirestoreService.ownerUserId(fromPregnancyPath: path), "OWNER123",
                       "공유 임신 문서 경로에서 실소유자 uid 를 추출해야 한다 (없으면 하위컬렉션 빈값 #3)")
    }

    func testOwnerUserId_fromInvalidPath_returnsNil() {
        XCTAssertNil(FirestoreService.ownerUserId(fromPregnancyPath: "foo/bar"))
        XCTAssertNil(FirestoreService.ownerUserId(fromPregnancyPath: "\(FirestoreCollections.users)/u/babies/b"))
    }

    // MARK: - #16 2시간 자동 종료 시 히스토리 갱신

    func testRecordKick_autoEndAfterTwoHours_refreshesKickHistory() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var preg = Pregnancy(id: "P1")
        preg.ownerUserId = "owner"
        vm.activePregnancy = preg
        // 3시간 전에 시작된 진행 세션 → exceededTwoHours
        vm.currentKickSession = KickSession(pregnancyId: "P1", startedAt: Date().addingTimeInterval(-3 * 3600))
        let endedInHistory = KickSession(pregnancyId: "P1")
        mock.kickSessionsResponse = [endedInHistory]

        await vm.recordKick(userId: "owner")

        XCTAssertNil(vm.currentKickSession, "2시간 초과 → 자동 종료")
        XCTAssertEqual(vm.kickSessions.map(\.id), [endedInHistory.id],
                       "자동 종료된 세션이 히스토리에 즉시 반영되어야 한다 (#16)")
    }

    // MARK: - #19 임신 데이터 쓰기는 소유자 path 로 라우팅

    func testKickSessionWrite_routesToPregnancyOwner_notCaller() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var preg = Pregnancy(id: "P1")
        preg.ownerUserId = "OWNER"
        vm.activePregnancy = preg

        await vm.startKickSession(userId: "PARTNER")  // 호출자가 파트너 uid 를 넘겨도

        XCTAssertEqual(mock.saveKickSessionUserIds, ["OWNER"],
                       "임신 데이터 쓰기는 공유 소유자 path 로 라우팅되어야 한다 — dataUserId (#19)")
    }
}
