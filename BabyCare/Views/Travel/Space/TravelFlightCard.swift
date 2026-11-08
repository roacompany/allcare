import SwiftUI

/// 홈 항공편 칸(시안 Home-Flight) — 머리 「가는 편 · 인천공항 운항 정보, 09:12 확인」 · 테두리 카드 · 「늦어진 시간으로 다시 봤어요」.
/// 목록 줄 여러 개를 낸다(TravelList 안에서 쓴다).
struct TravelFlightSections: View {
    let vm: TripDetailViewModel
    let flight: TripBooking

    private var cal: Calendar { vm.calendar }
    private var number: String { flight.flightNumber ?? flight.airline ?? "항공편" }

    var body: some View {
        let state = vm.flightState(for: flight)
        let outlook = vm.delayOutlook(for: flight)
        let impacts = outlook?.impacts ?? []
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(flight.flightLeg ?? number)
                    .travelFont(16, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                Spacer(minLength: 8)
                if case .loaded(let s)? = state {
                    Text("인천공항 운항 정보, \(TripDateText.time(s.fetchedAt, calendar: cal)) 확인")
                        .travelFont(12)
                        .foregroundStyle(TravelStyle.sub)
                        .monospacedDigit()
                }
            }
            card(state, outlook: outlook)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .travelRow(top: 14, bottom: impacts.isEmpty ? 4 : 0)
        if !impacts.isEmpty {
            Text("늦어진 시간으로 다시 봤어요")
                .travelFont(14, .semibold)
                .foregroundStyle(TravelStyle.body)
                .padding(.top, 14)
                .padding(.bottom, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .travelRow()
            ForEach(impacts, id: \.self) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .travelFont(15)
                        .travelLineHeight(1.35, size: 15)
                        .foregroundStyle(TravelStyle.ink)
                    Text(item.detail)
                        .travelFont(13)
                        .travelLineHeight(1.5, size: 13)
                        .foregroundStyle(TravelStyle.body)
                }
                .monospacedDigit()
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { TravelHairline() }
                .travelRow()
            }
        }
        Color.clear
            .frame(height: 12)
            .travelRow()
    }

    /// 테두리 카드(시안: 여백 14 · 모서리 8 · 1px #E6E8EC · 사이 12).
    private func card(_ state: FlightLiveState?, outlook: TripDelayOutlook?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text("\(number) \(TravelFlightText.place(flight.fromAirport)) → \(TravelFlightText.place(flight.toAirport))")
                    .travelFont(16, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                Spacer(minLength: 8)
                if case .loaded(let s)? = state, let remark = s.remark {
                    TravelChip(text: remark, tone: TravelFlightText.isAlert(s) ? .redStrong : .neutral)
                }
            }
            switch state {
            case .loaded(let s)?:
                if s.direction == .departure {
                    times(("출발", s.estimated ?? s.scheduled, s.scheduled),
                          ("도착", outlook?.arrival ?? flight.arrive?.time, flight.arrive?.time))
                } else {
                    times(("출발(예약)", flight.depart?.time, nil), ("인천 도착", s.estimated ?? s.scheduled, s.scheduled))
                }
                statusLines(s)
            case .later(let day)?:
                times(("출발", flight.depart?.time, nil), ("도착", flight.arrive?.time, nil))
                note("\(TripDateText.day(day, calendar: cal)) 당일에 인천공항 운항 정보로 지연·결항을 보여 드려요.")
            case .notFound?:
                times(("출발", flight.depart?.time, nil), ("도착", flight.arrive?.time, nil))
                note("오늘 인천공항 운항 목록에 없는 편명이에요. 예약의 편명을 확인해 주세요.")
            case .failed?:
                times(("출발", flight.depart?.time, nil), ("도착", flight.arrive?.time, nil))
                HStack(spacing: 8) {
                    note("운항 정보를 못 불러왔어요.")
                    Spacer(minLength: 8)
                    Button {
                        Task { await vm.refreshFlightStatus() }
                    } label: {
                        TravelLinkLabel(text: "다시 확인", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            case .loading?, nil:
                times(("출발", flight.depart?.time, nil), ("도착", flight.arrive?.time, nil))
                HStack(spacing: 6) {
                    ProgressView()
                    note("인천공항 운항 정보를 확인하는 중이에요.")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(TravelStyle.cardBorder, lineWidth: 1))
    }

    /// 출발 · 도착 두 칸(시안: 13 회색 이름 · 20 굵은 시각 · 옆에 13 회색 지운 줄 예정 시각).
    private func times(_ left: (String, Date?, Date?), _ right: (String, Date?, Date?)) -> some View {
        HStack(alignment: .top, spacing: 8) {
            column(left.0, now: left.1, was: left.2)
            column(right.0, now: right.1, was: right.2)
        }
    }

    private func column(_ label: String, now: Date?, was: Date?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .travelFont(13)
                .foregroundStyle(TravelStyle.sub)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(now.map { TripDateText.time($0, calendar: cal) } ?? "미정")
                    .travelFont(20, .bold)
                    .foregroundStyle(TravelStyle.ink)
                if let was, let now, TripDateText.time(was, calendar: cal) != TripDateText.time(now, calendar: cal) {
                    Text(TripDateText.time(was, calendar: cal))
                        .travelFont(13)
                        .strikethrough()
                        .foregroundStyle(TravelStyle.sub)
                }
            }
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statusLines(_ s: FlightLiveStatus) -> some View {
        if let info = TravelFlightText.info(s) {
            note(info)
        }
        if s.isCancelled {
            Text("결항이에요. 항공사 안내를 확인해 주세요.")
                .travelFont(13, .semibold)
                .foregroundStyle(TravelStyle.red)
        } else if s.isDiverted {
            Text("회항했어요. 항공사 안내를 확인해 주세요.")
                .travelFont(13, .semibold)
                .foregroundStyle(TravelStyle.red)
        } else if s.isDelayed, let d = s.delayMinutes, d > 0 {
            Text("예정보다 \(TripDelayPlanner.durationText(d)) 늦어요")
                .travelFont(13, .semibold)
                .foregroundStyle(TravelStyle.red)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .travelFont(13)
            .travelLineHeight(1.5, size: 13)
            .foregroundStyle(TravelStyle.sub)
    }
}

/// 예약 칸 항공편 줄 아래 — 시안 Trip-Bookings 의 회색 칩(22 · 12px) 「지연·결항은 5.10(월) 당일에 보여요」 · 늦으면 빨간 칩.
struct TripFlightLiveLine: View {
    let state: FlightLiveState?
    let isIncheon: Bool
    let calendar: Calendar

    var body: some View {
        if let line {
            TravelChip(text: line.text, tone: line.alert ? .redStrong : .neutral)
                .monospacedDigit()
                .padding(.top, 4)
        }
    }

    private var line: (text: String, alert: Bool)? {
        guard isIncheon else { return ("운항 정보는 인천공항을 오가는 편만 볼 수 있어요", false) }
        switch state {
        case .loaded(let s)?:
            var parts = [s.remark ?? "운항 정보"]
            if let when = s.estimated ?? s.scheduled {
                parts.append((s.direction == .departure ? "출발 " : "인천 도착 ") + TripDateText.time(when, calendar: calendar))
            }
            if s.isDelayed, let d = s.delayMinutes, d > 0 { parts.append("\(TripDelayPlanner.durationText(d)) 늦음") }
            parts.append("\(TripDateText.time(s.fetchedAt, calendar: calendar)) 확인")
            return (parts.joined(separator: " · "), TravelFlightText.isAlert(s))
        case .later(let day)?:
            return ("지연·결항은 \(TripDateText.day(day, calendar: calendar)) 당일에 보여요", false)
        case .loading?:
            return ("운항 정보를 확인하는 중", false)
        case .notFound?:
            return ("오늘 인천공항 목록에 없는 편명이에요", false)
        case .failed?:
            return ("운항 정보를 못 불러왔어요", false)
        case nil:
            return nil
        }
    }
}

/// 항공편 글자 — 공항 한글 이름 · 상태 색 · 탑승구/수하물 줄.
enum TravelFlightText {
    static func place(_ code: String?) -> String {
        guard let code = code?.uppercased() else { return "?" }
        return TripRoutePlace.airports.first { $0.code == code }?.names.first ?? code
    }

    /// 지연 · 결항 · 회항 = 시안 빨간 칩.
    static func isAlert(_ s: FlightLiveStatus) -> Bool {
        s.isCancelled || s.isDiverted || s.isDelayed
    }

    static func terminalName(_ t: String?) -> String? {
        switch t {
        case "T1": return "제1여객터미널"
        case "T2": return "제2여객터미널"
        case "탑승동": return "탑승동"
        default: return nil
        }
    }

    static func info(_ s: FlightLiveStatus) -> String? {
        var parts: [String] = []
        if s.direction == .departure {
            if let g = s.gate { parts.append("탑승구 \(g)") }
        } else {
            if let c = s.carousel { parts.append("수하물 \(c)번") }
            if let e = s.exit { parts.append("\(e) 출구") }
        }
        if let t = terminalName(s.terminal) { parts.append(t) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
