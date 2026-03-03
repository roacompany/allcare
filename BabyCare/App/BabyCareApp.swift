import SwiftUI

@main
struct BabyCareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState.auth)
                .environment(appState.baby)
                .environment(appState.activity)
                .environment(appState.calendar)
                .environment(appState.todo)
                .environment(appState.stats)
                .environment(appState.diary)
                .environment(appState.product)
                .environment(appState.health)
                .environment(appState.routine)
                .environment(appState.aiAdvice)
                .environment(appState.announcement)
        }
    }
}
