import Foundation

/// 기록 스트릭 정책 (UX Clean Sweep C1).
/// 기존 스트릭은 Routine 100% 완료 전용 — 이건 "일반 기록"을 하루라도 남긴 연속 일수.
/// 매일 돌아올 이유(리텐션)를 만든다. KST 자정 경계는 dayKey(YYYY-MM-DD)로 결정적 처리.
enum RecordStreakPolicy {
    /// 로컬 날짜 키(YYYY-MM-DD) — 시간대·시각 무관 하루 식별.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 오늘 기록 시 갱신된 스트릭. 오늘 이미 카운트됐으면 nil(변경 없음).
    /// - 어제 마지막 기록 → previousStreak + 1
    /// - 그 외(공백 ≥2일 / 최초) → 1로 재시작
    static func updatedStreak(previousStreak: Int, lastDayKey: String?, now: Date, calendar: Calendar = .current) -> Int? {
        let todayKey = dayKey(now, calendar: calendar)
        guard lastDayKey != todayKey else { return nil }   // 오늘 이미 카운트 — 변경 없음

        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterdayKey = dayKey(yesterday, calendar: calendar)
        if lastDayKey == yesterdayKey {
            return max(1, previousStreak) + 1
        }
        return 1
    }

    /// 스트릭 값으로 새로 획득 가능한 배지 id 목록 (임계 도달분).
    static func earnedBadgeIds(streak: Int) -> [String] {
        [("recordStreak3", 3), ("recordStreak7", 7), ("recordStreak14", 14)]
            .filter { streak >= $0.1 }
            .map(\.0)
    }
}
