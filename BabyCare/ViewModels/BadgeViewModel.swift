import Foundation

@MainActor @Observable
final class BadgeViewModel {
    var earned: [Badge] = []
    var stats: UserStats?
    var isLoaded = false

    private let firestoreService = FirestoreService.shared

    func load(userId: String) async {
        async let badgesTask = try? firestoreService.fetchBadges(userId: userId)
        async let statsTask = try? firestoreService.fetchStats(userId: userId)
        let (badges, s) = await (badgesTask, statsTask)
        earned = badges ?? []
        stats = s ?? nil
        isLoaded = true
    }

    var recentBadges: [Badge] {
        Array(earned.sorted(by: { $0.earnedAt > $1.earnedAt }).prefix(5))
    }

    func earnedBadge(for def: BadgeCatalog.Definition) -> Badge? {
        earned.first { $0.id == def.id }
    }
}
