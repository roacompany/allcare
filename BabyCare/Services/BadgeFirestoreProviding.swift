import Foundation

/// BadgeEvaluator가 의존하는 Firestore 작업만 추출한 narrow protocol (ISP).
///
/// FirestoreService 전체를 추상화하는 대신, 배지 시스템에 필요한 10개 메서드만
/// 노출해 통합 테스트에서 Mock 주입 가능. 신규 배지 로직 추가 시 필요한 메서드를
/// 이 protocol에 추가.
protocol BadgeFirestoreProviding: Sendable {
    func setFirstRecordIfMissing(userId: String, at date: Date) async throws
    func incrementStats(userId: String, field: String, by value: Int) async throws
    func fetchStats(userId: String) async throws -> UserStats?
    func setStatsAbsolute(
        userId: String,
        feedingCount: Int,
        sleepCount: Int,
        diaperCount: Int,
        growthRecordCount: Int,
        firstRecordAt: Date?
    ) async throws
    func countActivities(userId: String, babyId: String, typeRawValues: [String]) async throws -> Int
    func countGrowthRecords(userId: String, babyId: String) async throws -> Int
    func fetchEarliestActivity(userId: String, babyId: String) async throws -> Activity?
    func fetchEarliestGrowthRecord(userId: String, babyId: String) async throws -> GrowthRecord?
    func badgeExists(userId: String, badgeId: String) async throws -> Bool
    func saveBadge(_ badge: Badge, userId: String) async throws -> Bool
}

extension FirestoreService: BadgeFirestoreProviding {}
