import Foundation

/// 위젯 설치 유도 카드 정책 (UX Clean Sweep C2).
/// 위젯은 기록 마찰을 가장 크게 줄이는 기능인데 설치 유도가 없었다 —
/// 기록 습관이 생기기 시작한 사용자에게 1회(해제형) 안내한다.
enum WidgetPromoPolicy {
    static let dismissedKey = "widgetPromoDismissed"

    /// 노출: 누적 기록 3건 이상(습관 시작) + 아직 해제 안 함.
    static func isVisible(recordCount: Int, dismissed: Bool) -> Bool {
        recordCount >= 3 && !dismissed
    }
}
