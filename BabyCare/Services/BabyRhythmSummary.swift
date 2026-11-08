import Foundation

/// 7일 기록으로 계산한 아기 리듬 — 일정표(Itinerary)와 할 일(이유식 고기)이 쓴다.
/// 시각은 모두 「하루 중 몇 분째」(0 = 0시).
struct BabyRhythm: Hashable, Sendable {
    struct Block: Hashable, Sendable {
        let startMinute: Int
        let minutes: Int
        /// 그 묶음이 있던 날 ÷ 기록이 있는 날.
        let share: Double
    }

    let naps: [Block]
    let bedtimeMinute: Int?
    let wakeMinute: Int?
    let dayFeedIntervalMin: Int?
    /// 이유식 시각 묶음(minutes 는 0).
    let solids: [Block]
    let carSeatNaps: Int
    let daysWithRecords: Int
    let meat: MeatPresence
    let hasSolids: Bool

    /// 기록 있는 날이 4일 미만이면 「기록이 적어 대략이에요」.
    var isRough: Bool { daysWithRecords < 4 }
}

/// 계산 기준 = 「베이비케어 연동 명세」(10/17) 그대로 — 설계서 §6. 앱에 세 번째 기준을 만들지 않는다.
enum BabyRhythmSummary {
    // 경계 — SleepAnalysisService(낮잠 06~18시) · FeedingPredictionService(낮 06~22시 · 6시간 상한)와 같다.
    nonisolated static let napStartHour = 6
    nonisolated static let napEndHour = 18
    nonisolated static let napMustEndBeforeHour = 19
    nonisolated static let minNapMinutes = 15
    nonisolated static let clusterGapMinutes = 90
    nonisolated static let clusterWidthMinutes = 120
    nonisolated static let minShare = 0.3
    nonisolated static let nightMinMinutes = 60
    nonisolated static let wakeEarliestHour = 4
    nonisolated static let wakeLatestHour = 10
    nonisolated static let dayDefaultStartHour = 6
    nonisolated static let dayDefaultEndHour = 22
    nonisolated static let maxFeedGapMinutes = 360
    nonisolated static let minFeedGaps = 4
    nonisolated static let windowDays = 7
    /// 고기 낱말 — 「고기」라는 말이 없는 흔한 이유식 이름까지(닭죽 · 한우 진밥 · 소안심죽 · 사골 미음).
    /// 헷갈리면 「있음」 쪽으로 잡는다(벌금 300만 엔 규칙이라 「없음」이 더 위험하다) · 「소」 한 글자는 쓰지 않는다(소금).
    private static let meatWords = ["고기", "닭", "돼지", "오리", "한우", "안심", "등심", "우둔", "사태", "양지",
                                    "사골", "육수", "햄", "소시지", "베이컨", "차돌", "갈비"]
    /// 먼저 지우는 말 — 고기가 아니다.
    private static let notMeatWords = ["물고기"]

    /// 출발 전엔 [오늘 0시 − 7일, 오늘 0시) · 출발일부터는 [출발일 0시 − 7일, 출발일 0시) — 여행 중 흐트러진 날이 섞이지 않게.
    static func window(trip: Trip, now: Date, calendar: Calendar) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        var anchor = today
        if let start = Trip.date(fromDayKey: trip.startDay, calendar: calendar), today >= start {
            anchor = start
        }
        let from = calendar.date(byAdding: .day, value: -windowDays, to: anchor) ?? anchor
        return DateInterval(start: from, end: anchor)
    }

    static func build(activities: [Activity], window: DateInterval, calendar: Calendar) -> BabyRhythm {
        // 같은 기록은 한 번만(자정 넘긴 잠은 어제·오늘 목록 양쪽에 들어온다) · 창에서 시작한 것만 센다.
        var seen = Set<String>()
        let unique = activities.filter { seen.insert($0.id).inserted && $0.type != .unknown }
        let inWindow = ActivityDayAttribution.startedWithin(unique, from: window.start,
                                                            to: window.end.addingTimeInterval(-0.001))
        let day: (Date) -> Date = { calendar.startOfDay(for: $0) }
        let minuteOfDay: (Date) -> Int = {
            let c = calendar.dateComponents([.hour, .minute], from: $0)
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        let recordDays = Set(inWindow.map { day($0.startTime) })

        // ── 잠 ──
        let sleeps = inWindow.filter { $0.type == .sleep }
        let sleepDays = Set(sleeps.map { day($0.startTime) })
        var naps: [Sample] = []
        var nights: [Activity] = []
        for s in sleeps {
            guard let end = s.endTime else { continue }
            let hour = calendar.component(.hour, from: s.startTime)
            let minutes = Int(end.timeIntervalSince(s.startTime) / 60)
            if hour >= napStartHour && hour < napEndHour {
                let limit = calendar.date(bySettingHour: napMustEndBeforeHour, minute: 0, second: 0, of: s.startTime) ?? end
                if minutes >= minNapMinutes && end < limit {
                    naps.append(Sample(day: day(s.startTime), minute: minuteOfDay(s.startTime), minutes: minutes,
                                       isCarSeat: s.sleepMethod == .carSeat))
                }
            } else {
                nights.append(s)
            }
        }
        let napBlocks = cluster(naps, denominator: sleepDays.count)

        // 밤잠 시작 — 밤마다(18시 이후 = 그날 밤 · 06시 전 = 전날 밤) 1시간 넘게 잔 첫 잠.
        var firstNightSleep: [Date: Date] = [:]
        for s in nights {
            guard let end = s.endTime, end.timeIntervalSince(s.startTime) > TimeInterval(nightMinMinutes * 60) else { continue }
            let hour = calendar.component(.hour, from: s.startTime)
            let nightDay = hour < napStartHour ? (calendar.date(byAdding: .day, value: -1, to: day(s.startTime)) ?? day(s.startTime)) : day(s.startTime)
            if let current = firstNightSleep[nightDay], current <= s.startTime { continue }
            firstNightSleep[nightDay] = s.startTime
        }
        // 자정 넘긴 시작(예: 00:30)은 24시간을 더해 중앙값을 낸다.
        let bedtimes = firstNightSleep.values.map { start -> Int in
            let m = minuteOfDay(start)
            return m < napStartHour * 60 ? m + 1440 : m
        }
        let bedtime = median(bedtimes).map { $0 % 1440 }

        // 기상 — 밤잠을 끝난 날짜로 묶어 04~10시에 끝난 것 중 가장 늦은 끝.
        var wakeByDay: [Date: Int] = [:]
        for s in nights {
            guard let end = s.endTime else { continue }
            let m = minuteOfDay(end)
            guard m >= wakeEarliestHour * 60 && m < wakeLatestHour * 60 else { continue }
            wakeByDay[day(end)] = max(wakeByDay[day(end)] ?? 0, m)
        }
        let wake = median(Array(wakeByDay.values))

        // ── 낮 수유 간격 — 모유·병수유만 · 그날 기상~밤잠(모르면 06~22시) · 6시간 넘는 간격 뺌 ──
        let feeds = inWindow.filter { $0.type == .feedingBreast || $0.type == .feedingBottle }
        var gaps: [Int] = []
        for (feedDay, list) in Dictionary(grouping: feeds, by: { day($0.startTime) }) {
            let from = wakeByDay[feedDay] ?? dayDefaultStartHour * 60
            let to: Int = firstNightSleep[feedDay].map(minuteOfDay) ?? dayDefaultEndHour * 60
            let starts = list.map { minuteOfDay($0.startTime) }.filter { $0 >= from && $0 < to }.sorted()
            for (a, b) in zip(starts, starts.dropFirst()) where b - a <= maxFeedGapMinutes {
                gaps.append(b - a)
            }
        }
        let feedInterval = gaps.count >= minFeedGaps ? median(gaps) : nil

        // ── 이유식 — 낮잠과 같은 묶기 규칙 · 고기 낱말 ──
        let solidRecords = inWindow.filter { $0.type == .feedingSolid }
        let solidSamples = solidRecords.map { Sample(day: day($0.startTime), minute: minuteOfDay($0.startTime), minutes: 0, isCarSeat: false) }
        let solidBlocks = cluster(solidSamples, denominator: recordDays.count)

        return BabyRhythm(
            naps: napBlocks,
            bedtimeMinute: bedtime,
            wakeMinute: wake,
            dayFeedIntervalMin: feedInterval,
            solids: solidBlocks,
            carSeatNaps: naps.filter(\.isCarSeat).count,
            daysWithRecords: recordDays.count,
            meat: meatPresence(solidRecords),
            hasSolids: !solidRecords.isEmpty)
    }

    // MARK: - 내부

    private struct Sample {
        let day: Date
        let minute: Int
        let minutes: Int
        let isCarSeat: Bool
    }

    /// 시각 순으로 늘어놓고 묶는다: 앞 것보다 90분 넘게 늦거나 · 같은 날 것이 이미 있거나 · 폭이 2시간을 넘으면 새 묶음.
    /// share = 그 묶음에 있는 날 ÷ denominator · 0.3 미만은 버린다.
    private static func cluster(_ samples: [Sample], denominator: Int) -> [BabyRhythm.Block] {
        guard denominator > 0 else { return [] }
        var groups: [[Sample]] = []
        for s in samples.sorted(by: { $0.minute < $1.minute }) {
            if var last = groups.last, let prev = last.last, let first = last.first,
               s.minute - prev.minute <= clusterGapMinutes,
               s.minute - first.minute <= clusterWidthMinutes,
               !last.contains(where: { $0.day == s.day }) {
                last.append(s)
                groups[groups.count - 1] = last
            } else {
                groups.append([s])
            }
        }
        return groups.compactMap { g in
            let share = Double(Set(g.map(\.day)).count) / Double(denominator)
            guard share >= minShare, let start = median(g.map(\.minute)), let length = median(g.map(\.minutes)) else { return nil }
            return BabyRhythm.Block(startMinute: start, minutes: length, share: share)
        }
    }

    private static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    /// 고기 낱말이 하나라도 있으면 있음 · 이름 없는 이유식이 있으면 모름 · 모두 이름이 있고 고기 낱말이 없으면 없음.
    private static func meatPresence(_ solids: [Activity]) -> MeatPresence {
        guard !solids.isEmpty else { return .noSolids }
        var nameless = false
        for s in solids {
            guard var name = s.foodName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                nameless = true
                continue
            }
            for w in notMeatWords { name = name.replacingOccurrences(of: w, with: "") }
            if meatWords.contains(where: { name.contains($0) }) { return .present }
        }
        return nameless ? .unknown : .absent
    }
}
