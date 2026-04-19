import Foundation
@testable import BabyCare

/// BadgeEvaluator 통합 테스트용 Mock. 호출 기록 + 커스텀 리턴 값 스텁 지원.
///
/// 실제 Firestore 통신 없이 BadgeEvaluator 의 backfill/evaluate 플로우 검증.
/// Swift 6 Sendable: 단일 쓰레드 테스트 전용이므로 `@unchecked Sendable`.
final class MockBadgeFirestore: BadgeFirestoreProviding, @unchecked Sendable {
    // 스텁
    var activityCounts: [String: Int] = [:]       // key: babyId + typeRaw
    var growthCounts: [String: Int] = [:]         // key: babyId
    var earliestActivity: [String: Activity] = [:]
    var earliestGrowth: [String: GrowthRecord] = [:]
    var statsResponse: UserStats?
    var savedBadges: Set<String> = []

    // 기록
    private(set) var setStatsAbsoluteCalls: [(userId: String, feedingCount: Int)] = []
    private(set) var incrementStatsCalls: [(field: String, value: Int)] = []
    private(set) var setFirstRecordIfMissingCalls: [Date] = []
    private(set) var saveBadgeCalls: [String] = []

    // 에러 주입
    var errorOnFetchStats: Error?
    var errorOnSaveBadge: Error?

    func setFirstRecordIfMissing(userId: String, at date: Date) async throws {
        setFirstRecordIfMissingCalls.append(date)
    }

    func incrementStats(userId: String, field: String, by value: Int) async throws {
        incrementStatsCalls.append((field, value))
    }

    func fetchStats(userId: String) async throws -> UserStats? {
        if let err = errorOnFetchStats { throw err }
        return statsResponse
    }

    func setStatsAbsolute(
        userId: String,
        feedingCount: Int,
        sleepCount: Int,
        diaperCount: Int,
        growthRecordCount: Int,
        firstRecordAt: Date?
    ) async throws {
        setStatsAbsoluteCalls.append((userId, feedingCount))
    }

    func countActivities(userId: String, babyId: String, typeRawValues: [String]) async throws -> Int {
        typeRawValues.reduce(0) { $0 + (activityCounts["\(babyId)|\($1)"] ?? 0) }
    }

    func countGrowthRecords(userId: String, babyId: String) async throws -> Int {
        growthCounts[babyId] ?? 0
    }

    func fetchEarliestActivity(userId: String, babyId: String) async throws -> Activity? {
        earliestActivity[babyId]
    }

    func fetchEarliestGrowthRecord(userId: String, babyId: String) async throws -> GrowthRecord? {
        earliestGrowth[babyId]
    }

    func badgeExists(userId: String, badgeId: String) async throws -> Bool {
        savedBadges.contains(badgeId)
    }

    func saveBadge(_ badge: Badge, userId: String) async throws -> Bool {
        if let err = errorOnSaveBadge { throw err }
        let isNew = !savedBadges.contains(badge.id)
        savedBadges.insert(badge.id)
        saveBadgeCalls.append(badge.id)
        return isNew
    }
}
