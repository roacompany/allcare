import Foundation
import OSLog

/// 모든 배지 판정의 단일 진입점.
/// Phase 1: 수동 호출 API 제공 (Phase 2에서 기록 저장 훅 자동 연동)
@MainActor
final class BadgeEvaluator {
    static let log = Logger(subsystem: "com.roacompany.allcare", category: "Badge")
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

    private let firestoreService: BadgeFirestoreProviding
    private let clock: () -> Date

    init(
        firestoreService: BadgeFirestoreProviding = FirestoreService.shared,
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
                do {
                    try await firestoreService.setFirstRecordIfMissing(userId: userId, at: event.at)
                } catch {
                    Self.log.error("setFirstRecordIfMissing failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        // 2. aggregate badges: stats 증가 → threshold 체크
        if let (field, badgeIds) = Self.aggregateMapping(kind: event.kind) {
            do {
                try await firestoreService.incrementStats(userId: userId, field: field, by: 1)
            } catch {
                Self.log.error("incrementStats(\(field, privacy: .public)) failed: \(error.localizedDescription, privacy: .public)")
            }
            do {
                let stats = try await firestoreService.fetchStats(userId: userId)
                let value = Self.statsValue(stats: stats ?? .empty(), field: field)
                Self.log.debug("aggregate check field=\(field, privacy: .public) value=\(value)")
                for badgeId in badgeIds {
                    guard let def = BadgeCatalog.definition(id: badgeId) else { continue }
                    guard value >= def.threshold else { continue }
                    if let badge = await tryEarn(id: badgeId, userId: userId, babyId: event.babyId) {
                        newlyEarned.append(badge)
                    }
                }
            } catch {
                Self.log.error("fetchStats failed: \(error.localizedDescription, privacy: .public)")
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

    struct BackfillCounts {
        var feeding = 0
        var sleep = 0
        var diaper = 0
        var growth = 0
        var earliest: Date?
        var allSucceeded = true
    }

    /// 기존 기록에서 배지 시스템을 1회 백필.
    /// 이미 `migratedAtV1`이 있으면 no-op (idempotent).
    /// 성공 시 획득한 배지 배열 반환 — 호출자가 snackbar 여부 결정.
    @discardableResult
    func backfillIfNeeded(
        userId: String,
        ownedBabyIds: [String],
        currentRoutineMaxStreak: Int = 0
    ) async -> [Badge] {
        if await isAlreadyMigrated(userId: userId) { return [] }
        guard !ownedBabyIds.isEmpty else {
            Self.log.debug("backfill skipped — no owned babies")
            return []
        }

        let counts = await aggregateCounts(userId: userId, ownedBabyIds: ownedBabyIds)
        let earliestStr = counts.earliest?.description ?? "nil"
        Self.log.log("backfill counts — f=\(counts.feeding) s=\(counts.sleep) d=\(counts.diaper) g=\(counts.growth) earliest=\(earliestStr, privacy: .public) ok=\(counts.allSucceeded)")

        // 일부 아기 fetch 실패 시 backfill 중단 — 다음 런치에 재시도 (migratedAtV1 마킹 안 함)
        guard counts.allSucceeded else {
            Self.log.error("backfill aborted — partial aggregation failure, retry next launch")
            return []
        }

        do {
            try await firestoreService.setStatsAbsolute(
                userId: userId,
                feedingCount: counts.feeding,
                sleepCount: counts.sleep,
                diaperCount: counts.diaper,
                growthRecordCount: counts.growth,
                firstRecordAt: counts.earliest
            )
        } catch {
            Self.log.error("backfill setStatsAbsolute failed: \(error.localizedDescription, privacy: .public)")
            return []
        }

        let earned = await awardBackfilledBadges(userId: userId, counts: counts, routineMaxStreak: currentRoutineMaxStreak)
        Self.log.log("backfill done — awarded=\(earned.count)")
        return earned
    }

    private func isAlreadyMigrated(userId: String) async -> Bool {
        do {
            if let stats = try await firestoreService.fetchStats(userId: userId),
               stats.migratedAtV1 != nil {
                Self.log.debug("backfill skipped — already migrated")
                return true
            }
        } catch {
            // 네트워크 오류 등으로 판정 실패 시 재시도 가능하도록 false 반환
            // (setStatsAbsolute는 절대값 덮어쓰기 + tryEarn은 badgeExists dedup이므로 재실행 안전)
            Self.log.error("backfill fetchStats failed — will retry: \(error.localizedDescription, privacy: .public)")
            return false
        }
        return false
    }

    private func aggregateCounts(userId: String, ownedBabyIds: [String]) async -> BackfillCounts {
        var counts = BackfillCounts()
        let feedingRaw = ["feeding_breast", "feeding_bottle", "feeding_solid", "feeding_snack"]
        let sleepRaw = ["sleep"]
        let diaperRaw = ["diaper_wet", "diaper_dirty", "diaper_both"]

        for babyId in ownedBabyIds {
            do {
                counts.feeding += try await firestoreService.countActivities(userId: userId, babyId: babyId, typeRawValues: feedingRaw)
                counts.sleep += try await firestoreService.countActivities(userId: userId, babyId: babyId, typeRawValues: sleepRaw)
                counts.diaper += try await firestoreService.countActivities(userId: userId, babyId: babyId, typeRawValues: diaperRaw)
                counts.growth += try await firestoreService.countGrowthRecords(userId: userId, babyId: babyId)
            } catch {
                counts.allSucceeded = false
                Self.log.error("backfill count failed baby=\(babyId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            let (newEarliest, ok) = await updateEarliest(current: counts.earliest, userId: userId, babyId: babyId)
            counts.earliest = newEarliest
            if !ok { counts.allSucceeded = false }
        }
        return counts
    }

    private func updateEarliest(current: Date?, userId: String, babyId: String) async -> (Date?, Bool) {
        var earliest = current
        do {
            if let a = try await firestoreService.fetchEarliestActivity(userId: userId, babyId: babyId) {
                earliest = [earliest, a.startTime].compactMap { $0 }.min()
            }
            if let g = try await firestoreService.fetchEarliestGrowthRecord(userId: userId, babyId: babyId) {
                earliest = [earliest, g.date].compactMap { $0 }.min()
            }
            return (earliest, true)
        } catch {
            Self.log.error("backfill earliest failed baby=\(babyId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return (earliest, false)
        }
    }

    private func awardBackfilledBadges(userId: String, counts: BackfillCounts, routineMaxStreak: Int) async -> [Badge] {
        var earned: [Badge] = []
        if counts.earliest != nil, let b = await tryEarn(id: "firstRecord", userId: userId, babyId: nil) {
            earned.append(b)
        }
        let mappings: [(value: Int, badgeId: String)] = [
            (counts.feeding, "feeding100"),
            (counts.sleep, "sleep50"),
            (counts.diaper, "diaper200"),
            (counts.growth, "growth10")
        ]
        for m in mappings {
            guard let def = BadgeCatalog.definition(id: m.badgeId), m.value >= def.threshold else { continue }
            if let b = await tryEarn(id: m.badgeId, userId: userId, babyId: nil) {
                earned.append(b)
            }
        }
        let streakBadges: [(String, Int)] = [
            ("routineStreak3", 3), ("routineStreak7", 7), ("routineStreak30", 30)
        ]
        for (id, threshold) in streakBadges where routineMaxStreak >= threshold {
            if let b = await tryEarn(id: id, userId: userId, babyId: nil) {
                earned.append(b)
            }
        }
        return earned
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
        guard let def = BadgeCatalog.definition(id: id) else {
            Self.log.error("tryEarn: unknown badge id=\(id, privacy: .public)")
            return nil
        }
        let exists: Bool
        do {
            exists = try await firestoreService.badgeExists(userId: userId, badgeId: id)
        } catch {
            Self.log.error("badgeExists(\(id, privacy: .public)) failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
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
        do {
            let saved = try await firestoreService.saveBadge(badge, userId: userId)
            if saved { Self.log.log("badge earned: \(id, privacy: .public)") }
            return saved ? badge : nil
        } catch {
            Self.log.error("saveBadge(\(id, privacy: .public)) failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
