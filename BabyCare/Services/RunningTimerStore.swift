import Foundation

/// 지금 도는 타이머 — 앱(`ActivityTimerManager`)과 시리(App Intents)가 **같은 것을 본다**.
struct RunningTimer: Equatable, Sendable {
    let type: Activity.ActivityType
    let startedAt: Date
}

/// 앱 안에만 있던 타이머 상태를 App Group 으로 옮긴 자리.
///
/// 왜 옮겼나: 시리는 앱 화면 없이 도는 별도 진입점이라 ViewModel 을 못 본다.
/// 두 곳에 따로 두면 「잠들었어」와 앱 배너가 갈라진다 — **판정은 하나**.
///
/// 키는 `siri_` 접두 규약을 따른다 → 로그아웃 시 `SiriSharedStore.clearAll()` 이 저절로 지운다.
enum RunningTimerStore {
    private enum Keys {
        static let start = "siri_timer_start"
        static let type = "siri_timer_type"
    }

    /// 옮겨오기 전 자리(앱 전용이던 시절). 이관 뒤에는 쓰지 않는다.
    private enum LegacyKeys {
        static let start = "babycare_timer_start"
        static let type = "babycare_timer_type"
    }

    private static var defaults: UserDefaults { WidgetDataStore.defaults }

    static func current() -> RunningTimer? {
        let interval = defaults.double(forKey: Keys.start)
        guard interval > 0,
              let raw = defaults.string(forKey: Keys.type),
              let type = Activity.ActivityType.known(rawValue: raw) else { return nil }
        return RunningTimer(type: type, startedAt: Date(timeIntervalSince1970: interval))
    }

    static func start(type: Activity.ActivityType, at date: Date) {
        guard type != .unknown else { return }
        defaults.set(date.timeIntervalSince1970, forKey: Keys.start)
        defaults.set(type.rawValue, forKey: Keys.type)
    }

    static func clear() {
        defaults.removeObject(forKey: Keys.start)
        defaults.removeObject(forKey: Keys.type)
    }

    /// 🩸 업데이트 순간 타이머가 돌고 있었다면 잃지 않도록 옛 자리에서 한 번 옮겨 온다.
    /// 옮긴 뒤 옛 자리를 비워 두 곳이 갈라지지 않게 한다.
    static func migrateFromStandardDefaultsIfNeeded() {
        let legacyInterval = UserDefaults.standard.double(forKey: LegacyKeys.start)
        guard legacyInterval > 0 else { return }
        defer {
            UserDefaults.standard.removeObject(forKey: LegacyKeys.start)
            UserDefaults.standard.removeObject(forKey: LegacyKeys.type)
        }
        guard defaults.double(forKey: Keys.start) == 0,
              let raw = UserDefaults.standard.string(forKey: LegacyKeys.type),
              let type = Activity.ActivityType.known(rawValue: raw) else { return }
        start(type: type, at: Date(timeIntervalSince1970: legacyInterval))
    }
}
