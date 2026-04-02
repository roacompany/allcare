import Foundation

struct Baby: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var birthDate: Date
    var gender: Gender
    var bloodType: BloodType?
    var photoURL: String?
    var createdAt: Date
    var updatedAt: Date
    /// The Firebase UID of the user who owns this baby's data.
    /// nil means the baby belongs to the current user (own baby).
    /// Non-nil means this is a shared baby and data should be fetched from ownerUserId's path.
    var ownerUserId: String?

    enum Gender: String, Codable, CaseIterable {
        case male = "male"
        case female = "female"

        var displayName: String {
            switch self {
            case .male: "남아"
            case .female: "여아"
            }
        }

        var emoji: String {
            switch self {
            case .male: "👦"
            case .female: "👧"
            }
        }
    }

    enum BloodType: String, Codable, CaseIterable {
        case aPlus = "A+"
        case aMinus = "A-"
        case bPlus = "B+"
        case bMinus = "B-"
        case oPlus = "O+"
        case oMinus = "O-"
        case abPlus = "AB+"
        case abMinus = "AB-"
    }

    var ageText: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: birthDate, to: Date())
        if let year = components.year, year > 0 {
            return "\(year)세 \(components.month ?? 0)개월"
        } else if let month = components.month, month > 0 {
            return "\(month)개월 \(components.day ?? 0)일"
        } else {
            return "\(components.day ?? 0)일"
        }
    }

    var daysOld: Int {
        Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        birthDate: Date,
        gender: Gender,
        bloodType: BloodType? = nil,
        photoURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.bloodType = bloodType
        self.photoURL = photoURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
