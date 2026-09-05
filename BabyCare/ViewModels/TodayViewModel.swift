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

    /// 한 번이라도 **성공적으로** 읽었나 — 「시간표가 없다」와 「아직 모른다」를 가른다.
    private(set) var didLoad = false
    /// 마지막 읽기가 실패했나.
    /// ⛔ `errorMessage` 로 대신하지 않는다 — 시작·닫기 실패도 거기 담기는데, 그건 카드가
    ///    이미 떠 있는 상태라 카드를 통째로 실패 화면으로 바꾸면 안 된다.
    private(set) var loadFailed = false

    /// 카드가 무엇을 그릴지 — **여기 한 곳에서만** 정한다.
    /// 🧩 카드가 스스로 판단하면 「숨긴다」와 「못 읽었다」가 화면마다 갈라진다.
    enum Presentation: Equatable {
        /// 아직 모른다 — 아무것도 안 그린다(시간표 있는 사람 화면이 깜빡이지 않게).
        case loading
        /// 못 읽었다 — **숨기지 않는다.** 모르는 것과 없는 것은 다르다.
        case failed
        /// 시간표가 없다(확인됨) — 카드 자체를 그리지 않는다(PO 결정 2026-09-05).
        /// 시간표가 없으면 칸이 채워질 수 없어, 열어도 하루 종일 아무 일도 일어나지 않는다.
        case hidden
        /// 그린다.
        case ready
    }

    var presentation: Presentation {
        if loadFailed { return .failed }
        guard didLoad else { return .loading }
        return plan == nil ? .hidden : .ready
    }

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
    ///
    /// 🔑 **원자성**: 두 fetch 는 `async let` 으로 여전히 동시에 나간다 — 로컬 상수로
    ///    먼저 받아 두고, **둘 다 성공했을 때만** `run`/`plan` 을 한 번에 반영하고
    ///    `recompute()`를 부른다. 하나라도 throw 하면 프로퍼티는 한 글자도 안 바뀐다.
    ///    따로따로 `self.run =` / `self.plan =` 에 바로 대입하면, 앞이 성공하고 뒤가
    ///    실패했을 때 `run` 만 새 값이 되고 `plan`·`cells` 는 이전 값에 머물러 화면이
    ///    반쪽짜리 상태(리뷰 Important)가 된다 — 시간표를 못 읽었는데 하루 문서만
    ///    바뀐 것처럼 보이는 식.
    func load(userId: String, day: Date, activities: [Activity]) async {
        await withLoading {
            do {
                let docId = DayRun.documentId(for: day, calendar: calendar)
                async let fetchedRun = dayRunProvider.fetchDayRun(userId: userId, documentId: docId)
                async let fetchedPlans = planProvider.fetchDayPlans(userId: userId)
                // 🔑 `fetchedPlans` 는 `async let` 바인딩 — `try await` 가 바인딩 자체에 걸려야
                //    한다(값을 먼저 받은 뒤 `.first`). `try await fetchedPlans.first` 로 쓰면
                //    이 툴체인(Swift 6.3.3)이 `.first` 에 먼저 await 를 적용하려 해 컴파일이 깨진다.
                let newRun = try await fetchedRun
                let newPlan = (try await fetchedPlans).first
                run = newRun
                plan = newPlan
                recompute(day: day, activities: activities)
                errorMessage = nil
                didLoad = true
                loadFailed = false
            } catch {
                loadFailed = true
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
        // 🔴 못 읽었으면 **쓰지 않는다.** `saveDayRun` 은 `setData` 통째 덮어쓰기라,
        //    이미 닫은 오늘이 열린 하루로 되살아난다(리뷰 C4). 모르는 채 여느니 안 연다.
        guard !loadFailed else {
            errorMessage = "오늘 하루를 불러오지 못해 시작할 수 없어요."
            return
        }
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
