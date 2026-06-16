import XCTest
@testable import BabyCare

/// 아기 추가/삭제 신뢰성 회귀 테스트 (버그②).
final class BabyCRUDTests: XCTestCase {

    // MARK: - RC1: 삭제/수정 시 대상 아기의 owner 경로 사용 (현재 선택 아기 무관)

    @MainActor
    func test_ownerUserId_usesTargetBabyOwner_notCurrentUser() {
        // 공유받은 아기(owner = 다른 사람)를 삭제 → 그 아기의 owner 경로를 써야 함
        var shared = Baby(name: "공유아기", birthDate: Date(), gender: .female)
        shared.ownerUserId = "owner-uid"
        XCTAssertEqual(
            BabyViewModel.ownerUserId(for: shared, currentUserId: "me-uid"),
            "owner-uid"
        )
    }

    @MainActor
    func test_ownerUserId_fallsBackToCurrentWhenNil() {
        // 내 아기(ownerUserId 미설정) → 현재 사용자 경로로 폴백
        let own = Baby(name: "내아기", birthDate: Date(), gender: .male)
        XCTAssertNil(own.ownerUserId)
        XCTAssertEqual(
            BabyViewModel.ownerUserId(for: own, currentUserId: "me-uid"),
            "me-uid"
        )
    }
}
