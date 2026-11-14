import Foundation

struct FamilyInvite: Identifiable, Codable, Hashable {
    var id: String
    var code: String
    var ownerUserId: String
    var babyId: String
    var babyName: String
    var createdAt: Date
    var expiresAt: Date
    var isUsed: Bool

    init(
        id: String = UUID().uuidString,
        code: String = FamilyInvite.generateCode(),
        ownerUserId: String,
        babyId: String,
        babyName: String,
        createdAt: Date = Date(),
        expiresAt: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
        isUsed: Bool = false
    ) {
        self.id = id
        self.code = code
        self.ownerUserId = ownerUserId
        self.babyId = babyId
        self.babyName = babyName
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isUsed = isUsed
    }

    /// 초대 코드에 쓰는 글자 — 헷갈리는 I·O·0·1 은 뺐다. 만들기·고르기·거르기가 모두 이 한 곳을 본다.
    static let codeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    static let codeLength = 6

    static func generateCode() -> String {
        String((0..<codeLength).map { _ in codeAlphabet.randomElement()! })
    }

    /// 초대 문서 ID 로 써도 되는 코드인가 — 정확히 6글자 · 모두 `codeAlphabet`.
    /// 2026-11-11 규칙부터 문서 ID = 코드라서 입력이 그대로 경로가 된다. 「/」가 섞이면 경로가 바뀌고,
    /// 홀수 경로는 Firestore SDK 가 잡을 수 없는 예외(NSException)로 앱을 끈다 → 조회 전에 반드시 거른다.
    static func isWellFormedCode(_ code: String) -> Bool {
        true // RED 판: 아직 거르지 않는다(고치기 전 동작)
    }

    /// 받는 쪽 입력 칸 정리. RED 판: 고치기 전 화면 동작 그대로(대문자 + 앞 6글자).
    static func codeInput(from raw: String) -> String {
        String(raw.uppercased().prefix(codeLength))
    }

    /// 공유 시트로 보내는 초대 문구. 받는 사람은 여기 적힌 이름으로 앱스토어를 검색하므로
    /// 앱 이름은 문구에 따로 적지 않고 홈 화면 이름(CFBundleDisplayName)에서 가져온다.
    func shareText() -> String {
        "\(Self.homeScreenAppName) 가족 초대 코드: \(code)"
    }

    private static var homeScreenAppName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "베이비케어"
    }
}

struct SharedBabyAccess: Identifiable, Codable, Hashable {
    var id: String
    var ownerUserId: String
    var babyId: String
    var babyName: String
    var role: String // "viewer" or "editor"
    var joinedAt: Date
    /// 공유 멤버의 아기 관계 라벨 (CaregiverRelationship.rawValue). nil = 미설정(하위호환 optional).
    var relationship: String?
    /// 이 공유를 만든 초대코드. 신규 수락 시 항상 채움 — Firestore 규칙이 생성 시 교차검증한다.
    /// nil = 규칙 강화 이전에 만들어진 기존 공유(하위호환 optional).
    var inviteCode: String?

    init(
        id: String? = nil,
        ownerUserId: String,
        babyId: String,
        babyName: String,
        role: String = "editor",
        joinedAt: Date = Date(),
        relationship: String? = nil,
        inviteCode: String? = nil
    ) {
        self.id = id ?? "\(ownerUserId)_\(babyId)"
        self.ownerUserId = ownerUserId
        self.babyId = babyId
        self.babyName = babyName
        self.role = role
        self.joinedAt = joinedAt
        self.relationship = relationship
        self.inviteCode = inviteCode
    }
}
