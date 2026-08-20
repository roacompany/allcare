import Foundation

struct Activity: Identifiable, Codable, Hashable {
    var id: String
    var babyId: String
    var type: ActivityType
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval?
    /// feeding류 = 섭취 mL / feedingPumping = 생산(짜낸) mL.
    /// 합산 시 반드시 type/category 필터 필요 (섭취 ≠ 생산, 의료 정합 — spec §2/§4).
    var amount: Double?
    var side: BreastSide?
    var feedingContent: FeedingContent?   // 병수유 내용물(분유/유축한 모유). nil=분유(하위호환). feedingBottle에서만 의미.
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
    /// 활동을 기록한 보호자의 Firebase UID. nil = 과거 기록(소급 없음, 하위호환 optional).
    var createdBy: String?
    /// 유축(짜기) 배치 보관 방식 — 유통기한 산정 (feedingPumping 전용, 신규 optional). nil = 구 기록/미지정→냉장 가정.
    var pumpStorage: PumpStorage?
    /// 유축 배치 폐기 표시 — 재고 계산서 제외 (feedingPumping 전용, 신규 optional).
    var pumpDiscarded: Bool?

    /// 유축한 모유 병수유 — 섭취(.feeding)지만 'formula' 아님. 분유재고·분유량 집계서 제외용.
    var isBreastMilkBottle: Bool { type == .feedingBottle && feedingContent == .breastMilk }
    /// 진짜 분유(formula) 병수유 — 분유재고 차감·병원리포트 '분유량' 집계 대상(nil=분유).
    var isFormulaBottle: Bool { type == .feedingBottle && feedingContent != .breastMilk }
    /// 화면 라벨 — 유축한 모유 병수유(섭취)는 '모유(병)'. 유축(feedingPumping)은 생산.
    /// PO 지시(2026-07-12): '짜기'라는 말은 쓰지 않는다.
    var displayLabel: String { isBreastMilkBottle ? "모유(병)" : type.displayName }

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
        case feedingPumping = "feeding_pumping"
        /// 신버전이 추가한 미지의 type rawValue를 디코드한 read-only 센티넬 (forward-compat, 2026-06-09 spec).
        /// 구버전 가족기기가 모르는 종류를 만나도 문서 drop을 막기 위함. 절대 영속/picker/타이머/집계 노출 금지.
        case unknown = "unknown"

        /// init?(rawValue:)를 우회하는 raw-String 재구성 경로용 — 센티넬/미지 raw를 거부(드롭).
        /// (커스텀 init(from:)은 Decoder 경로만 관할하므로 rawValue 부활을 별도 차단)
        static func known(rawValue: String) -> ActivityType? {
            guard let type = ActivityType(rawValue: rawValue), type != .unknown else { return nil }
            return type
        }

        /// 미지의 rawValue를 .unknown으로 폴백 (throw 대신) → decodeDocuments compactMap이 문서를 살린다.
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = ActivityType(rawValue: raw) ?? .unknown
        }

        /// .unknown 은 read-only 센티넬 — 인코딩(=영속) 시 fail-loud. 실제 rawValue 덮어쓰기(데이터 손실) 봉쇄.
        /// 정상 type은 기존 synthesized와 동일하게 rawValue 단일값 인코딩.
        func encode(to encoder: Encoder) throws {
            guard self != .unknown else {
                throw EncodingError.invalidValue(self, EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "ActivityType.unknown은 read-only 센티넬이라 영속될 수 없다."
                ))
            }
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        var displayName: String {
            switch self {
            case .feedingBreast: "모유"
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
            case .feedingPumping: "유축"   // PO 지시: '짜기' 금지 — 짜는 행위 = 유축
            case .unknown: "앱 업데이트가 필요한 기록"
            }
        }

        var icon: String {
            switch self {
            case .feedingBreast: "figure.and.child.holdinghands"
            case .feedingBottle: "waterbottle.fill"          // 병(진단3: 커피잔→병) · 유축과는 색으로 구분
            case .feedingSolid: "fork.knife"
            case .feedingSnack: "carrot.fill"
            case .sleep: "moon.zzz.fill"
            case .diaperWet: "drop.fill"                      // 소변 = 물방울
            case .diaperDirty, .diaperBoth: "humidity.fill"  // 대변(+소변대변) = 습기 · 색이 주 변별자(SF Symbols 대변 심볼 부재)
            case .bath: "bathtub.fill"
            case .temperature: "thermometer.medium"
            case .medication: "pills.fill"
            case .feedingPumping: "drop.fill"
            case .unknown: "questionmark.circle"
            }
        }

        var color: String {
            switch self {
            case .feedingBreast, .feedingBottle: "feedingColor"
            case .feedingSolid, .feedingSnack: "solidColor"
            case .sleep: "sleepColor"
            case .diaperWet: "diaperColor"                       // 소변 = 앰버(현행)
            case .diaperDirty, .diaperBoth: "diaperDirtyColor"   // 대변(+소변대변) = 브라운(신규 · D4)
            case .bath: "bathColor"
            case .temperature: "temperatureColor"
            case .medication: "medicationColor"
            case .feedingPumping: "pumpingColor"
            case .unknown: "neutralGrayColor"
            }
        }

        /// 강조색 자산 이름 — 선택 상태·저장 버튼 등 흰 글자를 얹는 자리 전용 (기록 UX 재작업 2026-08-20).
        /// "한 활동 = 한 색": 표면은 `color`(파스텔), 강조는 같은 계열의 진한 톤. 폼별 색 하드코딩 금지 — 여기만 고친다.
        var emphasisColor: String {
            switch self {
            case .feedingBreast, .feedingBottle: "feedingEmphasisColor"
            case .feedingSolid, .feedingSnack: "solidEmphasisColor"
            case .sleep: "sleepEmphasisColor"
            case .diaperWet: "diaperEmphasisColor"
            case .diaperDirty, .diaperBoth: "diaperDirtyEmphasisColor"
            case .bath: "bathEmphasisColor"
            case .temperature: "temperatureEmphasisColor"
            case .medication: "medicationEmphasisColor"
            case .feedingPumping: "pumpingEmphasisColor"
            case .unknown: "neutralGrayColor"
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
            case .feedingPumping:
                return .pumping
            case .unknown:
                return .unknown
            }
        }

        // needs* 3종은 default: 없이 exhaustive 유지 (spec §4.1).
        // default:를 두면 신규 ActivityType이 silent false로 떨어져 입력 UX가 조용히 깨진다.
        var needsTimer: Bool {
            switch self {
            case .feedingBreast, .feedingBottle, .sleep:
                return true
            case .feedingSolid, .feedingSnack, .feedingPumping,
                 .diaperWet, .diaperDirty, .diaperBoth,
                 .bath, .temperature, .medication, .unknown:
                return false
            }
        }

        var needsAmount: Bool {
            switch self {
            case .feedingBottle, .feedingPumping:
                return true
            case .feedingBreast, .feedingSolid, .feedingSnack, .sleep,
                 .diaperWet, .diaperDirty, .diaperBoth,
                 .bath, .temperature, .medication, .unknown:
                return false
            }
        }

        var needsQuickInput: Bool {
            switch self {
            case .temperature, .medication, .feedingBottle, .feedingPumping:
                return true
            case .feedingBreast, .feedingSolid, .feedingSnack, .sleep,
                 .diaperWet, .diaperDirty, .diaperBoth, .bath, .unknown:
                return false
            }
        }
    }

    enum FeedingContent: String, Codable, CaseIterable {
        case formula = "formula"          // 분유 (rawValue = Firestore 영구계약)
        case breastMilk = "breast_milk"   // 유축한 모유
        /// 병수유 내용물 세그먼트의 단일 라벨 소스 — 짜둔 모유 먹인 "기록"의 이름은 어디서나 '모유(병)'.
        /// (2026-08-20 용어 한 벌: '유축'/'유축한 모유' 혼용 제거. '유축'은 생산 기록 전용.)
        var displayName: String {
            switch self {
            case .formula: "분유"
            case .breastMilk: "모유(병)"
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
        case feeding, sleep, diaper, health, pumping
        /// .unknown ActivityType의 중립 버킷 — 모든 집계(category == .feeding 등)에서 자동 배제.
        case unknown

        var displayName: String {
            switch self {
            case .feeding: "수유"
            case .sleep: "수면"
            case .diaper: "기저귀"
            case .health: "건강"
            case .pumping: "유축"
            case .unknown: "앱 업데이트가 필요한 기록"
            }
        }

        /// 카테고리 강조색 — 기록 폼 탭바의 선택 상태 전용 (타입 강조색과 같은 단일 소스 원칙).
        /// 기저귀=앰버(자산 diaperColor 계열), 건강=체온 계열(코랄 톤 대표).
        var emphasisColor: String {
            switch self {
            case .feeding: "feedingEmphasisColor"
            case .sleep: "sleepEmphasisColor"
            case .diaper: "diaperEmphasisColor"
            case .health: "temperatureEmphasisColor"
            case .pumping: "pumpingEmphasisColor"
            case .unknown: "neutralGrayColor"
            }
        }
    }

    // MARK: - 이유식 반응

    init(
        id: String = UUID().uuidString,
        babyId: String,
        type: ActivityType,
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval? = nil,
        amount: Double? = nil,
        side: BreastSide? = nil,
        feedingContent: FeedingContent? = nil,
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
        self.feedingContent = feedingContent
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
}
