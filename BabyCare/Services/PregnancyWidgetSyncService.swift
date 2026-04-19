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

    // 키는 ���젯 타겟의 PregnancyWidgetDataStore.Keys와 동일해야 함.
    private enum Keys {
        static let dueDate = "pregnancy_dueDate"
        static let lmpDate = "pregnancy_lmpDate"
        static let babyNickname = "pregnancy_babyNickname"
        static let isActive = "pregnancy_isActive"
    }

    // MARK: - Write (from main app)

    /// 임신 데이터를 위젯에 동기화.
    /// lmpDate/dueDate 원본을 저��하여 위젯 Provider가 주차/D-day를 동적으로 계산.
    static func update(pregnancy: Pregnancy?) {
        guard let p = pregnancy else {
            clear()
            return
        }
        defaults.set(p.dueDate, forKey: Keys.dueDate)
        defaults.set(p.lmpDate, forKey: Keys.lmpDate)
        defaults.set(p.babyNickname ?? "우리 아기", forKey: Keys.babyNickname)
        defaults.set(true, forKey: Keys.isActive)

        WidgetCenter.shared.reloadTimelines(ofKind: "PregnancyDDayWidget")
    }

    static func clear() {
        for key in [Keys.dueDate, Keys.lmpDate, Keys.babyNickname, Keys.isActive] {
            defaults.removeObject(forKey: key)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "PregnancyDDayWidget")
    }

    /// 테스트 전용: 키 prefix 검증에 사용.
    enum TestableKeys {
        static let dueDate = Keys.dueDate
        static let lmpDate = Keys.lmpDate
        static let babyNickname = Keys.babyNickname
        static let isActive = Keys.isActive
    }
}
