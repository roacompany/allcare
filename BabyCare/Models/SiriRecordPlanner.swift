import Foundation

/// 시리 기록의 **판정** — 부수효과 없음(저장은 호출부가 한다).
///
/// 저장 규칙(양 범위·체온 범위·타입별 필드)은 `ActivityDraftBuilder` 를 그대로 쓴다.
/// 시리가 폼과 다른 규칙을 갖게 되면 두 경로가 갈라진다 — **판정은 하나**.
enum SiriRecordPlanner {
    struct Plan: Equatable {
        let activity: Activity
        /// 소유자 경로 — 가족 공유 아기면 소유자 uid 아래에 쓴다.
        let collectionPath: String
        /// 시리가 말할 문구.
        let dialog: String
    }

    enum Outcome: Equatable {
        case ready(Plan)
        /// 값이 있어야 저장되는데 안 말했다 → 시리가 되물어야 한다.
        case needs(SiriPromptPolicy.Prompt)
        /// 로그인/아기 선택이 안 돼 기록할 곳이 없다.
        case notReady(SiriRecordContext.Reason)
        /// 기존 저장 판정이 거절 — 문구는 폼과 같은 것을 쓴다.
        case invalid(String)
    }

    static func plan(context: SiriRecordContext, request: SiriRecordRequest, now: Date) -> Outcome {
        switch context {
        case .notReady(let reason):
            return .notReady(reason)

        case .ready(let ownerUserId, let babyId, let babyName):
            if let missing = request.missingRequiredPrompt { return .needs(missing) }

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
                    dialog: dialog(kind: request.kind,
                                   amountMl: request.amountMl,
                                   temperatureCelsius: request.temperatureCelsius,
                                   babyName: babyName)
                ))
            }
        }
    }

    /// 조사 문제를 피해 "…의 …를 기록했어요" 로 고정한다(이름이 무엇이든 자연스럽다).
    /// default: 없이 exhaustive 유지.
    static func dialog(kind: SiriRecordKind,
                       amountMl: Int?,
                       temperatureCelsius: Double?,
                       babyName: String?) -> String {
        let label: String
        switch kind {
        case .breast:
            label = "모유 수유"
        case .bottleFormula, .bottleBreastMilk, .pumping:
            label = "\(kind.displayName) \(amountMl ?? 0)ml"
        case .temperature:
            label = "체온 \(Self.formatted(temperatureCelsius ?? 0))도"
        case .solid, .snack, .diaperWet, .diaperDirty, .bath, .medication:
            label = kind.displayName
        }
        let prefix = babyName.map { "\($0)의 " } ?? ""
        // 받침에 따라 을/를 — "소변를" 이 되지 않게(전 종류로 넓히며 드러난 문제).
        return "\(prefix)\(label)\(KoreanParticle.object(after: label)) 기록했어요"
    }

    /// 37.0 은 "37", 37.5 는 "37.5" 로 읽는다.
    private static func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
