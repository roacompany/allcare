import FirebaseFirestore
import XCTest
@testable import BabyCare

/// 계정 삭제 — 실제 FirestoreService·FirebaseAuth(에뮬레이터)를 레포 규칙에서(`make emulator-test`).
@MainActor
final class EmulatorAccountDeletionTests: XCTestCase {

    override func setUp() async throws {
        try await FirebaseEmulator.requireRunning()
        try await FirebaseEmulator.reset()
    }

    /// 그 사람 아래 기록이 있을 수 있는 자리 전부 — 사용자 칸 · 아기 둘(+그 아래 전부) · 임신(+그 아래 전부) · 가족 공유 표.
    /// (이름은 손으로 적는다 — 앱의 목록 상수를 그대로 쓰면 빠진 이름을 이 시험도 같이 빠뜨린다.)
    private func seedEverything(for uid: String) async throws {
        try await FirebaseEmulator.adminSet("users/\(uid)", ["babyCount": 2, "displayName": "떠나는 사람"])
        let underUser = ["todos", "routines", "dayPlans", "dayRuns", "products", "purchases", "hospitalVisits",
                         "vaccinations", "milestones", "diary", "premiumStatus", "sharedAccess", "fcmTokens",
                         "badges", "stats"]
        for collection in underUser {
            try await FirebaseEmulator.adminSet("users/\(uid)/\(collection)/d1", ["x": 1])
        }
        let underBaby = ["activities", "growth", "diary", "vaccinations", "milestones", "hospitalVisits", "purchases",
                         "hospitalReports", "allergies", "cryRecords", "weeklyMetrics", "highlightCache", "trips"]
        for baby in ["b1", "b2"] {
            try await FirebaseEmulator.adminSet("users/\(uid)/babies/\(baby)", ["name": baby])
            for collection in underBaby {
                try await FirebaseEmulator.adminSet("users/\(uid)/babies/\(baby)/\(collection)/d1", ["x": 1])
            }
        }
        let underPregnancy = ["kickSessions", "prenatalVisits", "pregnancyChecklists", "pregnancyWeights",
                              "pregnancySymptoms", "pregnancyVitals", "contractionSessions", "pregnancyMoods"]
        try await FirebaseEmulator.adminSet("users/\(uid)/pregnancies/p1", ["outcome": "ongoing"])
        for collection in underPregnancy {
            try await FirebaseEmulator.adminSet("users/\(uid)/pregnancies/p1/\(collection)/d1", ["x": 1])
        }
    }

    private func seedSomeoneElse() async throws {
        try await FirebaseEmulator.adminSet("users/stayer", ["babyCount": 1])
        try await FirebaseEmulator.adminSet("users/stayer/babies/sb", ["name": "남의 아기"])
        try await FirebaseEmulator.adminSet("users/stayer/babies/sb/activities/a1", ["x": 1])
    }

    /// 로그인한 채로 지우면 그 사람 아래엔 아무것도 남지 않는다. 남의 기록은 그대로.
    /// 고치기 전(deleteAllUserData): 목록 13개 중 규칙이 없는 activities 에서 던져 아무것도 커밋되지 않았고,
    /// 아기 밑 기록(수유·수면…)은 애초에 대상이 아니었다.
    func test_eraseAllUserData_leavesNothingOfThatPerson() async throws {
        let person = try await FirebaseEmulator.signUp("leaver")
        try await seedEverything(for: person.uid)
        try await seedSomeoneElse()

        try await person.service.eraseAllUserData(userId: person.uid)

        let left = try await FirebaseEmulator.adminDocumentPaths(under: "users/\(person.uid)")
        XCTAssertEqual(left, [], "남은 문서 \(left.count)개: \(left.prefix(10))")
        let other = try await FirebaseEmulator.adminDocumentPaths(under: "users/stayer")
        XCTAssertEqual(Set(other), ["users/stayer", "users/stayer/babies/sb", "users/stayer/babies/sb/activities/a1"])
    }

    /// 계정을 지우면 내가 만든 초대도 전부 지운다(아기 이름이 든 개인정보) — 남의 초대는 그대로.
    /// 고치기 전: 계정 삭제 뒤에도 초대가 영영 남았다(만료는 「못 씀」일 뿐 지우지 않는다 · 무료 요금제라 TTL 도 없다).
    func test_eraseAllUserData_alsoDeletesMyInvites() async throws {
        let person = try await FirebaseEmulator.signUp("leaver")
        let uid = person.uid
        for (code, baby) in [("AAAA22", "b1"), ("BBBB33", "b2")] {
            try await FirebaseEmulator.adminSet("invites/\(code)", [
                "code": code, "ownerUserId": uid, "babyId": baby, "babyName": "콩이",
                "createdAt": Date(), "expiresAt": Date().addingTimeInterval(86_400), "isUsed": false,
            ])
        }
        try await FirebaseEmulator.adminSet("invites/DDDD55", [
            "code": "DDDD55", "ownerUserId": "someoneElse", "babyId": "x", "babyName": "남의 아기",
            "createdAt": Date(), "expiresAt": Date().addingTimeInterval(86_400), "isUsed": false,
        ])

        try await person.service.eraseAllUserData(userId: uid)

        let mine1 = try await FirebaseEmulator.adminGet("invites/AAAA22")
        let mine2 = try await FirebaseEmulator.adminGet("invites/BBBB33")
        let theirs = try await FirebaseEmulator.adminGet("invites/DDDD55")
        XCTAssertNil(mine1)
        XCTAssertNil(mine2)
        XCTAssertNotNil(theirs, "남의 초대는 그대로")
    }

    /// 실제 로그인(Auth 에뮬레이터)으로 전 과정: 기록 → 로그인. 끝나면 계정도 기록도 없다.
    /// 고치기 전 순서(로그인 먼저)에선 기록 정리가 로그인 없이 나가 규칙에 막혀, 기록이 전부 남은 채 「삭제됨」이었다.
    func test_accountDeletion_withRealLogin_removesRecordsThenLogin() async throws {
        let person = try await FirebaseEmulator.signUp("leaver")
        let uid = person.uid
        try await seedEverything(for: uid)
        let deletion = AccountDeletion(
            auth: FirebaseAccountAuth(auth: person.auth),
            data: person.service,
            photos: MockStorageService(),
            pushToken: {},
            now: { Date() }
        )

        let outcome = await deletion.run()

        XCTAssertEqual(outcome, .deleted)
        let loginLeft = try await FirebaseEmulator.authUserExists(uid: uid)
        XCTAssertFalse(loginLeft, "로그인 계정이 남았다")
        let left = try await FirebaseEmulator.adminDocumentPaths(under: "users/\(uid)")
        XCTAssertEqual(left, [], "남은 문서 \(left.count)개: \(left.prefix(10))")
    }
}
