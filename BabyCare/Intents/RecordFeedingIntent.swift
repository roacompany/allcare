import AppIntents
import Foundation

/// 시리로 부를 수 있는 수유 종류. 라벨은 2026-08-20 용어 확정본을 따른다.
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

    var kind: SiriFeedingRequest.Kind {
        switch self {
        case .breast: .breast
        case .bottleFormula: .bottleFormula
        case .bottleBreastMilk: .bottleBreastMilk
        }
    }
}

/// "시리야, 베이비케어에 모유 수유 기록해줘" — 앱을 열지 않고 한 손으로 기록한다.
///
/// 밤중 수유는 한 손엔 아기, 한 손엔 젖병이라 폰을 만질 손이 없다. 그래서 `openAppWhenRun = false`.
/// 판정은 전부 `SiriFeedingPlanner`(순수)가 하고, 여기서는 되묻기와 응답만 한다.
struct RecordFeedingIntent: AppIntent {
    static let title: LocalizedStringResource = "수유 기록"
    static let description = IntentDescription("아기의 수유를 기록합니다.")
    /// 한 손으로 끝나야 하므로 앱을 띄우지 않는다.
    static let openAppWhenRun = false

    @Parameter(title: "수유 종류")
    var kindOption: SiriFeedingKindOption

    @Parameter(title: "수유량 (ml)", requestValueDialog: "몇 ml 먹였나요?")
    var amountMl: Int?

    init() {}

    init(kindOption: SiriFeedingKindOption) {
        self.kindOption = kindOption
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var outcome = plan(amountMl: amountMl)

        // 병수유인데 양을 안 말했으면 되묻는다 — 조용히 실패시키지 않는다.
        if case .needsAmount = outcome {
            outcome = plan(amountMl: try await $amountMl.requestValue())
        }

        switch outcome {
        case .ready(let ready):
            await SiriFeedingRecorder.record(ready)
            return .result(dialog: IntentDialog(stringLiteral: ready.dialog))
        case .needsAmount:
            return .result(dialog: "수유량을 알려주세요")
        case .notReady(let reason):
            return .result(dialog: IntentDialog(stringLiteral: reason.siriMessage))
        case .invalid(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }

    private func plan(amountMl: Int?) -> SiriFeedingPlanner.Outcome {
        SiriFeedingPlanner.plan(
            context: SiriRecordContextStore.current(),
            request: SiriFeedingRequest(kind: kindOption.kind, amountMl: amountMl),
            now: Date()
        )
    }
}

/// 설치만 하면 바로 쓰이는 시리 명령 — 손님이 단축어 앱에서 따로 만들 필요가 없다.
/// (베이비타임 등 구형 Siri Shortcuts 방식은 손님이 4단계를 직접 설정해야 한다.)
struct BabyCareAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordFeedingIntent(kindOption: .breast),
            phrases: [
                "\(.applicationName)에 모유 수유 기록",
                "\(.applicationName) 모유 수유 기록해줘",
                "Record breast feeding in \(.applicationName)"
            ],
            shortTitle: "모유 수유 기록",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: RecordFeedingIntent(kindOption: .bottleFormula),
            phrases: [
                "\(.applicationName)에 분유 기록",
                "\(.applicationName) 분유 먹였어",
                "Record formula feeding in \(.applicationName)"
            ],
            shortTitle: "분유 기록",
            systemImageName: "waterbottle.fill"
        )
        AppShortcut(
            intent: RecordFeedingIntent(kindOption: .bottleBreastMilk),
            phrases: [
                "\(.applicationName)에 모유 병수유 기록",
                "\(.applicationName) 유축한 모유 먹였어",
                "Record pumped milk feeding in \(.applicationName)"
            ],
            shortTitle: "모유(병) 기록",
            systemImageName: "drop.circle.fill"
        )
    }
}
