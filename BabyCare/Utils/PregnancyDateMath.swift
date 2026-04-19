import Foundation

/// 임신 모드 날짜 계산 pure helpers.
/// UserDefaults / Firestore 의존성 없음 — 단위 테스트 용이.
/// 위젯 + 메인 앱 양쪽에서 사용 (project.yml widget sources에 포함).
enum PregnancyDateMath {

    /// LMP에서 현재까지 경과 주차/일.
    /// - Returns: lmp가 nil이거나 미래면 nil.
    static func weekAndDay(from lmp: Date?, now: Date) -> (weeks: Int, days: Int)? {
        guard let lmp else { return nil }
        let comps = Calendar.current.dateComponents([.day], from: lmp, to: now)
        guard let totalDays = comps.day, totalDays >= 0 else { return nil }
        return (weeks: totalDays / 7, days: totalDays % 7)
    }

    /// 예정일까지 남은 일수.
    /// - Returns: 양수=미래, 0=오늘, 음수=초과(overdue). due가 nil이면 nil.
    static func dDay(due: Date?, now: Date) -> Int? {
        guard let due else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let dueDay = cal.startOfDay(for: due)
        return cal.dateComponents([.day], from: today, to: dueDay).day
    }
}
