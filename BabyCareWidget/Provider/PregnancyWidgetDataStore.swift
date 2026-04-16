import Foundation

/// 임신 모드 위젯 공유 데이터. 읽기 전용 (Keys + Read).
/// 쓰기는 메인 앱의 PregnancyWidgetSyncService에서 담당.
/// 기존 WidgetDataStore와 별도 키 prefix (pregnancy_) 격리.
enum PregnancyWidgetDataStore {
    private static let suiteName = "group.com.roacompany.allcare"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - Keys (prefix: pregnancy_)

    enum Keys {
        static let dueDate = "pregnancy_dueDate"
        static let currentWeek = "pregnancy_currentWeek"
        static let currentDay = "pregnancy_currentDay"
        static let babyNickname = "pregnancy_babyNickname"
        static let dDay = "pregnancy_dDay"
        static let isActive = "pregnancy_isActive"
    }

    // MARK: - Read (from widget)

    static var isActive: Bool {
        defaults.bool(forKey: Keys.isActive)
    }

    static var babyNickname: String {
        defaults.string(forKey: Keys.babyNickname) ?? "우리 아기"
    }

    static var currentWeek: Int {
        defaults.integer(forKey: Keys.currentWeek)
    }

    static var currentDay: Int {
        defaults.integer(forKey: Keys.currentDay)
    }

    static var dDay: Int {
        defaults.integer(forKey: Keys.dDay)
    }

    static var dueDate: Date? {
        defaults.object(forKey: Keys.dueDate) as? Date
    }
}
