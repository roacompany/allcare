import Foundation

@MainActor @Observable
final class AdminDashboardViewModel {
    var userCount: Int?

    private let firestoreService = FirestoreService.shared

    func loadUserCount() async {
        do {
            userCount = try await firestoreService.fetchUserCount()
        } catch {
            print("[Admin] 사용자 수 조회 실패: \(error.localizedDescription)")
        }
    }
}
