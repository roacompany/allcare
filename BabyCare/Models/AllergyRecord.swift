import Foundation

enum AllergyReactionType: String, Codable, CaseIterable {
    case skin = "skin"
    case digestive = "digestive"
    case respiratory = "respiratory"
    case other = "other"

    var displayName: String {
        switch self {
        case .skin: return "피부"
        case .digestive: return "소화기"
        case .respiratory: return "호흡기"
        case .other: return "기타"
        }
    }
}

enum AllergySeverity: String, Codable, CaseIterable {
    case mild = "mild"
    case moderate = "moderate"
    case severe = "severe"

    var displayName: String {
        switch self {
        case .mild: return "경증"
        case .moderate: return "중등"
        case .severe: return "중증"
        }
    }
}

enum CommonAllergen: String, Codable, CaseIterable {
    case dairy = "dairy"
    case egg = "egg"
    case peanut = "peanut"
    case wheat = "wheat"
    case soy = "soy"
    case shrimp = "shrimp"
    case crab = "crab"
    case peach = "peach"
    case walnut = "walnut"
    case other = "other"

    var displayName: String {
        switch self {
        case .dairy: return "우유"
        case .egg: return "계란"
        case .peanut: return "땅콩"
        case .wheat: return "밀"
        case .soy: return "대두"
        case .shrimp: return "새우"
        case .crab: return "게"
        case .peach: return "복숭아"
        case .walnut: return "호두"
        case .other: return "기타"
        }
    }
}

struct AllergyRecord: Identifiable, Codable, Hashable {
    var id: String
    var babyId: String
    var allergenName: String
    var reactionType: AllergyReactionType
    var severity: AllergySeverity
    var date: Date
    var symptoms: [String]
    var note: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        babyId: String,
        allergenName: String,
        reactionType: AllergyReactionType = .skin,
        severity: AllergySeverity = .mild,
        date: Date = Date(),
        symptoms: [String] = [],
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.babyId = babyId
        self.allergenName = allergenName
        self.reactionType = reactionType
        self.severity = severity
        self.date = date
        self.symptoms = symptoms
        self.note = note
        self.createdAt = createdAt
    }
}
