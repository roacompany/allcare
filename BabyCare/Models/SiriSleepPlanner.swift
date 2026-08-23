import Foundation

/// 시리 수면 기록의 **판정** — 부수효과 없음.
///
/// 새 개념을 만들지 않는다: 앱에 이미 있는 타이머(`RunningTimerStore`)를 시리가 만지는 것뿐이다.
/// 저장 규칙(24시간 초과 거절)은 `ActivityDraftBuilder` 가 갖고 있다 — 여기서 다시 쓰지 않는다.
enum SiriSleepPlanner {
    enum Outcome: Equatable {
        /// 타이머를 시작해도 된다.
        case start(dialog: String)
        /// 이미 자는 중 — 덮어쓰지 않는다(앞의 잠이 통째로 사라진다).
        case alreadySleeping(dialog: String)
        /// 다른 타이머가 도는 중 — 남의 것을 끄지 않는다.
        case busy(dialog: String)
        /// 타이머를 멈추고 이 기록을 저장한다.
        case save(SiriRecordPlanner.Plan)
        /// 자고 있다고 기록된 게 없다.
        case notSleeping(dialog: String)
        case notReady(SiriRecordContext.Reason)
        /// 기존 저장 판정이 거절 — 문구는 폼과 같은 것을 쓴다.
        case invalid(String)
    }

    /// `SiriRecordPlanner.plan` 과 같은 모양으로 쓴다 — 컨텍스트 해석이 두 벌이 되지 않게.
    static func planStart(context: SiriRecordContext, running: RunningTimer?, now: Date) -> Outcome {
        switch context {
        case .notReady(let reason):
            return .notReady(reason)

        case .ready(_, _, let babyName):
            if let running {
                if running.type == .sleep {
                    let elapsed = SleepSession(startedAt: running.startedAt).duration(now: now)
                    return .alreadySleeping(dialog: "이미 자고 있다고 기록돼 있어요. \(spoken(elapsed))째예요")
                }
                // 남의 타이머를 끄지 않는다 — 수유 중이던 기록이 사라진다.
                return .busy(dialog: "지금 \(running.type.displayName) 타이머가 돌고 있어요")
            }
            return .start(dialog: "\(subjectPrefix(babyName))자기 시작한 걸로 기록했어요")
        }
    }

    static func planStop(context: SiriRecordContext, running: RunningTimer?, now: Date) -> Outcome {
        let ownerUserId: String, babyId: String, babyName: String?
        switch context {
        case .notReady(let reason):
            return .notReady(reason)
        case .ready(let owner, let baby, let name):
            (ownerUserId, babyId, babyName) = (owner, baby, name)
        }

        guard let running, running.type == .sleep else {
            return .notSleeping(dialog: "자고 있다고 기록된 게 없어요")
        }

        let session = SleepSession(startedAt: running.startedAt)
        let duration = session.duration(now: now)

        var draft = ActivityDraft(babyId: babyId, type: .sleep, startTime: session.startedAt)
        draft.source = .siri
        draft.endTime = now
        draft.duration = duration

        switch ActivityDraftBuilder.build(draft) {
        case .failure(let error):
            return .invalid(error.message)
        case .success(let activity):
            return .save(SiriRecordPlanner.Plan(
                activity: activity,
                collectionPath: FirestoreCollections.babyChildPath(
                    userId: ownerUserId,
                    babyId: babyId,
                    collection: FirestoreCollections.activities
                ),
                dialog: "\(subjectPrefix(babyName))\(spoken(duration)) 잤어요"
            ))
        }
    }

    /// "서준이 " / "서아가 " — 이름이 없으면 빈 문자열.
    private static func subjectPrefix(_ babyName: String?) -> String {
        guard let babyName, !babyName.isEmpty else { return "" }
        return "\(babyName)\(KoreanParticle.subject(after: babyName)) "
    }

    /// "3시간 20분" · "45분" · "2시간" — 0분은 말하지 않는다.
    static func spoken(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)분" }
        if minutes == 0 { return "\(hours)시간" }
        return "\(hours)시간 \(minutes)분"
    }
}
