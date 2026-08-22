import Foundation

/// 시리 수유 기록의 **판정** — 부수효과 없음(저장은 호출부가 한다).
///
/// 수유량 범위·타입별 필드 같은 저장 규칙은 `ActivityDraftBuilder` 를 그대로 쓴다.
/// 시리가 폼과 다른 규칙을 갖게 되면 두 경로가 갈라진다 — **판정은 하나**.
enum SiriFeedingPlanner {
    struct Plan: Equatable {
        let activity: Activity
        /// 소유자 경로 — 가족 공유 아기면 소유자 uid 아래에 쓴다.
        let collectionPath: String
        /// 시리가 말할 문구.
        let dialog: String
    }

    enum Outcome: Equatable {
        case ready(Plan)
        /// 병수유인데 양을 안 말했다 → 시리가 되물어야 한다.
        case needsAmount
        /// 로그인/아기 선택이 안 돼 기록할 곳이 없다.
        case notReady(SiriRecordContext.Reason)
        /// 기존 저장 판정이 거절 — 문구는 폼과 같은 것을 쓴다.
        case invalid(String)
    }

    static func plan(context: SiriRecordContext, request: SiriFeedingRequest, now: Date) -> Outcome {
        switch context {
        case .notReady(let reason):
            return .notReady(reason)

        case .ready(let ownerUserId, let babyId, let babyName):
            if request.kind.requiresAmount, request.amountMl == nil { return .needsAmount }

            switch ActivityDraftBuilder.build(request.draft(babyId: babyId, at: now)) {
            case .failure(let error):
                return .invalid(error.message)
            case .success(let activity):
                return .ready(Plan(
                    activity: activity,
                    collectionPath: FirestoreCollections.babyChildPath(
                        userId: ownerUserId,
                        babyId: babyId,
                        collection: FirestoreCollections.activities
                    ),
                    dialog: dialog(kind: request.kind, amountMl: request.amountMl, babyName: babyName)
                ))
            }
        }
    }

    /// 조사 문제를 피해 "…의 …를 기록했어요" 로 고정한다(이름이 무엇이든 자연스럽다).
    static func dialog(kind: SiriFeedingRequest.Kind, amountMl: Int?, babyName: String?) -> String {
        let label: String
        switch kind {
        case .breast:
            label = "모유 수유"
        case .bottleFormula:
            label = "분유 \(amountMl ?? 0)ml"
        case .bottleBreastMilk:
            label = "모유(병) \(amountMl ?? 0)ml"
        }
        let prefix = babyName.map { "\($0)의 " } ?? ""
        return "\(prefix)\(label)를 기록했어요"
    }
}
