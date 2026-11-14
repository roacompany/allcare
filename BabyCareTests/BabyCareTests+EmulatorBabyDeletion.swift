import FirebaseFirestore
import XCTest
@testable import BabyCare

/// 아기 삭제 — 실제 FirestoreService.deleteBaby 를 레포 규칙이 걸린 에뮬레이터에서(`make emulator-test`).
@MainActor
final class EmulatorBabyDeletionTests: XCTestCase {

    override func setUp() async throws {
        try await FirebaseEmulator.requireRunning()
        try await FirebaseEmulator.reset()
    }

    /// 아기를 지우면 그 아기 아래엔 아무것도 남지 않는다 — 하위 컬렉션 전부(여행 포함).
    /// 고치기 전(main 2a108e1): 지우기 목록에 trips 가 없어 여행 일정(날짜·숙소·편명)이 서버에 남았다.
    /// 다른 아기와 사용자 칸은 그대로여야 하고, 아기 수는 한 번만 준다.
    func test_deleteBaby_leavesNothingUnderTheBaby() async throws {
        let owner = try await FirebaseEmulator.signUp("owner")
        let uid = owner.uid
        let babyPath = "users/\(uid)/babies/b1"
        try await FirebaseEmulator.adminSet("users/\(uid)", ["babyCount": 2])
        try await FirebaseEmulator.adminSet(babyPath, ["name": "콩이"])
        let underBaby = ["activities", "growth", "diary", "vaccinations", "milestones", "hospitalVisits", "purchases",
                         "hospitalReports", "allergies", "cryRecords", "weeklyMetrics", "highlightCache", "trips"]
        for collection in underBaby {
            try await FirebaseEmulator.adminSet("\(babyPath)/\(collection)/d1", ["x": 1])
        }
        try await FirebaseEmulator.adminSet("\(babyPath)/activities/d2", ["x": 2])
        try await FirebaseEmulator.adminSet("\(babyPath)/trips/t2", ["city": "가상 도시"])
        try await FirebaseEmulator.adminSet("users/\(uid)/babies/b2", ["name": "둘째"])
        try await FirebaseEmulator.adminSet("users/\(uid)/babies/b2/activities/k1", ["x": 1])
        try await FirebaseEmulator.adminSet("users/\(uid)/todos/t1", ["x": 1])

        try await owner.service.deleteBaby("b1", userId: uid)

        let left = try await FirebaseEmulator.adminDocumentPaths(under: babyPath)
        XCTAssertEqual(left, [], "아기 아래 남은 문서: \(left)")
        let otherBaby = try await FirebaseEmulator.adminDocumentPaths(under: "users/\(uid)/babies/b2")
        XCTAssertEqual(Set(otherBaby), ["users/\(uid)/babies/b2", "users/\(uid)/babies/b2/activities/k1"])
        let todo = try await FirebaseEmulator.adminGet("users/\(uid)/todos/t1")
        XCTAssertNotNil(todo, "사용자 칸은 아기 삭제와 무관")
        let user = try await FirebaseEmulator.adminGet("users/\(uid)")
        XCTAssertEqual(user?["babyCount"] as? Int, 1)
    }

    /// 아기를 지우면 그 아기의 초대도 지운다(초대엔 아기 이름이 있다) — 다른 아기·남의 초대는 그대로.
    /// 고치기 전: 아기를 지워도 초대가 남아, 7일 안엔 받은 사람이 빈 아기 공유에 들어갈 수 있었고 이름은 영영 남았다.
    func test_deleteBaby_alsoDeletesThatBabysInvites() async throws {
        let owner = try await FirebaseEmulator.signUp("owner")
        let uid = owner.uid
        try await FirebaseEmulator.adminSet("users/\(uid)/babies/b1", ["name": "콩이"])
        try await seedInvite("AAAA22", owner: uid, baby: "b1")
        try await seedInvite("BBBB33", owner: uid, baby: "b1")
        try await seedInvite("CCCC44", owner: uid, baby: "b2")
        try await seedInvite("DDDD55", owner: "someoneElse", baby: "b1")

        try await owner.service.deleteBaby("b1", userId: uid)

        let aaaa = try await FirebaseEmulator.adminGet("invites/AAAA22")
        let bbbb = try await FirebaseEmulator.adminGet("invites/BBBB33")
        let cccc = try await FirebaseEmulator.adminGet("invites/CCCC44")
        let dddd = try await FirebaseEmulator.adminGet("invites/DDDD55")
        XCTAssertNil(aaaa, "지운 아기의 초대가 남았다")
        XCTAssertNil(bbbb, "지운 아기의 초대가 남았다")
        XCTAssertNotNil(cccc, "다른 아기 초대는 그대로")
        XCTAssertNotNil(dddd, "남의 초대는 그대로")
    }

    private func seedInvite(_ code: String, owner: String, baby: String) async throws {
        try await FirebaseEmulator.adminSet("invites/\(code)", [
            "code": code, "ownerUserId": owner, "babyId": baby, "babyName": "콩이",
            "createdAt": Date(), "expiresAt": Date().addingTimeInterval(86_400), "isUsed": false,
        ])
    }

    /// 기록이 많은 아기(한 묶음 400개를 넘는 기록)도 끝까지 지운다.
    func test_deleteBaby_withMoreRecordsThanOneBatch_deletesAll() async throws {
        let owner = try await FirebaseEmulator.signUp("owner")
        let uid = owner.uid
        let babyPath = "users/\(uid)/babies/b1"
        try await FirebaseEmulator.adminSet(babyPath, ["name": "콩이"])
        for index in 0..<450 {
            try await FirebaseEmulator.adminSet("\(babyPath)/activities/a\(index)", ["x": index])
        }

        try await owner.service.deleteBaby("b1", userId: uid)

        let left = try await FirebaseEmulator.adminDocumentPaths(under: babyPath)
        XCTAssertEqual(left.count, 0, "남은 문서 \(left.count)개")
    }
}
