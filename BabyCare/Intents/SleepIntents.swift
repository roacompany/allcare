import AppIntents
import Foundation

/// "시리야, 베이비케어에 잠들었어" — 앱의 수면 타이머를 시작한다.
///
/// 새 개념을 만들지 않는다. `RunningTimerStore` 는 앱 배너·잠금화면이 보는 그 자리다.
struct StartSleepIntent: AppIntent {
    static let title: LocalizedStringResource = "수면 시작"
    static let description = IntentDescription("아기가 자기 시작했다고 기록합니다.")
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date()
        let outcome = SiriSleepPlanner.planStart(
            context: SiriRecordContextStore.current(),
            running: RunningTimerStore.current(),
            now: now
        )

        switch outcome {
        case .start(let dialog):
            RunningTimerStore.start(type: .sleep, at: now)
            return .result(dialog: IntentDialog(stringLiteral: dialog))
        case .alreadySleeping(let dialog), .busy(let dialog), .notSleeping(let dialog):
            return .result(dialog: IntentDialog(stringLiteral: dialog))
        case .notReady(let reason):
            return .result(dialog: IntentDialog(stringLiteral: reason.siriMessage))
        case .invalid(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .save:
            // planStart 는 저장하지 않는다 — 도달 불가.
            return .result(dialog: "기록하지 못했어요")
        }
    }
}

/// "시리야, 베이비케어에 깼어" — 타이머를 멈추고 잔 시간과 함께 저장한다.
struct StopSleepIntent: AppIntent {
    static let title: LocalizedStringResource = "수면 종료"
    static let description = IntentDescription("아기가 깼다고 기록합니다.")
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = SiriSleepPlanner.planStop(
            context: SiriRecordContextStore.current(),
            running: RunningTimerStore.current(),
            now: Date()
        )

        switch outcome {
        case .save(let plan):
            RunningTimerStore.clear()
            await SiriRecordRecorder.record(plan)
            return .result(dialog: IntentDialog(stringLiteral: plan.dialog))
        case .invalid(let message):
            // ⚠️ 타이머를 지우지 않는다 — 앱에서 시간을 고쳐 저장할 수 있게 남긴다.
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .notSleeping(let dialog), .alreadySleeping(let dialog), .busy(let dialog), .start(let dialog):
            return .result(dialog: IntentDialog(stringLiteral: dialog))
        case .notReady(let reason):
            return .result(dialog: IntentDialog(stringLiteral: reason.siriMessage))
        }
    }
}

/// 설치만 하면 바로 쓰이는 시리 명령 — 손님이 단축어 앱에서 따로 만들 필요가 없다.
/// (베이비타임 등 구형 Siri Shortcuts 방식은 손님이 4단계를 직접 설정해야 한다.)
///
/// ⚠️ **App Shortcut 은 앱당 10개까지**(애플 제한). 지금 8개 — 늘릴 때 이 주석을 확인할 것.
///    자주 쓰는 5종만 프리셋으로 두고, 나머지는 마지막의 **종류 변수 문구**가 전부 받는다.
struct BabyCareAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordActivityIntent(kindOption: .breast),
            phrases: [
                "\(.applicationName)에 모유 수유 기록",
                "\(.applicationName) 모유 수유 기록해줘",
                "Record breast feeding in \(.applicationName)"
            ],
            shortTitle: "모유 수유 기록",
            systemImageName: "figure.and.child.holdinghands"
        )
        AppShortcut(
            intent: RecordActivityIntent(kindOption: .bottleFormula),
            phrases: [
                "\(.applicationName)에 분유 기록",
                "\(.applicationName) 분유 먹였어",
                "Record formula feeding in \(.applicationName)"
            ],
            shortTitle: "분유 기록",
            systemImageName: "waterbottle.fill"
        )
        AppShortcut(
            intent: RecordActivityIntent(kindOption: .bottleBreastMilk),
            phrases: [
                "\(.applicationName)에 모유 병수유 기록",
                "\(.applicationName) 유축한 모유 먹였어",
                "Record pumped milk feeding in \(.applicationName)"
            ],
            shortTitle: "모유(병) 기록",
            systemImageName: "drop.circle.fill"
        )
        AppShortcut(
            intent: RecordActivityIntent(kindOption: .diaperWet),
            phrases: [
                "\(.applicationName)에 소변 기록",
                "\(.applicationName) 쉬했어",
                "Record a wet diaper in \(.applicationName)"
            ],
            shortTitle: "소변 기록",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: RecordActivityIntent(kindOption: .diaperDirty),
            phrases: [
                "\(.applicationName)에 대변 기록",
                "\(.applicationName) 응가했어",
                "Record a dirty diaper in \(.applicationName)"
            ],
            shortTitle: "대변 기록",
            systemImageName: "humidity.fill"
        )
        AppShortcut(
            intent: StartSleepIntent(),
            phrases: [
                "\(.applicationName)에 잠들었어",
                "\(.applicationName) 자기 시작했어",
                "Start sleep in \(.applicationName)"
            ],
            shortTitle: "수면 시작",
            systemImageName: "moon.zzz.fill"
        )
        AppShortcut(
            intent: StopSleepIntent(),
            phrases: [
                "\(.applicationName)에 깼어",
                "\(.applicationName) 일어났어",
                "Stop sleep in \(.applicationName)"
            ],
            shortTitle: "수면 종료",
            systemImageName: "sun.max.fill"
        )
        // 나머지 전 종류(유축·이유식·간식·목욕·체온·투약)를 이 한 자리가 받는다.
        AppShortcut(
            intent: RecordActivityIntent(),
            phrases: [
                "\(.applicationName)에 \(\.$kindOption) 기록",
                "\(.applicationName) \(\.$kindOption) 기록해줘",
                "Record \(\.$kindOption) in \(.applicationName)"
            ],
            shortTitle: "기록",
            systemImageName: "square.and.pencil"
        )
    }
}
