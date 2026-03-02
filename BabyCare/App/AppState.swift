import Foundation
import FirebaseCore

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

    private init() {
        // Firebase를 ViewModel 생성 전에 반드시 초기화
        FirebaseApp.configure()

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
    }
}
