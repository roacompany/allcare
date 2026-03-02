import SwiftUI
import FirebaseCore

@main
struct BabyCareApp: App {
    private let appState = AppState.shared

    init() {
        FirebaseApp.configure()
    }

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
        }
    }
}
