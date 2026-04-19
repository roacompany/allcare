import Foundation

/// 임신 모드 위젯 공유 데이터. 읽기 전용 (Keys + Read).
/// 쓰기는 메인 앱의 PregnancyWidgetSyncService에서 담당.
/// 기존 WidgetDataStore와 별도 키 prefix (pregnancy_) 격리.
///
/// 주차/D-day는 원본 날짜(lmpDate, dueDate)에서 동적 계산.
/// 스냅샷 방식 대신 매 타임라인 갱신 시 최신 값 보장.
enum PregnancyWidgetDataStore {
    private static let suiteName = "group.com.roacompany.allcare"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - Keys (prefix: pregnancy_)

    enum Keys {
        static let dueDate = "pregnancy_dueDate"
        static let lmpDate = "pregnancy_lmpDate"
        static let babyNickname = "pregnancy_babyNickname"
        static let isActive = "pregnancy_isActive"
    }

    // MARK: - Read (from widget)

    static var isActive: Bool {
        defaults.bool(forKey: Keys.isActive)
    }

    static var babyNickname: String {
        defaults.string(forKey: Keys.babyNickname) ?? "우리 아기"
    }

    static var dueDate: Date? {
        defaults.object(forKey: Keys.dueDate) as? Date
    }

    static var lmpDate: Date? {
        defaults.object(forKey: Keys.lmpDate) as? Date
    }

    // MARK: - Dynamic Calculations

    /// LMP 기준 현재 임신 주차. PregnancyDateMath helper 위임 (단위 테스트 가능).
    static var currentWeekAndDay: (weeks: Int, days: Int)? {
        PregnancyDateMath.weekAndDay(from: lmpDate, now: Date())
    }

    /// 예정일까지 남은 일수 (음수=초과). PregnancyDateMath helper 위임.
    static var dDay: Int? {
        PregnancyDateMath.dDay(due: dueDate, now: Date())
    }
}
