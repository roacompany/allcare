import Foundation

struct UserStats: Identifiable, Codable, Hashable {
    var id: String?             // optional — Firestore decode 실패 방지
    var feedingCount: Int?
    var sleepCount: Int?
    var diaperCount: Int?
    var growthRecordCount: Int?
    var firstRecordAt: Date?
    var updatedAt: Date?
    var migratedAtV1: Date?     // 백필 완료 타임스탬프 (nil이면 미실행 → backfillIfNeeded 대상)
    var recordStreak: Int?      // 기록 연속 일수 (C1 — 일반 기록 스트릭, routine과 별개)
    var lastRecordDayKey: String?   // 마지막 기록 날짜 키(YYYY-MM-DD) — 스트릭 판정용

    static let lifetimeId = "lifetime"

    static func empty() -> UserStats {
        UserStats(
            id: lifetimeId,
            feedingCount: 0,
            sleepCount: 0,
            diaperCount: 0,
            growthRecordCount: 0,
            firstRecordAt: nil,
            updatedAt: Date(),
            migratedAtV1: nil,
            recordStreak: 0,
            lastRecordDayKey: nil
        )
    }
}
