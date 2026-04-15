import Foundation

struct UserStats: Identifiable, Codable, Hashable {
    var id: String?             // optional — Firestore decode 실패 방지
    var feedingCount: Int?
    var sleepCount: Int?
    var diaperCount: Int?
    var growthRecordCount: Int?
    var firstRecordAt: Date?
    var updatedAt: Date?

    static let lifetimeId = "lifetime"

    static func empty() -> UserStats {
        UserStats(
            id: lifetimeId,
            feedingCount: 0,
            sleepCount: 0,
            diaperCount: 0,
            growthRecordCount: 0,
            firstRecordAt: nil,
            updatedAt: Date()
        )
    }
}
