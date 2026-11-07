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

    static func generateCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
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

    init(
        id: String? = nil,
        ownerUserId: String,
        babyId: String,
        babyName: String,
        role: String = "editor",
        joinedAt: Date = Date(),
        relationship: String? = nil
    ) {
        self.id = id ?? "\(ownerUserId)_\(babyId)"
        self.ownerUserId = ownerUserId
        self.babyId = babyId
        self.babyName = babyName
        self.role = role
        self.joinedAt = joinedAt
        self.relationship = relationship
    }
}
