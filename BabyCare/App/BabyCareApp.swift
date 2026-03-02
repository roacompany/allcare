import SwiftUI
import FirebaseCore

@main
struct BabyCareApp: App {
    @State private var authVM = AuthViewModel()
    @State private var babyVM = BabyViewModel()
    @State private var activityVM = ActivityViewModel()
    @State private var calendarVM = CalendarViewModel()
    @State private var todoVM = TodoViewModel()
    @State private var statsVM = StatsViewModel()
    @State private var diaryVM = DiaryViewModel()
    @State private var productVM = ProductViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authVM)
                .environment(babyVM)
                .environment(activityVM)
                .environment(calendarVM)
                .environment(todoVM)
                .environment(statsVM)
                .environment(diaryVM)
                .environment(productVM)
                .preferredColorScheme(nil)
        }
    }
}
