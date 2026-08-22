import FirebaseAuth
import Foundation

/// 시리 기록의 **부수효과** — 판정은 `SiriFeedingPlanner` 가 이미 끝냈다.
///
/// 오프라인 큐에 적는 것을 저장 성공으로 본다(앱의 기존 계약과 동일 — `persist` 도 큐잉을 성공으로 돌려준다).
///
/// ⚠️ **로그인 안 된 상태에서는 `flush()` 를 부르지 않는다.** 큐는 5회 실패하면 항목을 버리는데,
///    백그라운드 실행이라 인증이 아직 복원되지 않았을 때 flush 하면 시리를 몇 번 쓰는 것만으로
///    먼저 쌓인 기록이 재시도를 소진하고 조용히 사라진다.
@MainActor
enum SiriFeedingRecorder {
    static func record(_ plan: SiriFeedingPlanner.Plan) async {
        let queued = OfflineQueue.shared.enqueueSave(
            plan.activity,
            collectionPath: plan.collectionPath,
            documentId: plan.activity.id
        )
        guard queued else {
            AppLogger.firestore.error("시리 기록 인코딩 실패 — activity \(plan.activity.id) 큐잉 누락")
            return
        }
        // 인증이 살아 있을 때만 즉시 전송 시도. 아니면 앱이 다음에 뜰 때/연결 복구 때 나간다.
        guard Auth.auth().currentUser != nil else { return }
        await OfflineQueue.shared.flush()
    }
}
