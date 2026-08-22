import Foundation

/// 시리로 받은 수유 요청 → 기존 저장 판정(`ActivityDraftBuilder`)이 그대로 먹는 순수 스냅샷.
///
/// 저장 규칙(수유량 1~500ml, 타입별 필드)을 여기서 다시 쓰지 않는다 — **판정은 하나**.
/// 시리 진입점이 폼과 다른 규칙을 갖게 되면 두 경로가 갈라진다.
struct SiriFeedingRequest: Sendable {
    /// 시리가 구분해 받는 수유 종류. 용어는 2026-08-20 확정본을 따른다:
    /// 직접 수유 = 모유 · 병에 담아 먹인 유축 모유 = 모유(병) · 분유 = 분유.
    enum Kind: String, CaseIterable, Sendable {
        case breast = "breast"
        case bottleFormula = "bottle_formula"
        case bottleBreastMilk = "bottle_breast_milk"

        var activityType: Activity.ActivityType {
            switch self {
            case .breast: .feedingBreast
            case .bottleFormula, .bottleBreastMilk: .feedingBottle
            }
        }

        var feedingContent: Activity.FeedingContent {
            switch self {
            case .bottleBreastMilk: .breastMilk
            case .breast, .bottleFormula: .formula
            }
        }

        /// 병수유는 양이 있어야 저장된다(`ActivityDraftBuilder` 1~500ml 검증).
        /// → 양을 안 말했으면 시리가 되물어야 한다는 근거.
        var requiresAmount: Bool {
            switch self {
            case .breast: false
            case .bottleFormula, .bottleBreastMilk: true
            }
        }
    }

    let kind: Kind
    let amountMl: Int?

    func draft(babyId: String, at date: Date) -> ActivityDraft {
        var draft = ActivityDraft(babyId: babyId, type: kind.activityType, startTime: date)
        draft.source = .siri             // 진입점이 스스로 선언한다 — 호출부가 적지 않는다
        draft.feedingContent = kind.feedingContent
        if let amountMl { draft.amountText = String(amountMl) }
        return draft
    }
}
