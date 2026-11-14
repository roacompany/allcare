import FirebaseFirestore
import XCTest
@testable import BabyCare

/// 가족 초대 — 실제 VM·서비스(Swift)를 레포 규칙이 걸린 에뮬레이터에 태운다(`make emulator-test`).
/// 에뮬레이터가 없으면 건너뛴다.
@MainActor
final class EmulatorFamilySharingTests: XCTestCase {

    override func setUp() async throws {
        try await FirebaseEmulator.requireRunning()
        try await FirebaseEmulator.reset()
    }

    /// 새 앱 초대 전 과정: 아기 만들기 → 초대 만들기 → 코드로 받기 → 받은 사람이 주인 아기를 읽는다 → 초대 「사용함」.
    func test_inviteAndJoin_endToEnd() async throws {
        let owner = try await FirebaseEmulator.signUp("owner")
        let baby = Baby(name: "콩이", birthDate: Date(timeIntervalSince1970: 1_780_000_000), gender: .female)
        try await owner.service.createBaby(baby, userId: owner.uid)

        let ownerVM = FamilySharingViewModel(firestoreService: owner.service)
        await ownerVM.generateInvite(for: baby, userId: owner.uid)
        let code = try XCTUnwrap(ownerVM.generatedInvite?.code, "초대 코드가 만들어져야 한다: \(ownerVM.message ?? "-")")
        let stored = try await FirebaseEmulator.adminGet("invites/\(code)")
        XCTAssertEqual(stored?["ownerUserId"] as? String, owner.uid, "서버에 내 초대로 저장돼야 한다")
        XCTAssertEqual(stored?["isUsed"] as? Bool, false)

        let joiner = try await FirebaseEmulator.signUp("joiner")
        let joinerVM = FamilySharingViewModel(firestoreService: joiner.service)
        let access = try await joinerVM.joinFamily(code: code, userId: joiner.uid, relationship: .father)
        XCTAssertEqual(access.ownerUserId, owner.uid)
        XCTAssertEqual(access.inviteCode, code)

        let shared = try await joiner.service.fetchBaby(userId: owner.uid, babyId: baby.id)
        XCTAssertEqual(shared?.name, "콩이", "받은 사람이 주인 아기를 읽어야 공유가 열린 것이다")
        let used = try await FirebaseEmulator.adminGet("invites/\(code)")
        XCTAssertEqual(used?["isUsed"] as? Bool, true)
    }

    /// 공유 문구를 통째로 붙여 넣어도 들어가진다(받는 칸 정리 → 조회).
    func test_join_withWholeShareTextPasted() async throws {
        let owner = try await FirebaseEmulator.signUp("owner")
        let baby = Baby(name: "콩이", birthDate: Date(timeIntervalSince1970: 1_780_000_000), gender: .male)
        try await owner.service.createBaby(baby, userId: owner.uid)
        let ownerVM = FamilySharingViewModel(firestoreService: owner.service)
        await ownerVM.generateInvite(for: baby, userId: owner.uid)
        let invite = try XCTUnwrap(ownerVM.generatedInvite)

        let joiner = try await FirebaseEmulator.signUp("joiner")
        let typed = FamilyInvite.codeInput(from: invite.shareText())
        let access = try await FamilySharingViewModel(firestoreService: joiner.service)
            .joinFamily(code: typed, userId: joiner.uid, relationship: .mother)
        XCTAssertEqual(access.babyId, baby.id)
    }

    /// 규칙이 공유 문서를 거부하면(이미 쓴 초대) 서비스가 그 거부를 던진다.
    /// 고치기 전(c997bb3 이전): Codable setData 가 서버를 안 기다려 성공으로 돌아왔다 → 화면은 「참여」, 서버엔 공유 없음.
    func test_saveSharedAccess_withUsedInvite_throwsServerRejection() async throws {
        try await FirebaseEmulator.adminSet("invites/R8WX3D", [
            "code": "R8WX3D", "ownerUserId": "ownerX", "babyId": "b1", "babyName": "콩이",
            "createdAt": Date(), "expiresAt": Date().addingTimeInterval(86_400), "isUsed": true,
        ])
        let joiner = try await FirebaseEmulator.signUp("joiner")
        let access = SharedBabyAccess(ownerUserId: "ownerX", babyId: "b1", babyName: "콩이", inviteCode: "R8WX3D")
        do {
            try await joiner.service.saveSharedAccess(access, userId: joiner.uid)
            XCTFail("규칙 거부를 삼켰다")
        } catch {
            XCTAssertEqual((error as NSError).code, FirestoreErrorCode.permissionDenied.rawValue, "\(error)")
        }
        let left = try await FirebaseEmulator.adminGet("users/\(joiner.uid)/sharedAccess/ownerX_b1")
        XCTAssertNil(left)
    }

    /// 만든 코드가 이미 남의 초대 코드면 저장이 실패로 끝난다 — 남의 아기 초대를 내 것처럼 보여 주지 않는다.
    func test_saveInvite_codeAlreadyTakenByAnotherOwner_throws() async throws {
        try await FirebaseEmulator.adminSet("invites/K7MNP2", [
            "code": "K7MNP2", "ownerUserId": "someoneElse", "babyId": "theirBaby", "babyName": "남의 아기",
            "createdAt": Date(), "expiresAt": Date().addingTimeInterval(86_400), "isUsed": false,
        ])
        let owner = try await FirebaseEmulator.signUp("owner")
        let mine = FamilyInvite(code: "K7MNP2", ownerUserId: owner.uid, babyId: "myBaby", babyName: "콩이")
        do {
            try await owner.service.saveInvite(mine)
            XCTFail("남의 초대 위에 덮어썼다고 믿게 했다")
        } catch {
            XCTAssertEqual((error as NSError).code, FirestoreErrorCode.permissionDenied.rawValue, "\(error)")
        }
        let stored = try await FirebaseEmulator.adminGet("invites/K7MNP2")
        XCTAssertEqual(stored?["ownerUserId"] as? String, "someoneElse")
    }
}
