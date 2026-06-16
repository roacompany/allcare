import Foundation

@MainActor @Observable
final class BadgeViewModel {
    var earned: [Badge] = []
    var stats: UserStats?
    var isLoaded = false
    var errorMessage: String?

    private let firestoreService = FirestoreService.shared

    func load(userId: String) async {
        do {
            async let badgesTask = firestoreService.fetchBadges(userId: userId)
            async let statsTask = firestoreService.fetchStats(userId: userId)
            earned = try await badgesTask
            stats = try await statsTask
            errorMessage = nil
        } catch {
            // M5: 로드 실패를 "배지 없음"과 구분 — 사용자에게 노출 가능하도록 errorMessage 세팅
            errorMessage = "배지 정보를 불러오지 못했습니다."
            logSilent("배지/통계 로드 실패", error: error, logger: AppLogger.badge)
        }
        isLoaded = true
    }

    var recentBadges: [Badge] {
        Array(earned.sorted(by: { $0.earnedAt > $1.earnedAt }).prefix(5))
    }

    func earnedBadge(for def: BadgeCatalog.Definition) -> Badge? {
        earned.first { $0.id == def.id }
    }
}
