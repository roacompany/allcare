import Foundation

/// 이 기록은 시리가 무엇을 되물어야 하나 — **단일 판정**.
///
/// 저장 규칙 자체는 `ActivityDraftBuilder` 가 갖고 있다. 여기는 "값이 없으면 저장이 안 되는가"를
/// 시리 쪽에서 미리 아는 자리일 뿐이고, 둘이 어긋나면
/// `testSiriPromptPolicy_matchesDraftBuilderForEveryKind` 가 빨강으로 잡는다.
enum SiriPromptPolicy {
    /// 시리가 되물을 값.
    enum Prompt: String, Equatable, Sendable {
        case amountMl
        case temperatureCelsius
        case medicationName

        /// 값이 없으면 `ActivityDraftBuilder` 가 **거절하는가**.
        /// false = 물어는 보되, 못 들으면 그냥 저장한다(조용히 실패시키지 않는다).
        var isRequired: Bool {
            switch self {
            case .amountMl, .temperatureCelsius: true
            case .medicationName: false   // 앱도 약 이름 없이 저장된다
            }
        }

        /// 시리가 되물을 때 하는 말.
        var requestDialog: String {
            switch self {
            case .amountMl: "몇 ml 인가요?"
            case .temperatureCelsius: "몇 도인가요?"
            case .medicationName: "어떤 약인가요?"
            }
        }
    }

    /// default: 없이 exhaustive 유지 — 새 종류가 조용히 "안 물어봄"으로 떨어지지 않도록.
    static func prompt(for kind: SiriRecordKind) -> Prompt? {
        switch kind {
        case .breast, .solid, .snack, .diaperWet, .diaperDirty, .bath:
            return nil
        case .bottleFormula, .bottleBreastMilk, .pumping:
            return .amountMl
        case .temperature:
            return .temperatureCelsius
        case .medication:
            return .medicationName
        }
    }
}
