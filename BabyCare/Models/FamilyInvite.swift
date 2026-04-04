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
}

struct SharedBabyAccess: Identifiable, Codable, Hashable {
    var id: String
    var ownerUserId: String
    var babyId: String
    var babyName: String
    var role: String // "viewer" or "editor"
    var joinedAt: Date

    init(
        id: String? = nil,
        ownerUserId: String,
        babyId: String,
        babyName: String,
        role: String = "editor",
        joinedAt: Date = Date()
    ) {
        self.id = id ?? "\(ownerUserId)_\(babyId)"
        self.ownerUserId = ownerUserId
        self.babyId = babyId
        self.babyName = babyName
        self.role = role
        self.joinedAt = joinedAt
    }
}
