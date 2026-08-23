import AppIntents
import Foundation

/// 시리 문구에 들어가는 기록 종류 — 「베이비케어에 ⟨소변⟩ 기록」의 ⟨…⟩ 자리.
///
/// `AppEnum` 이라 시리가 말 속에서 값을 바로 집어낸다(되묻기 없음).
/// ⚠️ `rawValue` 는 **손님이 단축어 앱에 만들어 둔 것에 저장된다** — 바꾸면 그 단축어가 깨진다.
enum SiriRecordKindOption: String, AppEnum {
    case breast, bottleFormula, bottleBreastMilk, pumping, solid, snack
    case diaperWet, diaperDirty, bath, temperature, medication

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "기록 종류"

    /// 화면 라벨과 같은 말을 쓴다 — 손님이 앱에서 본 낱말 그대로 부를 수 있어야 한다.
    static let caseDisplayRepresentations: [SiriRecordKindOption: DisplayRepresentation] = [
        .breast: "모유",
        .bottleFormula: "분유",
        .bottleBreastMilk: "모유(병)",
        .pumping: "유축",
        .solid: "이유식",
        .snack: "간식",
        .diaperWet: "소변",
        .diaperDirty: "대변",
        .bath: "목욕",
        .temperature: "체온",
        .medication: "투약"
    ]

    /// default: 없이 exhaustive 유지 — 새 종류가 조용히 빠지지 않도록.
    var kind: SiriRecordKind {
        switch self {
        case .breast: .breast
        case .bottleFormula: .bottleFormula
        case .bottleBreastMilk: .bottleBreastMilk
        case .pumping: .pumping
        case .solid: .solid
        case .snack: .snack
        case .diaperWet: .diaperWet
        case .diaperDirty: .diaperDirty
        case .bath: .bath
        case .temperature: .temperature
        case .medication: .medication
        }
    }
}

/// "시리야, 베이비케어에 소변 기록해줘" — 앱을 열지 않고 한 손으로 기록한다.
///
/// 판정은 전부 `SiriRecordPlanner`(순수)가 하고, 여기서는 되묻기와 응답만 한다.
struct RecordActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "기록"
    static let description = IntentDescription("아기의 기록을 남깁니다.")
    /// 한 손으로 끝나야 하므로 앱을 띄우지 않는다.
    static let openAppWhenRun = false

    @Parameter(title: "기록 종류")
    var kindOption: SiriRecordKindOption

    @Parameter(title: "양 (ml)", requestValueDialog: "몇 ml 인가요?")
    var amountMl: Int?

    @Parameter(title: "체온 (°C)", requestValueDialog: "몇 도인가요?")
    var temperatureCelsius: Double?

    @Parameter(title: "약 이름", requestValueDialog: "어떤 약인가요?")
    var medicationName: String?

    init() {}

    init(kindOption: SiriRecordKindOption) {
        self.kindOption = kindOption
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var outcome = plan()

        // 값이 있어야 저장되는 종류인데 안 말했으면 되묻는다 — 조용히 실패시키지 않는다.
        if case .needs(let prompt) = outcome {
            switch prompt {
            case .amountMl: amountMl = try await $amountMl.requestValue()
            case .temperatureCelsius: temperatureCelsius = try await $temperatureCelsius.requestValue()
            case .medicationName: medicationName = try await $medicationName.requestValue()
            }
            outcome = plan()
        }

        switch outcome {
        case .ready(let ready):
            await SiriRecordRecorder.record(ready)
            return .result(dialog: IntentDialog(stringLiteral: ready.dialog))
        case .needs(let prompt):
            return .result(dialog: IntentDialog(stringLiteral: prompt.requestDialog))
        case .notReady(let reason):
            return .result(dialog: IntentDialog(stringLiteral: reason.siriMessage))
        case .invalid(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }

    private func plan() -> SiriRecordPlanner.Outcome {
        SiriRecordPlanner.plan(
            context: SiriRecordContextStore.current(),
            request: SiriRecordRequest(kind: kindOption.kind,
                                       amountMl: amountMl,
                                       temperatureCelsius: temperatureCelsius,
                                       medicationName: medicationName),
            now: Date()
        )
    }
}
