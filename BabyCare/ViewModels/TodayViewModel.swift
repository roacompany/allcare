import Foundation

/// 「오늘 하루」 — 열고 · 시간표와 기록을 이어 붙이고 · 닫는다.
///
/// `userId` 는 호출부가 owner-path(`dataUserId`)로 변환해 넘긴다 — VM 이 스스로 정하지 않는다.
/// ⛔ 칸의 상태는 저장하지 않는다. 시간표 + 기록에서 **매번 다시 계산**한다.
@MainActor @Observable
final class TodayViewModel: LoadingStateful {

    private(set) var run: DayRun?
    private(set) var cells: [DayCell] = []
    private(set) var plan: DayPlan?
    var isLoading = false
    var errorMessage: String?

    private let dayRunProvider: DayRunFirestoreProviding
    private let planProvider: DayPlanFirestoreProviding
    private let calendar: Calendar

    init(
        dayRunProvider: DayRunFirestoreProviding = FirestoreService.shared,
        planProvider: DayPlanFirestoreProviding = FirestoreService.shared,
        calendar: Calendar = .current
    ) {
        self.dayRunProvider = dayRunProvider
        self.planProvider = planProvider
        self.calendar = calendar
    }

    // MARK: - Load

    /// `activities` 는 **하루 목록 그대로** 넘겨도 된다 — 순수 함수들이 `startedOn` 으로 거른다.
    func load(userId: String, day: Date, activities: [Activity]) async {
        await withLoading {
            do {
                let docId = DayRun.documentId(for: day, calendar: calendar)
                async let fetchedRun = dayRunProvider.fetchDayRun(userId: userId, documentId: docId)
                async let fetchedPlans = planProvider.fetchDayPlans(userId: userId)
                run = try await fetchedRun
                // 🔑 `fetchedPlans` 는 `async let` 바인딩 — `try await` 가 바인딩 자체에 걸려야
                //    한다(값을 먼저 받은 뒤 `.first`). `try await fetchedPlans.first` 로 쓰면
                //    이 툴체인(Swift 6.3.3)이 `.first` 에 먼저 await 를 적용하려 해 컴파일이 깨진다.
                plan = (try await fetchedPlans).first
                recompute(day: day, activities: activities)
                errorMessage = nil
            } catch {
                errorMessage = "오늘 하루를 불러오지 못했어요."
                logSilent("오늘 하루 로드 실패", error: error, logger: AppLogger.firestore)
            }
        }
    }

    /// 기록이 바뀔 때마다 화면이 부르는 자리 — 저장소를 다시 안 두드린다.
    func refreshCells(day: Date, activities: [Activity]) {
        recompute(day: day, activities: activities)
    }

    private func recompute(day: Date, activities: [Activity]) {
        guard let plan else { cells = []; return }
        let anchors = DayAnchorsBuilder.anchors(from: activities, on: day, calendar: calendar)
        let slots = DayPlanExpander.slots(plan: plan, day: day, anchors: anchors, calendar: calendar)
        cells = DaySlotFiller.fill(slots: slots, activities: activities, on: day, calendar: calendar)
    }

    // MARK: - 열기 · 닫기

    /// 같은 날 다시 눌러도 **시작 시각은 그대로**다(문서 id 가 날짜라 덮어쓰기가 멱등).
    func startToday(userId: String, day: Date) async {
        if let existing = run, existing.id == DayRun.documentId(for: day, calendar: calendar) { return }
        let new = DayRun(id: DayRun.documentId(for: day, calendar: calendar),
                         planId: plan?.id, startedAt: Date())
        do {
            try await dayRunProvider.saveDayRun(new, userId: userId)
            run = new
            errorMessage = nil
        } catch {
            // ⛔ 저장이 실패했으면 열린 것처럼 보이지 않는다 — 손님이 닫을 수 없는 하루가 생긴다.
            errorMessage = "오늘 하루를 시작하지 못했어요."
            logSilent("하루 시작 실패", error: error, logger: AppLogger.firestore)
        }
    }

    func closeToday(userId: String) async {
        guard var current = run, current.isOpen else { return }
        current.closedAt = Date()
        do {
            try await dayRunProvider.saveDayRun(current, userId: userId)
            run = current
            errorMessage = nil
        } catch {
            errorMessage = "오늘 하루를 닫지 못했어요."
            logSilent("하루 닫기 실패", error: error, logger: AppLogger.firestore)
        }
    }

    // MARK: - 밤 요약

    func summaryLine(babyName: String) -> String? {
        DaySummary.babyLine(cells: cells, babyName: babyName)
    }
}
