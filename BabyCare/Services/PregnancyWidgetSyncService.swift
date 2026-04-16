import Foundation
import WidgetKit

/// 임신 모드 위젯 데이터 동기화 (메인 앱 → 위젯).
/// 기존 WidgetDataStore와 별도 키 prefix (pregnancy_) 격리.
/// 같은 App Groups Suite (group.com.roacompany.allcare) 사용.
/// 위젯 타겟에서는 PregnancyWidgetDataStore가 읽기 담당.
enum PregnancyWidgetSyncService {
    private static let suiteName = "group.com.roacompany.allcare"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // 키는 위젯 타겟의 PregnancyWidgetDataStore.Keys와 동일해야 함.
    private enum Keys {
        static let dueDate = "pregnancy_dueDate"
        static let currentWeek = "pregnancy_currentWeek"
        static let currentDay = "pregnancy_currentDay"
        static let babyNickname = "pregnancy_babyNickname"
        static let dDay = "pregnancy_dDay"
        static let isActive = "pregnancy_isActive"
    }

    // MARK: - Write (from main app)

    static func update(pregnancy: Pregnancy?) {
        guard let p = pregnancy else {
            clear()
            return
        }
        defaults.set(p.dueDate, forKey: Keys.dueDate)
        if let week = p.currentWeekAndDay {
            defaults.set(week.weeks, forKey: Keys.currentWeek)
            defaults.set(week.days, forKey: Keys.currentDay)
        }
        defaults.set(p.babyNickname ?? "우리 아기", forKey: Keys.babyNickname)
        if let dDay = p.dDay {
            defaults.set(dDay, forKey: Keys.dDay)
        }
        defaults.set(true, forKey: Keys.isActive)

        WidgetCenter.shared.reloadTimelines(ofKind: "PregnancyDDayWidget")
    }

    static func clear() {
        for key in [Keys.dueDate, Keys.currentWeek, Keys.currentDay,
                    Keys.babyNickname, Keys.dDay, Keys.isActive] {
            defaults.removeObject(forKey: key)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "PregnancyDDayWidget")
    }

    /// 테스트 전용: 키 prefix 검증에 사용.
    enum TestableKeys {
        static let dueDate = Keys.dueDate
        static let currentWeek = Keys.currentWeek
        static let currentDay = Keys.currentDay
        static let babyNickname = Keys.babyNickname
        static let dDay = Keys.dDay
        static let isActive = Keys.isActive
    }
}
