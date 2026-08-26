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

    /// 그 날짜에 귀속되는 활동 시간의 합(초) — 자정 클립.
    /// 🔑 「이 날 총 몇 시간」을 말하는 자리는 화면·리포트·분석 가릴 것 없이 전부 이걸 쓴다.
    /// 하루 조회는 「그날 시작」 + 「그날 끝」 두 쿼리를 합쳐 오므로(FirestoreService+Activity),
    /// 여기서 전체 duration 을 더하면 자정 넘김 밤잠 하나가 어제·오늘 양쪽에서 통째로 세어진다.
    static func totalClippedDuration(_ activities: [Activity], on day: Date, calendar: Calendar = .current) -> TimeInterval {
        activities.reduce(0) { $0 + clippedDuration($1, on: day, calendar: calendar) }
    }

    /// 그 날짜에 「일어난 것으로 세는」 기록 — 시작 시각 기준 하루 귀속.
    /// 🔑 시간(duration)은 자정에서 잘라 두 날에 나눠 주지만, **횟수·양은 나눌 수 없다**.
    /// 하루 조회는 「그날 끝난」 기록도 실어 오므로, 거르지 않고 세면 자정을 넘긴 수유 한 번이
    /// 어제도 1회·오늘도 1회가 된다(양도 같이 두 번 더해진다).
    static func startedOn(_ activities: [Activity], day: Date, calendar: Calendar = .current) -> [Activity] {
        activities.filter { calendar.isDate($0.startTime, inSameDayAs: day) }
    }

    /// 기간 안에서 시작한 기록 — 횟수·분포·평균이 세는 것.
    /// 🔑 기간 조회는 자정 넘김 밤잠을 잡으려고 **하루 앞당겨** 부른다. 그 앞당긴 하루가
    /// 횟수와 그래프 막대로 새지 않도록, 세는 자리는 이걸로 걷어낸 목록을 본다.
    static func startedWithin(_ activities: [Activity], from: Date, to: Date) -> [Activity] {
        activities.filter { $0.startTime >= from && $0.startTime <= to }
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
