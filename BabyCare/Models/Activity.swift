import Foundation

struct Activity: Identifiable, Codable, Hashable {
    var id: String
    var babyId: String
    var type: ActivityType
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval?
    var amount: Double?
    var side: BreastSide?
    var note: String?
    var photoURL: String?
    var temperature: Double?
    var medicationName: String?
    var createdAt: Date

    // 기록 UX 강화 필드 (모두 optional — Firestore 호환, 마이그레이션 불필요)
    var foodName: String?
    var foodAmount: String?
    var foodReaction: FoodReaction?
    var stoolColor: StoolColor?
    var stoolConsistency: StoolConsistency?
    var hasRash: Bool?
    var sleepQuality: SleepQualityType?
    var sleepMethod: SleepMethodType?
    var medicationDosage: String?

    enum ActivityType: String, Codable, CaseIterable, Identifiable {
        var id: String { rawValue }
        case feedingBreast = "feeding_breast"
        case feedingBottle = "feeding_bottle"
        case feedingSolid = "feeding_solid"
        case feedingSnack = "feeding_snack"
        case sleep = "sleep"
        case diaperWet = "diaper_wet"
        case diaperDirty = "diaper_dirty"
        case diaperBoth = "diaper_both"
        case bath = "bath"
        case temperature = "temperature"
        case medication = "medication"

        var displayName: String {
            switch self {
            case .feedingBreast: "모유수유"
            case .feedingBottle: "분유"
            case .feedingSolid: "이유식"
            case .feedingSnack: "간식"
            case .sleep: "수면"
            case .diaperWet: "소변"
            case .diaperDirty: "대변"
            case .diaperBoth: "소변+대변"
            case .bath: "목욕"
            case .temperature: "체온"
            case .medication: "투약"
            }
        }

        var icon: String {
            switch self {
            case .feedingBreast: "figure.and.child.holdinghands"
            case .feedingBottle: "cup.and.saucer.fill"
            case .feedingSolid: "fork.knife"
            case .feedingSnack: "carrot.fill"
            case .sleep: "moon.zzz.fill"
            case .diaperWet, .diaperDirty, .diaperBoth: "humidity.fill"
            case .bath: "bathtub.fill"
            case .temperature: "thermometer.medium"
            case .medication: "pills.fill"
            }
        }

        var color: String {
            switch self {
            case .feedingBreast, .feedingBottle: "feedingColor"
            case .feedingSolid, .feedingSnack: "solidColor"
            case .sleep: "sleepColor"
            case .diaperWet, .diaperDirty, .diaperBoth: "diaperColor"
            case .bath: "bathColor"
            case .temperature: "temperatureColor"
            case .medication: "medicationColor"
            }
        }

        var category: ActivityCategory {
            switch self {
            case .feedingBreast, .feedingBottle, .feedingSolid, .feedingSnack:
                return .feeding
            case .sleep:
                return .sleep
            case .diaperWet, .diaperDirty, .diaperBoth:
                return .diaper
            case .bath, .temperature, .medication:
                return .health
            }
        }

        var needsTimer: Bool {
            switch self {
            case .feedingBreast, .feedingBottle, .sleep:
                return true
            default:
                return false
            }
        }

        var needsAmount: Bool {
            switch self {
            case .feedingBottle:
                return true
            default:
                return false
            }
        }

        var needsQuickInput: Bool {
            switch self {
            case .temperature, .medication, .feedingBottle:
                return true
            default:
                return false
            }
        }
    }

    enum BreastSide: String, Codable, CaseIterable {
        case left = "L"
        case right = "R"
        case both = "B"

        var displayName: String {
            switch self {
            case .left: "왼쪽"
            case .right: "오른쪽"
            case .both: "양쪽"
            }
        }
    }

    enum ActivityCategory: String, CaseIterable {
        case feeding, sleep, diaper, health

        var displayName: String {
            switch self {
            case .feeding: "수유"
            case .sleep: "수면"
            case .diaper: "기저귀"
            case .health: "건강"
            }
        }
    }

    // MARK: - 이유식 반응

    enum FoodReaction: String, Codable, CaseIterable {
        case good, normal, refused, allergy

        var displayName: String {
            switch self {
            case .good: "잘 먹음"
            case .normal: "보통"
            case .refused: "안 먹음"
            case .allergy: "알레르기 반응"
            }
        }

        var icon: String {
            switch self {
            case .good: "hand.thumbsup.fill"
            case .normal: "minus.circle.fill"
            case .refused: "hand.thumbsdown.fill"
            case .allergy: "exclamationmark.triangle.fill"
            }
        }

        var needsAttention: Bool { self == .allergy }
    }

    // MARK: - 대변 색상

    enum StoolColor: String, Codable, CaseIterable {
        case yellow, green, brown, dark, red, white

        var displayName: String {
            switch self {
            case .yellow: "노란색"
            case .green: "녹색"
            case .brown: "갈색"
            case .dark: "짙은색"
            case .red: "붉은색"
            case .white: "흰색"
            }
        }

        var colorHex: String {
            switch self {
            case .yellow: "DAA520"
            case .green: "4CAF50"
            case .brown: "8B4513"
            case .dark: "3E2723"
            case .red: "D32F2F"
            case .white: "E0E0E0"
            }
        }

        var needsAttention: Bool {
            self == .red || self == .white
        }
    }

    // MARK: - 대변 농도

    enum StoolConsistency: String, Codable, CaseIterable {
        case watery, soft, normal, hard

        var displayName: String {
            switch self {
            case .watery: "묽음"
            case .soft: "무름"
            case .normal: "보통"
            case .hard: "딱딱함"
            }
        }

        var icon: String {
            switch self {
            case .watery: "drop.fill"
            case .soft: "cloud.fill"
            case .normal: "circle.fill"
            case .hard: "diamond.fill"
            }
        }
    }

    // MARK: - 수면 질

    enum SleepQualityType: String, Codable, CaseIterable {
        case good, fussy, light

        var displayName: String {
            switch self {
            case .good: "잘 잠"
            case .fussy: "뒤척임"
            case .light: "얕은 수면"
            }
        }

        var icon: String {
            switch self {
            case .good: "moon.fill"
            case .fussy: "figure.walk"
            case .light: "cloud.moon.fill"
            }
        }
    }

    // MARK: - 잠드는 방법

    enum SleepMethodType: String, Codable, CaseIterable {
        case selfSettled, nursing, holding, stroller, carSeat

        var displayName: String {
            switch self {
            case .selfSettled: "스스로"
            case .nursing: "수유 중"
            case .holding: "안아서"
            case .stroller: "유모차"
            case .carSeat: "카시트"
            }
        }

        var icon: String {
            switch self {
            case .selfSettled: "bed.double.fill"
            case .nursing: "figure.and.child.holdinghands"
            case .holding: "hands.and.sparkles.fill"
            case .stroller: "stroller.fill"
            case .carSeat: "car.fill"
            }
        }
    }

    var durationText: String? {
        guard let duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }
        return "\(minutes)분"
    }

    var amountText: String? {
        guard let amount else { return nil }
        return "\(Int(amount))ml"
    }

    init(
        id: String = UUID().uuidString,
        babyId: String,
        type: ActivityType,
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval? = nil,
        amount: Double? = nil,
        side: BreastSide? = nil,
        note: String? = nil,
        photoURL: String? = nil,
        temperature: Double? = nil,
        medicationName: String? = nil,
        createdAt: Date = Date(),
        foodName: String? = nil,
        foodAmount: String? = nil,
        foodReaction: FoodReaction? = nil,
        stoolColor: StoolColor? = nil,
        stoolConsistency: StoolConsistency? = nil,
        hasRash: Bool? = nil,
        sleepQuality: SleepQualityType? = nil,
        sleepMethod: SleepMethodType? = nil,
        medicationDosage: String? = nil
    ) {
        self.id = id
        self.babyId = babyId
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.amount = amount
        self.side = side
        self.note = note
        self.photoURL = photoURL
        self.temperature = temperature
        self.medicationName = medicationName
        self.createdAt = createdAt
        self.foodName = foodName
        self.foodAmount = foodAmount
        self.foodReaction = foodReaction
        self.stoolColor = stoolColor
        self.stoolConsistency = stoolConsistency
        self.hasRash = hasRash
        self.sleepQuality = sleepQuality
        self.sleepMethod = sleepMethod
        self.medicationDosage = medicationDosage
    }
}
