import Foundation

struct Badge: Identifiable, Codable, Hashable {
    var id: String            // BadgeCatalog.id와 동일 (예: "feeding100")
    var category: BadgeCategory
    var earnedByUserId: String
    var babyId: String?       // 아기 행동 배지인 경우 연결 (Phase 2 private 필터링)
    var earnedAt: Date
    var earnedAtDateUTC: String   // YYYY-MM-DD (타임존 정규화)
    var conditionVersion: Int     // 조건 변경 대비
}

enum BadgeCategory: String, Codable, CaseIterable {
    case firstTime
    case aggregate
    case streak
}

enum BadgeCatalog {
    struct Definition: Hashable {
        let id: String
        let category: BadgeCategory
        let titleKey: String
        let descriptionKey: String
        let iconSFSymbol: String
        let conditionVersion: Int
        let threshold: Int
        let statsField: String?   // aggregate 배지만 설정 (firstTime/streak은 nil)
    }

    static let all: [Definition] = [
        .init(id: "firstRecord",     category: .firstTime, titleKey: "badge.firstRecord",     descriptionKey: "badge.firstRecord.desc",     iconSFSymbol: "star.fill",                  conditionVersion: 1, threshold: 1,   statsField: nil),
        .init(id: "feeding100",      category: .aggregate, titleKey: "badge.feeding100",      descriptionKey: "badge.feeding100.desc",      iconSFSymbol: "drop.fill",                  conditionVersion: 1, threshold: 100, statsField: "feedingCount"),
        .init(id: "sleep50",         category: .aggregate, titleKey: "badge.sleep50",         descriptionKey: "badge.sleep50.desc",         iconSFSymbol: "moon.zzz.fill",              conditionVersion: 1, threshold: 50,  statsField: "sleepCount"),
        .init(id: "diaper200",       category: .aggregate, titleKey: "badge.diaper200",       descriptionKey: "badge.diaper200.desc",       iconSFSymbol: "drop.triangle.fill",         conditionVersion: 1, threshold: 200, statsField: "diaperCount"),
        .init(id: "routineStreak3",  category: .streak,    titleKey: "badge.routineStreak3",  descriptionKey: "badge.routineStreak3.desc",  iconSFSymbol: "flame.fill",                 conditionVersion: 1, threshold: 3,   statsField: nil),
        .init(id: "routineStreak7",  category: .streak,    titleKey: "badge.routineStreak7",  descriptionKey: "badge.routineStreak7.desc",  iconSFSymbol: "flame.fill",                 conditionVersion: 1, threshold: 7,   statsField: nil),
        .init(id: "routineStreak30", category: .streak,    titleKey: "badge.routineStreak30", descriptionKey: "badge.routineStreak30.desc", iconSFSymbol: "crown.fill",                 conditionVersion: 1, threshold: 30,  statsField: nil),
        .init(id: "growth10",        category: .aggregate, titleKey: "badge.growth10",        descriptionKey: "badge.growth10.desc",        iconSFSymbol: "chart.line.uptrend.xyaxis",  conditionVersion: 1, threshold: 10,  statsField: "growthRecordCount")
    ]

    static func definition(id: String) -> Definition? {
        all.first { $0.id == id }
    }
}
