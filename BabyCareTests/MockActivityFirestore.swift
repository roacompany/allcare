import Foundation
@testable import BabyCare

/// ActivityViewModel 통합 테스트용 Mock. 호출 기록 + 에러 주입 + in-memory fetch 스텁.
final class MockActivityFirestore: ActivityFirestoreProviding, @unchecked Sendable {
    var errorOnSave: Error?

    private(set) var saveActivityCalls: [Activity] = []
    private(set) var deleteActivityCalls: [String] = []
    private(set) var saveWeeklyMetricSnapshotCalls: [WeeklyMetricSnapshot] = []

    var activitiesByDate: [Activity] = []
    var activitiesByRange: [Activity] = []
    var weeklyMetricSnapshotsResponse: [WeeklyMetricSnapshot] = []

    func saveActivity(_ activity: Activity, userId: String) async throws {
        saveActivityCalls.append(activity)
        if let err = errorOnSave { throw err }
    }

    func deleteActivity(_ activityId: String, userId: String, babyId: String) async throws {
        deleteActivityCalls.append(activityId)
    }

    func fetchActivities(userId: String, babyId: String, date: Date) async throws -> [Activity] {
        activitiesByDate
    }

    func fetchActivities(userId: String, babyId: String, from startDate: Date, to endDate: Date) async throws -> [Activity] {
        activitiesByRange
    }

    func fetchWeeklyMetricSnapshots(userId: String, babyId: String, limit: Int) async throws -> [WeeklyMetricSnapshot] {
        weeklyMetricSnapshotsResponse
    }

    func saveWeeklyMetricSnapshot(_ snapshot: WeeklyMetricSnapshot, userId: String, babyId: String) async throws {
        saveWeeklyMetricSnapshotCalls.append(snapshot)
    }
}
