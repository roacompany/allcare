import UIKit

/// 지원 판(iOS 17)보다 나중에 생긴 SF Symbol 을 쓸 때 — 이 기기에 없으면 옛 이름으로.
/// 없는 이름은 오류 없이 빈칸으로 그려진다. `scripts/symbols_check.py` 가 옛 이름이 지원 판에 있는지 본다.
enum SFSymbolFallback {
    /// RED 판: 고치기 전 동작 그대로 — 늘 새 이름(이 기기에 없으면 빈칸).
    static func prefer(_ newer: String, else older: String) -> String {
        newer
    }
}
