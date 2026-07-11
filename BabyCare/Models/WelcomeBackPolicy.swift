import Foundation

/// 웰컴백 카드 정책 (UX Clean Sweep C5).
/// D1 복귀 넛지(알림)의 착지 경험 — 며칠 만에 돌아온 사용자에게 공백을 부담이 아닌
/// 환영으로 연결한다. 오늘 기록이 생기면 자동 소멸(닫기 불필요).
/// 7일+ 완전 공백은 FirstRecordGuide가 담당 — 최근 7일 데이터 기반이라 자연 상호 배타.
enum WelcomeBackPolicy {
    /// 공백 인정 최소 일수.
    static let minGapDays = 3

    /// 복귀 공백 일수 — 오늘 기록 0 + 마지막 기록이 3일 이상 전일 때만 반환.
    static func gapDays(lastRecordAt: Date?, todayCount: Int, now: Date, calendar: Calendar = .current) -> Int? {
        guard todayCount == 0, let last = lastRecordAt else { return nil }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return days >= minGapDays ? days : nil
    }
}
