import Foundation

/// ActivityViewModel 이 의존하는 활동 R/W narrow protocol (ISP).
/// FirestoreService.shared 직접 결합을 끊어 단위 테스트(MockActivityFirestore) 주입을 가능하게 한다.
protocol ActivityFirestoreProviding: Sendable {
    func saveActivity(_ activity: Activity, userId: String) async throws
    func deleteActivity(_ activityId: String, userId: String, babyId: String) async throws
    func fetchActivities(userId: String, babyId: String, date: Date) async throws -> [Activity]
    func fetchActivities(userId: String, babyId: String, from startDate: Date, to endDate: Date) async throws -> [Activity]
    func fetchWeeklyMetricSnapshots(userId: String, babyId: String, limit: Int) async throws -> [WeeklyMetricSnapshot]
    func saveWeeklyMetricSnapshot(_ snapshot: WeeklyMetricSnapshot, userId: String, babyId: String) async throws
    func fetchStats(userId: String) async throws -> UserStats?
}

extension FirestoreService: ActivityFirestoreProviding {}
