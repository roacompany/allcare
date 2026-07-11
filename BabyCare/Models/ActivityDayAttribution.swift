import Foundation

/// 활동의 "하루 귀속" 정책 (자정 넘김 수면 버그 fix).
/// 저장 데이터는 startTime/endTime 그대로 두고, 조회·합계·캘린더 표시 시점에
/// 활동이 걸친 날짜들로 귀속시킨다 — 자정을 넘긴 수면은 시작일과 종료일 양쪽에 보이고,
/// 하루 합계는 그 날짜에 실제로 걸친 구간만 클립해 더한다.
enum ActivityDayAttribution {

    /// 안전 상한 — 손상 데이터(비정상 endTime)로 인한 폭주 방지. 실사용 수면은 1~2일.
    static let maxSpannedDays = 31

    /// 실효 종료 시각: endTime > (startTime + duration 레거시) > 시작 시각(포인트 이벤트).
    static func effectiveEnd(startTime: Date, endTime: Date?, duration: TimeInterval?) -> Date {
        if let endTime { return endTime }
        if let duration { return startTime.addingTimeInterval(duration) }
        return startTime
    }

    /// 활동 구간 [startTime, effectiveEnd]가 해당 날짜와 겹치는가.
    /// 종료가 정확히 자정(다음날 00:00)인 활동은 다음날에 포함되지 않는다.
    static func overlaps(day: Date, startTime: Date, endTime: Date?, duration: TimeInterval?, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        guard startTime < nextDayStart else { return false }
        let end = effectiveEnd(startTime: startTime, endTime: endTime, duration: duration)
        // 구간이 날짜 안으로 파고들었거나(end > dayStart), 시작 자체가 이 날짜(포인트 이벤트 포함)
        return end > dayStart || startTime >= dayStart
    }

    /// 기간 [periodStart, periodEnd] 와 겹치는 시간(초) — 기간 경계로 클립 (주간 합계용, D1).
    static func clippedDuration(from periodStart: Date, to periodEnd: Date, startTime: Date, endTime: Date?, duration: TimeInterval?) -> TimeInterval {
        let end = effectiveEnd(startTime: startTime, endTime: endTime, duration: duration)
        let clippedStart = max(startTime, periodStart)
        let clippedEnd = min(end, periodEnd)
        return max(0, clippedEnd.timeIntervalSince(clippedStart))
    }

    /// 해당 날짜에 귀속되는 시간(초) — 날짜 경계로 클립. 포인트 이벤트/역전 구간은 0.
    static func clippedDuration(on day: Date, startTime: Date, endTime: Date?, duration: TimeInterval?, calendar: Calendar = .current) -> TimeInterval {
        let dayStart = calendar.startOfDay(for: day)
        guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }
        let end = effectiveEnd(startTime: startTime, endTime: endTime, duration: duration)
        let clippedStart = max(startTime, dayStart)
        let clippedEnd = min(end, nextDayStart)
        return max(0, clippedEnd.timeIntervalSince(clippedStart))
    }

    /// 활동이 걸친 날짜들(각 날짜의 startOfDay). 상한 maxSpannedDays.
    static func spannedDays(startTime: Date, endTime: Date?, duration: TimeInterval?, calendar: Calendar = .current) -> [Date] {
        let end = effectiveEnd(startTime: startTime, endTime: endTime, duration: duration)
        var day = calendar.startOfDay(for: startTime)
        var days: [Date] = []
        while days.count < maxSpannedDays {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            // 다음 날짜에 구간이 파고들지 않으면 종료 (자정 정각 종료 = 다음날 미포함)
            guard end > next else { break }
            day = next
        }
        return days
    }

    /// 하루 조회 2쿼리(startTime-in-day + endTime-in-day) 결과 병합 — id dedupe + startTime 내림차순.
    static func mergeDayResults(_ primary: [Activity], _ secondary: [Activity]) -> [Activity] {
        var seen = Set<String>()
        var merged: [Activity] = []
        for activity in primary + secondary where seen.insert(activity.id).inserted {
            merged.append(activity)
        }
        return merged.sorted { $0.startTime > $1.startTime }
    }
}

// MARK: - Activity 편의 오버로드

extension ActivityDayAttribution {
    static func overlaps(_ activity: Activity, day: Date, calendar: Calendar = .current) -> Bool {
        overlaps(day: day, startTime: activity.startTime, endTime: activity.endTime, duration: activity.duration, calendar: calendar)
    }

    static func clippedDuration(_ activity: Activity, on day: Date, calendar: Calendar = .current) -> TimeInterval {
        clippedDuration(on: day, startTime: activity.startTime, endTime: activity.endTime, duration: activity.duration, calendar: calendar)
    }

    static func spannedDays(_ activity: Activity, calendar: Calendar = .current) -> [Date] {
        spannedDays(startTime: activity.startTime, endTime: activity.endTime, duration: activity.duration, calendar: calendar)
    }
}

// MARK: - 종료 시간 입력 지원 타입

extension Activity.ActivityType {
    /// 종료 시간(구간) 입력이 의미 있는 타입 — 기록 뷰의 showEndTime과 동일 집합.
    /// 편집 시트에서 endTime 없는 기존 기록에도 종료 시간 추가를 허용하는 기준.
    var supportsEndTime: Bool {
        needsTimer || self == .bath
    }
}
