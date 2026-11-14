import XCTest
@testable import BabyCare

/// 가족 초대 코드 — 받는 쪽 입력 칸과 서버 조회 사이의 약속.
/// 초대 문서 ID = 초대 코드(2026-11-11 규칙). 그래서 입력 글자가 그대로 문서 경로가 된다 —
/// 「/」 하나가 경로를 바꾸고, 홀수 경로는 Firestore SDK 가 잡을 수 없는 예외로 앱을 끈다.
final class FamilyInviteCodeTests: XCTestCase {

    // MARK: - 받는 쪽 입력 칸 (FamilyInvite.codeInput)

    /// 초대한 사람은 공유 문구를 통째로 보낸다 → 받는 사람이 문구를 통째로 붙여 넣어도 코드가 남아야 한다.
    /// (고치기 전: 앞 6글자 「베이비케어 」만 남아 「유효하지 않은 코드입니다.」)
    func test_codeInput_pastedShareText_keepsOnlyTheCode() {
        XCTAssertEqual(FamilyInvite.codeInput(from: "베이비케어 가족 초대 코드: K7MNP2"), "K7MNP2")
        XCTAssertEqual(FamilyInvite.codeInput(from: "베이비케어 가족 초대 코드: K7MNP2\n"), "K7MNP2")
        XCTAssertEqual(FamilyInvite.codeInput(from: "BabyCare 가족 초대 코드: K7MNP2"), "K7MNP2",
                       "앱 이름이 영문 대문자여도 6글자 덩어리만 코드로 본다")
    }

    /// 앱이 실제로 만든 공유 문구를 그대로 붙여 넣는 경우.
    func test_codeInput_appGeneratedShareText_roundTrips() {
        let invite = FamilyInvite(code: "R8WX3D", ownerUserId: "o", babyId: "b", babyName: "콩이")
        XCTAssertEqual(FamilyInvite.codeInput(from: invite.shareText()), "R8WX3D")
    }

    func test_codeInput_lowercaseAndSurroundingSpaces_areNormalized() {
        XCTAssertEqual(FamilyInvite.codeInput(from: " k7mnp2 "), "K7MNP2")
        XCTAssertEqual(FamilyInvite.codeInput(from: "k7mnp2"), "K7MNP2")
    }

    /// 문서 경로를 바꾸는 글자(「/」)와 그 밖의 기호는 칸에 남지 않는다.
    func test_codeInput_neverKeepsPathSeparatorsOrSymbols() {
        XCTAssertEqual(FamilyInvite.codeInput(from: "ab/cd23"), "ABCD23")
        XCTAssertEqual(FamilyInvite.codeInput(from: "../AB2"), "AB2")
        XCTAssertEqual(FamilyInvite.codeInput(from: "a.b_c-d"), "ABCD")
        XCTAssertFalse(FamilyInvite.codeInput(from: "K7/NP2").contains("/"))
    }

    /// 한 글자씩 칠 때 칸이 글자를 바꾸거나 지우면 안 된다(onChange 가 다시 부른다).
    func test_codeInput_typingOneLetterAtATime_isKeptAsTyped() {
        XCTAssertEqual(FamilyInvite.codeInput(from: ""), "")
        XCTAssertEqual(FamilyInvite.codeInput(from: "k"), "K")
        XCTAssertEqual(FamilyInvite.codeInput(from: "K7"), "K7")
        XCTAssertEqual(FamilyInvite.codeInput(from: "K7M"), "K7M")
        for typed in ["K", "K7M", "K7MNP2", "AB2"] {
            XCTAssertEqual(FamilyInvite.codeInput(from: typed), typed, "이미 정리된 글자는 그대로: \(typed)")
        }
    }

    func test_codeInput_seventhLetter_isIgnored() {
        XCTAssertEqual(FamilyInvite.codeInput(from: "K7MNP2X"), "K7MNP2")
    }

    // MARK: - 조회 전에 거르는 판정 (FamilyInvite.isWellFormedCode)

    func test_isWellFormedCode_acceptsEveryGeneratedCode() {
        for _ in 0..<300 {
            let code = FamilyInvite.generateCode()
            XCTAssertTrue(FamilyInvite.isWellFormedCode(code), "앱이 만든 코드는 늘 통과해야 한다: \(code)")
        }
    }

    func test_isWellFormedCode_rejectsAnythingThatCannotBeAnInvite() {
        for bad in ["", "K7MNP", "K7MNP2X", "K7/NP2", "../AB2", "k7mnp2", "K7MNP1", "K7MNPO", "K7 NP2", "가나다라마바"] {
            XCTAssertFalse(FamilyInvite.isWellFormedCode(bad), "초대 코드가 될 수 없다: \(bad)")
        }
    }

    // MARK: - 서버 조회 (FirestoreService.findInviteByCode)

    /// 고치기 전: 「K7/NP2」 → invites/K7/NP2 (홀수 경로) → Firestore SDK 가 NSException 을 던져 앱이 꺼진다.
    /// 판정에서 걸러 nil(→ 「유효하지 않은 코드입니다.」)로 끝나야 한다. 이 시험은 서버에 닿지 않는다.
    func test_findInviteByCode_malformedCode_returnsNilInsteadOfCrashing() async throws {
        let found = try await FirestoreService.shared.findInviteByCode("K7/NP2")
        XCTAssertNil(found)
    }
}
