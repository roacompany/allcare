import Foundation

/// 시리(App Intents)가 읽는 "어디에 기록할지" 스냅샷 — 앱과 같은 App Group 에 둔다.
///
/// 시리는 앱 화면 없이 백그라운드로 실행되므로 ViewModel 상태를 못 본다.
/// 앱은 로그인·아기 선택이 바뀔 때마다 여기에 남기고, **로그아웃 시 반드시 지운다**.
///
/// 🔒 `clear()` 를 빠뜨리면 시리가 **이전 계정 경로**에 계속 쓴다 —
///    #39(계정 전환 잔존)와 같은 결함군이고, 오프라인 큐를 비우는 것만으로는 못 막는다.
enum SiriRecordContextStore {
    private enum Keys {
        static let ownerUserId = "siri_ownerUserId"
        static let babyId = "siri_babyId"
        static let babyName = "siri_babyName"
    }

    /// App Group 은 위젯과 같은 곳 — suite 이름의 단일 소스는 `WidgetDataStore`.
    private static var defaults: UserDefaults { WidgetDataStore.defaults }

    /// 소유자 경로(가족 공유 시 owner uid = `babyVM.dataUserId()`)와 선택된 아기를 기록.
    static func update(ownerUserId: String?, babyId: String?, babyName: String?) {
        defaults.set(ownerUserId, forKey: Keys.ownerUserId)
        defaults.set(babyId, forKey: Keys.babyId)
        defaults.set(babyName, forKey: Keys.babyName)
    }

    static func current() -> SiriRecordContext {
        SiriRecordContext.resolve(
            ownerUserId: defaults.string(forKey: Keys.ownerUserId),
            babyId: defaults.string(forKey: Keys.babyId),
            babyName: defaults.string(forKey: Keys.babyName)
        )
    }

    /// 로그아웃·계정 전환 시 호출 (`AppState.resetUserScopedState`).
    static func clear() {
        [Keys.ownerUserId, Keys.babyId, Keys.babyName].forEach {
            defaults.removeObject(forKey: $0)
        }
    }
}
