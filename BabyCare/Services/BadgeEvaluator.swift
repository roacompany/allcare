import Foundation

/// 모든 배지 판정의 단일 진입점.
/// Phase 1: 수동 호출 API 제공 (Phase 2에서 기록 저장 훅 자동 연동)
@MainActor
final class BadgeEvaluator {
    struct Event {
        enum Kind: Equatable {
            case feedingLogged
            case sleepLogged
            case diaperLogged
            case growthLogged
            case routineStreakUpdated(newStreak: Int)
        }
        let kind: Kind
        let babyId: String?
        let at: Date
    }

    private let firestoreService: FirestoreService
    private let clock: () -> Date

    init(
        firestoreService: FirestoreService = FirestoreService.shared,
        clock: @escaping () -> Date = { Date() }
    ) {
        self.firestoreService = firestoreService
        self.clock = clock
    }

    /// 이벤트 수신 → 관련 배지 판정 → Firestore 저장. 신규 획득 배지 배열 반환.
    @discardableResult
    func evaluate(event: Event, userId: String) async -> [Badge] {
        var newlyEarned: [Badge] = []

        // 1. firstRecord: logging 이벤트 1회
        if Self.shouldCheckFirstRecord(kind: event.kind) {
            if let badge = await tryEarn(id: "firstRecord", userId: userId, babyId: event.babyId) {
                newlyEarned.append(badge)
                try? await firestoreService.setFirstRecordIfMissing(userId: userId, at: event.at)
            }
        }

        // 2. aggregate badges: stats 증가 → threshold 체크
        if let (field, badgeIds) = Self.aggregateMapping(kind: event.kind) {
            try? await firestoreService.incrementStats(userId: userId, field: field, by: 1)
            if let stats = try? await firestoreService.fetchStats(userId: userId) {
                let value = Self.statsValue(stats: stats, field: field)
                for badgeId in badgeIds {
                    guard let def = BadgeCatalog.definition(id: badgeId) else { continue }
                    guard value >= def.threshold else { continue }
                    if let badge = await tryEarn(id: badgeId, userId: userId, babyId: event.babyId) {
                        newlyEarned.append(badge)
                    }
                }
            }
        }

        // 3. streak badges
        if case .routineStreakUpdated(let streak) = event.kind {
            let streakBadges: [(String, Int)] = [
                ("routineStreak3", 3),
                ("routineStreak7", 7),
                ("routineStreak30", 30)
            ]
            for (id, threshold) in streakBadges where streak >= threshold {
                if let badge = await tryEarn(id: id, userId: userId, babyId: nil) {
                    newlyEarned.append(badge)
                }
            }
        }

        return newlyEarned
    }

    // MARK: - Helpers (internal — 테스트용 노출)

    static func shouldCheckFirstRecord(kind: Event.Kind) -> Bool {
        switch kind {
        case .feedingLogged, .sleepLogged, .diaperLogged, .growthLogged: return true
        case .routineStreakUpdated: return false
        }
    }

    static func aggregateMapping(kind: Event.Kind) -> (field: String, badgeIds: [String])? {
        switch kind {
        case .feedingLogged:  return ("feedingCount", ["feeding100"])
        case .sleepLogged:    return ("sleepCount", ["sleep50"])
        case .diaperLogged:   return ("diaperCount", ["diaper200"])
        case .growthLogged:   return ("growthRecordCount", ["growth10"])
        case .routineStreakUpdated: return nil
        }
    }

    static func statsValue(stats: UserStats, field: String) -> Int {
        switch field {
        case "feedingCount":      return stats.feedingCount ?? 0
        case "sleepCount":        return stats.sleepCount ?? 0
        case "diaperCount":       return stats.diaperCount ?? 0
        case "growthRecordCount": return stats.growthRecordCount ?? 0
        default: return 0
        }
    }

    private static let utcFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static func utcDateString(_ date: Date) -> String {
        Self.utcFormatter.string(from: date)
    }

    // MARK: - Private

    private func tryEarn(id: String, userId: String, babyId: String?) async -> Badge? {
        guard let def = BadgeCatalog.definition(id: id) else { return nil }
        let exists = (try? await firestoreService.badgeExists(userId: userId, badgeId: id)) ?? false
        guard !exists else { return nil }
        let now = clock()
        let badge = Badge(
            id: id,
            category: def.category,
            earnedByUserId: userId,
            babyId: babyId,
            earnedAt: now,
            earnedAtDateUTC: Self.utcDateString(now),
            conditionVersion: def.conditionVersion
        )
        let saved = (try? await firestoreService.saveBadge(badge, userId: userId)) ?? false
        return saved ? badge : nil
    }
}
