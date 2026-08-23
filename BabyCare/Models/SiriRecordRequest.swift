import Foundation

/// 시리로 받은 기록 요청 → 기존 저장 판정(`ActivityDraftBuilder`)이 그대로 먹는 순수 스냅샷.
///
/// 저장 규칙(수유량 1~500ml, 체온 34.0~43.0°C, 타입별 필드)을 여기서 다시 쓰지 않는다
/// — **판정은 하나**. 시리 진입점이 폼과 다른 규칙을 갖게 되면 두 경로가 갈라진다.
struct SiriRecordRequest: Sendable {
    let kind: SiriRecordKind
    let amountMl: Int?
    let temperatureCelsius: Double?
    let medicationName: String?

    init(kind: SiriRecordKind,
         amountMl: Int? = nil,
         temperatureCelsius: Double? = nil,
         medicationName: String? = nil) {
        self.kind = kind
        self.amountMl = amountMl
        self.temperatureCelsius = temperatureCelsius
        self.medicationName = medicationName
    }

    /// 되물어야 할 값이 아직 없으면 그 Prompt 를 돌려준다(없으면 nil = 바로 저장 가능).
    var missingRequiredPrompt: SiriPromptPolicy.Prompt? {
        guard let prompt = SiriPromptPolicy.prompt(for: kind), prompt.isRequired else { return nil }
        switch prompt {
        case .amountMl: return amountMl == nil ? prompt : nil
        case .temperatureCelsius: return temperatureCelsius == nil ? prompt : nil
        case .medicationName: return nil   // 필수가 아니다
        }
    }

    /// default: 없이 exhaustive 유지 — 새 종류가 조용히 "아무 값도 안 실림"으로 떨어지지 않도록.
    func draft(babyId: String, at date: Date) -> ActivityDraft {
        var d = ActivityDraft(babyId: babyId, type: kind.tile.type, startTime: date)
        d.source = .siri   // 진입점이 스스로 선언한다 — 호출부가 적지 않는다

        switch kind {
        case .breast, .solid, .snack, .diaperWet, .diaperDirty, .bath:
            break
        case .bottleFormula, .bottleBreastMilk:
            d.feedingContent = kind.tile.contentPreset ?? .formula
            if let amountMl { d.amountText = String(amountMl) }
        case .pumping:
            if let amountMl { d.amountText = String(amountMl) }
        case .temperature:
            if let temperatureCelsius { d.temperatureText = String(temperatureCelsius) }
        case .medication:
            if let medicationName, !medicationName.trimmingCharacters(in: .whitespaces).isEmpty {
                d.medicationName = medicationName
            }
        }
        return d
    }
}
