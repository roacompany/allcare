import Foundation

struct HospitalVisit: Identifiable, Codable, Hashable {
    var id: String
    var babyId: String
    var visitType: VisitType
    var hospitalName: String
    var department: String?
    var doctorName: String?
    var visitDate: Date
    var purpose: String?
    var diagnosis: String?
    var prescription: String?
    var cost: Int?
    var nextVisitDate: Date?
    var scheduledDate: Date?
    var note: String?
    var createdAt: Date

    enum VisitType: String, Codable, CaseIterable {
        case regular = "regular"
        case sick = "sick"
        case vaccination = "vaccination"
        case emergency = "emergency"
        case checkup = "checkup"
        case dental = "dental"
        case eyeCare = "eye_care"
        case other = "other"

        var displayName: String {
            switch self {
            case .regular: "정기검진"
            case .sick: "진료"
            case .vaccination: "예방접종"
            case .emergency: "응급"
            case .checkup: "건강검진"
            case .dental: "치과"
            case .eyeCare: "안과"
            case .other: "기타"
            }
        }

        var icon: String {
            switch self {
            case .regular: "stethoscope"
            case .sick: "cross.case.fill"
            case .vaccination: "syringe.fill"
            case .emergency: "light.beacon.max.fill"
            case .checkup: "list.clipboard.fill"
            case .dental: "mouth.fill"
            case .eyeCare: "eye.fill"
            case .other: "building.2.fill"
            }
        }

        var color: String {
            switch self {
            case .regular: "9FB5FF"
            case .sick: "FF9F9F"
            case .vaccination: "FF9FB5"
            case .emergency: "FF6B6B"
            case .checkup: "9FDFBF"
            case .dental: "FFD59F"
            case .eyeCare: "D59FFF"
            case .other: "B5B5B5"
            }
        }
    }

    var isUpcoming: Bool {
        visitDate > Date()
    }

    var isPast: Bool {
        visitDate <= Date()
    }

    var hasNextVisit: Bool {
        nextVisitDate != nil
    }

    init(
        id: String = UUID().uuidString,
        babyId: String,
        visitType: VisitType = .sick,
        hospitalName: String,
        department: String? = nil,
        doctorName: String? = nil,
        visitDate: Date = Date(),
        purpose: String? = nil,
        diagnosis: String? = nil,
        prescription: String? = nil,
        cost: Int? = nil,
        nextVisitDate: Date? = nil,
        scheduledDate: Date? = nil,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.babyId = babyId
        self.visitType = visitType
        self.hospitalName = hospitalName
        self.department = department
        self.doctorName = doctorName
        self.visitDate = visitDate
        self.purpose = purpose
        self.diagnosis = diagnosis
        self.prescription = prescription
        self.cost = cost
        self.nextVisitDate = nextVisitDate
        self.scheduledDate = scheduledDate
        self.note = note
        self.createdAt = createdAt
    }
}

// MARK: - Recent Hospitals (UserDefaults)

enum RecentHospitals {
    private static let key = "recentHospitals"
    private static let maxCount = 10

    static var list: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var hospitals = list.filter { $0 != trimmed }
        hospitals.insert(trimmed, at: 0)
        if hospitals.count > maxCount {
            hospitals = Array(hospitals.prefix(maxCount))
        }
        UserDefaults.standard.set(hospitals, forKey: key)
    }
}
