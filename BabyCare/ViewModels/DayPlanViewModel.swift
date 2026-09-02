import Foundation

/// 시간표 VM — owner-path 로 읽고 쓴다.
/// `userId` 는 호출부가 owner-path(`dataUserId`, 공유 아기 데이터 라우팅)로 변환해 넘긴다 —
/// VM 은 스스로 currentUserId 를 정하지 않는다.
@MainActor @Observable
final class DayPlanViewModel: LoadingStateful {

    private(set) var plans: [DayPlan] = []
    var isLoading = false
    var errorMessage: String?

    private let provider: DayPlanFirestoreProviding

    init(provider: DayPlanFirestoreProviding = FirestoreService.shared) {
        self.provider = provider
    }

    // MARK: - Load

    func load(userId: String) async {
        await withLoading {
            do {
                // provider 가 이미 createdAt 오름차순(+id tie-break)으로 정렬해 돌려준다
                // (실제 Firestore 쿼리·Mock 동일 계약) — VM 에서 다시 정렬하지 않는다.
                // 여기서 .sorted 를 추가하면 프로덕션 정렬과 갈릴 수 있다.
                plans = try await provider.fetchDayPlans(userId: userId)
                errorMessage = nil
            } catch {
                errorMessage = "시간표를 불러오지 못했어요."
                logSilent("시간표 로드 실패", error: error, logger: AppLogger.firestore)
            }
        }
    }

    // MARK: - Save (append-or-replace)

    func save(_ plan: DayPlan, userId: String) async {
        let previous = plans
        if let i = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[i] = plan
        } else {
            plans.append(plan)
        }
        do {
            try await provider.saveDayPlan(plan, userId: userId)
            errorMessage = nil
        } catch {
            plans = previous
            errorMessage = "시간표를 저장하지 못했어요."
            logSilent("시간표 저장 실패", error: error, logger: AppLogger.firestore)
        }
    }

    // MARK: - Delete

    func delete(_ plan: DayPlan, userId: String) async {
        let previous = plans
        plans.removeAll { $0.id == plan.id }
        do {
            try await provider.deleteDayPlan(plan.id, userId: userId)
            errorMessage = nil
        } catch {
            plans = previous
            errorMessage = "시간표를 지우지 못했어요."
            logSilent("시간표 삭제 실패", error: error, logger: AppLogger.firestore)
        }
    }
}
