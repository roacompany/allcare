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

    // ── 이유식/간식 상세 ─────────────────────────────────────
    var foodName: String?
    var solidStage: SolidStage?
    var foodAmount: String?           // "50g", "3숟가락" 등 자유 입력
    var allergyReaction: Bool?

    // ── 기저귀 상세 ──────────────────────────────────────────
    var stoolColor: StoolColor?
    var stoolConsistency: StoolConsistency?
    var hasRash: Bool?

    // ── 수면 상세 ────────────────────────────────────────────
    var sleepQuality: SleepQualityType?
    var sleepLocation: SleepLocationType?

    // ── 건강 상세 ────────────────────────────────────────────
    var medicationDosage: String?     // "5ml", "1정" 등
    var bathWaterTemp: Double?

    enum ActivityType: String, Codable, CaseIterable {
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
    }

    // MARK: - 이유식 단계
    enum SolidStage: String, Codable, CaseIterable {
        case early    = "early"     // 초기 (4~6개월)
        case mid      = "mid"       // 중기 (7~8개월)
        case late     = "late"      // 후기 (9~11개월)
        case complete = "complete"  // 완료기 (12개월~)

        var displayName: String {
            switch self {
            case .early:    "초기"
            case .mid:      "중기"
            case .late:     "후기"
            case .complete: "완료기"
            }
        }

        var ageHint: String {
            switch self {
            case .early:    "4~6개월"
            case .mid:      "7~8개월"
            case .late:     "9~11개월"
            case .complete: "12개월~"
            }
        }
    }

    // MARK: - 대변 색상
    enum StoolColor: String, Codable, CaseIterable {
        case yellow    = "yellow"
        case green     = "green"
        case brown     = "brown"
        case dark      = "dark"
        case red       = "red"       // 혈변 — 의사 상담 필요
        case white     = "white"     // 백색변 — 즉시 진료

        var displayName: String {
            switch self {
            case .yellow: "노란색"
            case .green:  "녹색"
            case .brown:  "갈색"
            case .dark:   "짙은색"
            case .red:    "붉은색"
            case .white:  "흰색"
            }
        }

        var colorHex: String {
            switch self {
            case .yellow: "E8C547"
            case .green:  "6B9E5E"
            case .brown:  "8B6914"
            case .dark:   "4A3728"
            case .red:    "C94444"
            case .white:  "E8E4DE"
            }
        }

        /// 의료 주의가 필요한 색상
        var needsAttention: Bool {
            self == .red || self == .white
        }
    }

    // MARK: - 대변 상태
    enum StoolConsistency: String, Codable, CaseIterable {
        case watery  = "watery"
        case soft    = "soft"
        case normal  = "normal"
        case hard    = "hard"

        var displayName: String {
            switch self {
            case .watery: "묽음"
            case .soft:   "무름"
            case .normal: "보통"
            case .hard:   "딱딱함"
            }
        }

        var icon: String {
            switch self {
            case .watery: "drop.fill"
            case .soft:   "cloud.fill"
            case .normal: "circle.fill"
            case .hard:   "square.fill"
            }
        }
    }

    // MARK: - 수면 질
    enum SleepQualityType: String, Codable, CaseIterable {
        case good  = "good"
        case fussy = "fussy"
        case light = "light"

        var displayName: String {
            switch self {
            case .good:  "잘 잠"
            case .fussy: "뒤척임"
            case .light: "얕은 수면"
            }
        }

        var icon: String {
            switch self {
            case .good:  "moon.fill"
            case .fussy: "figure.walk"
            case .light: "cloud.moon.fill"
            }
        }
    }

    // MARK: - 수면 장소
    enum SleepLocationType: String, Codable, CaseIterable {
        case crib      = "crib"
        case bed       = "bed"
        case stroller  = "stroller"
        case carSeat   = "car_seat"
        case arms      = "arms"

        var displayName: String {
            switch self {
            case .crib:     "아기침대"
            case .bed:      "부모침대"
            case .stroller: "유모차"
            case .carSeat:  "카시트"
            case .arms:     "안아서"
            }
        }

        var icon: String {
            switch self {
            case .crib:     "bed.double.fill"
            case .bed:      "bed.double"
            case .stroller: "figure.walk"
            case .carSeat:  "car.fill"
            case .arms:     "figure.and.child.holdinghands"
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
        solidStage: SolidStage? = nil,
        foodAmount: String? = nil,
        allergyReaction: Bool? = nil,
        stoolColor: StoolColor? = nil,
        stoolConsistency: StoolConsistency? = nil,
        hasRash: Bool? = nil,
        sleepQuality: SleepQualityType? = nil,
        sleepLocation: SleepLocationType? = nil,
        medicationDosage: String? = nil,
        bathWaterTemp: Double? = nil
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
        self.solidStage = solidStage
        self.foodAmount = foodAmount
        self.allergyReaction = allergyReaction
        self.stoolColor = stoolColor
        self.stoolConsistency = stoolConsistency
        self.hasRash = hasRash
        self.sleepQuality = sleepQuality
        self.sleepLocation = sleepLocation
        self.medicationDosage = medicationDosage
        self.bathWaterTemp = bathWaterTemp
    }
}
