import Foundation

/// 저장 진입점(풀폼/빠른기록/미니시트)이 공통으로 채우는 순수 입력 스냅샷.
/// VM 라이브 상태(타이머 등)를 여기서 값으로 고정 → Builder는 부수효과 없이 매핑만.
struct ActivityDraft: Equatable {
    var babyId: String
    var type: Activity.ActivityType

    // 시간/타이머 (VM이 stopTimer/수동조정 해석 후 값으로 주입)
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval?
    var wasManuallyAdjusted: Bool = false

    // 타입별 값 (해당 없으면 무시)
    var side: Activity.BreastSide?
    var amountText: String = ""          // "" = 미입력; 검증은 Builder
    var feedingContent: Activity.FeedingContent = .formula
    var foodName: String = ""
    var foodAmount: String = ""
    var foodReaction: Activity.FoodReaction?
    var temperatureText: String = ""
    var medicationName: String = ""
    var medicationDosage: String = ""
    var sleepQuality: Activity.SleepQualityType?
    var sleepMethod: Activity.SleepMethodType?
    var stoolColor: Activity.StoolColor?
    var stoolConsistency: Activity.StoolConsistency?
    var hasRash: Bool = false
    var note: String = ""

    init(babyId: String, type: Activity.ActivityType, startTime: Date = Date()) {
        self.babyId = babyId
        self.type = type
        self.startTime = startTime
    }
}

/// 기록 저장 전 검증 실패 사유. message 는 사용자 노출 문구(현행 문구 보존).
enum RecordValidationError: Error, Equatable {
    case invalidAmount(isPumping: Bool)   // 수유/유축량 1~500ml 밖 (문구만 구분)
    case invalidTemperature               // 체온 34.0~43.0°C 밖
    case tooShort                         // duration < 1초 (수동조정 예외)
    case sleepTooLong                     // 수면 duration > 24h
    case unknownType                      // .unknown 센티넬 (영속 불가)

    var message: String {
        switch self {
        case .invalidAmount(let isPumping):
            isPumping ? "유축량을 올바르게 입력해주세요. (1~500ml)"
                      : "수유량을 올바르게 입력해주세요. (1~500ml)"
        case .invalidTemperature: "체온을 올바르게 입력해주세요. (34.0~43.0°C)"
        case .tooShort: "최소 1초 이상 기록해주세요."
        case .sleepTooLong: "수면 시간이 24시간을 초과합니다. 시간을 확인해주세요."
        case .unknownType: "지원하지 않는 기록입니다."
        }
    }
}
