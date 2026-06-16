import Foundation

/// 앱 전체에서 공유되는 싱글톤 상태 컨테이너.
/// @State가 아닌 static 인스턴스로 ViewModel 생명주기를 앱과 동일하게 유지.
@MainActor
final class AppState {
    static let shared = AppState()

    let auth: AuthViewModel
    let baby: BabyViewModel
    let activity: ActivityViewModel
    let calendar: CalendarViewModel
    let todo: TodoViewModel
    let stats: StatsViewModel
    let diary: DiaryViewModel
    let product: ProductViewModel
    let health: HealthViewModel
    let routine: RoutineViewModel
    let aiAdvice: AIAdviceViewModel
    let announcement: AnnouncementViewModel
    let patternReport: PatternReportViewModel
    let purchase: PurchaseViewModel
    let hospitalReport: HospitalReportViewModel
    let badgePresenter: BadgePresenter
    let insight: InsightService
    let pregnancy: PregnancyViewModel

    private init() {
        // Firebase는 AppDelegate에서 초기화됨
        auth = AuthViewModel()
        baby = BabyViewModel()
        activity = ActivityViewModel()
        calendar = CalendarViewModel()
        todo = TodoViewModel()
        stats = StatsViewModel()
        diary = DiaryViewModel()
        product = ProductViewModel()
        health = HealthViewModel()
        routine = RoutineViewModel()
        aiAdvice = AIAdviceViewModel()
        announcement = AnnouncementViewModel()
        patternReport = PatternReportViewModel()
        purchase = PurchaseViewModel()
        hospitalReport = HospitalReportViewModel()
        badgePresenter = BadgePresenter()
        insight = InsightService()
        pregnancy = PregnancyViewModel()
    }

    /// 로그아웃/계정 전환 시 사용자 스코프 상태를 전부 초기화 (계정 간 데이터 잔존 차단).
    /// ContentView 의 isAuthenticated=false 단일 초크포인트에서 호출.
    func resetUserScopedState() {
        baby.reset()
        pregnancy.reset()

        activity.todayActivities = []

        calendar.activitiesForDate = []
        calendar.hospitalVisitsForDate = []
        calendar.vaccinationsForDate = []
        calendar.todosForDate = []
        calendar.eventDots = [:]

        todo.todos = []
        todo.completedTodosCache = []

        stats.weeklyActivities = []
        diary.entries = []

        health.vaccinations = []
        health.milestones = []
        health.hospitalVisits = []

        routine.routines = []

        aiAdvice.messages = []
        aiAdvice.currentBaby = nil

        announcement.announcements = []
        announcement.allAnnouncements = []

        patternReport.report = nil
        patternReport.aiInsight = nil
        patternReport.feedingPredictionText = nil

        purchase.records = []

        hospitalReport.cachedReport = nil
        hospitalReport.checklistItems = []
        hospitalReport.growthRecords = []
        hospitalReport.vaccinations = []
        hospitalReport.pdfURL = nil

        product.products = []

        // 임신 v3 선택 모듈 표시 토글(@AppStorage)은 기기 전역 — 계정 전환 시 잔존 방지 (L1)
        for key in ["pregnancy.module.medication", "pregnancy.module.water", "pregnancy.module.sleep"] {
            UserDefaults.standard.removeObject(forKey: key)
        }

        OfflineQueue.shared.clear()
    }
}
