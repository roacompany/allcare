import Foundation

/// 앱 전체에서 공유되는 싱글톤 상태 컨테이너.
/// @State가 아닌 static 인스턴스로 ViewModel 생명주기를 앱과 동일하게 유지.
@MainActor
final class AppState {
    static let shared = AppState()

    let auth = AuthViewModel()
    let baby = BabyViewModel()
    let activity = ActivityViewModel()
    let calendar = CalendarViewModel()
    let todo = TodoViewModel()
    let stats = StatsViewModel()
    let diary = DiaryViewModel()
    let product = ProductViewModel()
    let health = HealthViewModel()

    private init() {}
}
