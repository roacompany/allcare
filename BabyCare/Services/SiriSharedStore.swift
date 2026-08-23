import Foundation

/// 시리(App Intents)가 앱과 나눠 쓰는 App Group 값의 **정리 담당**.
///
/// 🩸 지울 것을 이름으로 나열하지 않는다. `AppState.resetUserScopedState` 처럼 목록을 적는 자리는
///    나중에 생긴 항목이 조용히 빠진다(같은 결함을 세 번 겪었다).
///    대신 **접두 규약**을 쓴다 — 시리가 읽는 사용자 범위 값은 전부 `siri_` 로 시작하고,
///    여기서는 접두가 붙은 키를 전부 지운다. 새 키가 생겨도 이 파일은 안 고쳐도 된다.
///
/// ⚠️ 새 시리 공유 값을 만들 때는 **반드시 `siri_` 로 시작하는 키**를 쓸 것.
enum SiriSharedStore {
    static let userScopedPrefix = "siri_"

    /// 로그아웃·계정 전환에서 호출 (`AppState.resetUserScopedState`).
    static func clearAll() {
        let defaults = WidgetDataStore.defaults
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(userScopedPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
