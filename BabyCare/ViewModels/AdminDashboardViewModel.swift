import Foundation

@MainActor @Observable
final class AdminDashboardViewModel {
    var userCount: Int?

    private let firestoreService = FirestoreService.shared

    func loadUserCount() async {
        do {
            userCount = try await firestoreService.fetchUserCount()
        } catch {
            logSilent("사용자 수 조회 실패", error: error, logger: AppLogger.admin)
        }
    }
}
