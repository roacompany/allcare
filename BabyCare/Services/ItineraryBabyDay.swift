import Foundation

/// 아기 리듬을 하루에 놓는다(시안 일정 판) — 수유는 낮잠 뒤로 밀고, 비행·운전과 겹치면 말한다. 순수.
struct ItineraryBabyDay {
    /// 수유·이유식이 공항에 있을 시각 — 출발 2시간 전부터 · 도착 1시간 뒤까지.
    nonisolated static let airportBeforeDepartureMinutes = 120
    nonisolated static let airportAfterArrivalMinutes = 60
    /// 도착이 밤잠과 맞닿는 범위 — 도착은 「빨라야」라서 앞쪽을 넓게 본다.
    nonisolated static let bedtimeCautionMinutes = 60
    nonisolated static let bedtimeLeadMinutes = 20
    nonisolated static let bedtimeTrailMinutes = 60
    nonisolated static let defaultDayEndMinute = 22 * 60

    let rhythm: BabyRhythm
    /// 그날 0시.
    let day: Date
    let spans: [ItinerarySpan]
    let flights: [TripBooking]
    /// 그날 숙소 도착 예상.
    let arrivals: [Date]
    let calendar: Calendar

    /// 시각 순 · 같은 시각이면 낮잠 → 이유식 → 수유 → 밤잠.
    func lines() -> [PlacedLine] {
        (naps() + solids() + feeds() + bedtime()).enumerated()
            .sorted { $0.element.at == $1.element.at ? $0.offset < $1.offset : ($0.element.at ?? day) < ($1.element.at ?? day) }
            .map(\.element)
    }

    /// 빨라야 도착이 밤잠 앞뒤 한 시간 안이면 맞닿는다.
    func caution(reach: Date) -> Itinerary.Caution? {
        guard let minute = rhythm.bedtimeMinute else { return nil }
        let bed = at(minute)
        let margin = TimeInterval(Self.bedtimeCautionMinutes * 60)
        guard reach >= bed.addingTimeInterval(-margin), reach <= bed.addingTimeInterval(margin) else { return nil }
        let advice = "차에서 잠들면 숙소에서 바로 눕힐 수 있게 아기침대 요청을 먼저 확인하세요."
        return Itinerary.Caution(title: "밤잠 시간과 맞닿아요",
                                 body: rhythm.carSeatNaps > 0 ? "카시트에서 잔 기록이 \(rhythm.carSeatNaps)번 있어요. \(advice)" : advice,
                                 timing: "빨라야 \(clock(reach))에 닿고, 밤잠은 \(TravelChildText.clock(minute))이에요.")
    }

    // MARK: - 홈 아이 칩(시안 Main)

    /// 구간이 있는 일(비행 · 이동) — 낮잠과 겹침 → 밤잠이 그 안 → 밤잠 앞뒤에 걸침.
    func chip(from start: Date, to end: Date, verb: String, during: String) -> String? {
        if let nap = rhythm.naps.first(where: { start < at($0.startMinute + $0.minutes) && end > at($0.startMinute) }) {
            return "낮잠 \(TravelChildText.clock(nap.startMinute))과 \(verb)이 겹쳐요"
        }
        guard let minute = rhythm.bedtimeMinute else { return nil }
        let bed = at(minute)
        if bed >= start, bed < end { return "밤잠 \(TravelChildText.clock(minute)) — \(during) 중이에요" }
        return nearBedtime(from: start, to: end) ? "밤잠 \(TravelChildText.clock(minute)) 무렵이에요" : nil
    }

    /// 한 시각의 일(도착 · 렌터카 인수) — 밤잠 앞뒤면.
    func chip(at time: Date) -> String? {
        guard let minute = rhythm.bedtimeMinute, nearBedtime(from: time, to: time) else { return nil }
        return "밤잠 \(TravelChildText.clock(minute)) 무렵이에요"
    }

    func cautionChip() -> String? {
        rhythm.bedtimeMinute.map { "밤잠 \(TravelChildText.clock($0))과 맞닿아요" }
    }

    /// 밤잠 20분 전 ~ 60분 뒤에 걸치나.
    private func nearBedtime(from start: Date, to end: Date) -> Bool {
        guard let minute = rhythm.bedtimeMinute else { return false }
        let bed = at(minute)
        return start <= bed.addingTimeInterval(TimeInterval(Self.bedtimeTrailMinutes * 60))
            && end >= bed.addingTimeInterval(-TimeInterval(Self.bedtimeLeadMinutes * 60))
    }

    // MARK: - 줄

    private func naps() -> [PlacedLine] {
        rhythm.naps.map { nap in
            let start = at(nap.startMinute), end = at(nap.startMinute + nap.minutes)
            let hit = spans.first { start < $0.end && end > $0.start }
            let detail = hit.map { "\(sharePrefix(nap)), \($0.isFlight ? "탑승" : "운전") 시간과 겹쳐요" } ?? "\(sharePrefix(nap)) 이 시간쯤 잤어요"
            return line("nap-\(nap.startMinute)", start, "낮잠 약 \(nap.minutes)분", detail)
        }
    }

    private func solids() -> [PlacedLine] {
        rhythm.solids.map { solid in
            let time = at(solid.startMinute)
            let place = airport(at: time)
            let base = countShare(solid)
            let detail = travelNote(time) ?? place.flatMap { TripEntryChoices.airportName($0) }.map { "\(base) 이 시간쯤, \($0)에 있을 때예요" } ?? "\(base) 이 시간쯤 먹었어요"
            return line("solid-\(solid.startMinute)", time, "이유식", detail, airportCode: travelNote(time) == nil ? place : nil)
        }
    }

    /// 기상부터 평소 간격마다 · 낮잠 안이면 깬 뒤로 옮기고 다음은 옮긴 시각 + 간격 · 밤잠 전까지.
    private func feeds() -> [PlacedLine] {
        // 기상을 모르면 수유를 놓을 기준이 없다 — 지어내지 않는다.
        guard let wake = rhythm.wakeMinute else { return [] }
        guard let interval = rhythm.dayFeedIntervalMin, interval > 0 else { return [line("wake", at(wake), "기상", nil)] }
        let limit = rhythm.bedtimeMinute ?? Self.defaultDayEndMinute
        var out: [PlacedLine] = []
        var minute = wake
        while minute < limit {
            var moved = false
            if let nap = rhythm.naps.first(where: { minute >= $0.startMinute && minute < $0.startMinute + $0.minutes }) {
                minute = nap.startMinute + nap.minutes
                moved = true
            }
            guard minute < limit else { break }
            let time = at(minute)
            let note = travelNote(time)
            let base = moved ? "낮잠에서 깬 뒤로 잡았어요" : minute == wake ? "깬 뒤 바로, 이후 약 \(TripDelayPlanner.durationText(interval))마다" : nil
            out.append(line("feed-\(minute)", time, "수유", note ?? base, airportCode: note == nil ? airport(at: time) : nil))
            minute += interval
        }
        return out
    }

    private func bedtime() -> [PlacedLine] {
        guard let minute = rhythm.bedtimeMinute else { return [] }
        let time = at(minute)
        let detail = travelNote(time) ?? (arrivals.contains { $0 <= time } ? "숙소 도착 뒤" : nil)
        return [line("bedtime", time, "밤잠", detail)]
    }

    private func line(_ id: String, _ time: Date, _ title: String, _ detail: String?, airportCode: String? = nil) -> PlacedLine {
        PlacedLine(line: Itinerary.Line(id: id, clock: clock(time), title: title, detail: detail, lane: .baby, airportCode: airportCode), at: time)
    }

    // MARK: - 판단

    private func travelNote(_ time: Date) -> String? {
        spans.first { time >= $0.start && time < $0.end }.map { $0.isFlight ? "비행 중이에요" : "운전 중이에요" }
    }

    /// 수유·이유식이 공항에 있을 시각이면 그 공항.
    private func airport(at time: Date) -> String? {
        for f in flights {
            if let depart = f.depart?.time, time < depart,
               time >= depart.addingTimeInterval(-TimeInterval(Self.airportBeforeDepartureMinutes * 60)) {
                return f.fromAirport
            }
            if let arrive = f.arrive?.time, time >= arrive,
               time <= arrive.addingTimeInterval(TimeInterval(Self.airportAfterArrivalMinutes * 60)) {
                return f.toAirport
            }
        }
        return nil
    }

    private func recorded(_ block: BabyRhythm.Block) -> (days: Int, all: Int) {
        let all = rhythm.daysWithRecords
        return (Int((block.share * Double(all)).rounded()), all)
    }

    /// 「최근 7일 동안 매일」 · 「7일 중 6일」.
    private func sharePrefix(_ block: BabyRhythm.Block) -> String {
        let r = recorded(block)
        return r.days >= r.all ? "최근 \(r.all)일 동안 매일" : "\(r.all)일 중 \(r.days)일"
    }

    /// 「7일 모두」 · 「7일 중 6일」.
    private func countShare(_ block: BabyRhythm.Block) -> String {
        let r = recorded(block)
        return r.days >= r.all ? "\(r.all)일 모두" : "\(r.all)일 중 \(r.days)일"
    }

    private func at(_ minute: Int) -> Date {
        day.addingTimeInterval(TimeInterval(minute * 60))
    }

    private func clock(_ date: Date) -> String {
        Itinerary.clock(date, calendar: calendar)
    }
}
