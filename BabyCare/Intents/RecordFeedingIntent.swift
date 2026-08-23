import AppIntents
import Foundation

/// v2.8.9 에서 나간 수유 전용 인텐트 — **한 판(v2.8.10) 동안만 남긴다.**
///
/// 지우면 손님이 단축어 앱에 만들어 둔 것이 깨지므로 남기되, 판정은 전부
/// `RecordActivityIntent` 와 같은 자리(`SiriRecordPlanner`)를 쓴다 — 두 문이 갈라지지 않게.
/// App Shortcut 노출은 새 인텐트만 한다(`BabyCareAppShortcuts` 는 `SleepIntents.swift` 에 있다).
enum SiriFeedingKindOption: String, AppEnum {
    case breast
    case bottleFormula
    case bottleBreastMilk

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "수유 종류"
    static let caseDisplayRepresentations: [SiriFeedingKindOption: DisplayRepresentation] = [
        .breast: "모유",
        .bottleFormula: "분유",
        .bottleBreastMilk: "모유(병)"
    ]

    var kind: SiriRecordKind {
        switch self {
        case .breast: .breast
        case .bottleFormula: .bottleFormula
        case .bottleBreastMilk: .bottleBreastMilk
        }
    }
}

struct RecordFeedingIntent: AppIntent {
    static let title: LocalizedStringResource = "수유 기록"
    static let description = IntentDescription("아기의 수유를 기록합니다.")
    static let openAppWhenRun = false

    @Parameter(title: "수유 종류")
    var kindOption: SiriFeedingKindOption

    @Parameter(title: "수유량 (ml)", requestValueDialog: "몇 ml 먹였나요?")
    var amountMl: Int?

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var outcome = plan()

        if case .needs(.amountMl) = outcome {
            amountMl = try await $amountMl.requestValue()
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
            request: SiriRecordRequest(kind: kindOption.kind, amountMl: amountMl),
            now: Date()
        )
    }
}
