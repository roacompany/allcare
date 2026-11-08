import SwiftUI

/// 항공편 추가·수정(시안 Entry-Flight) — 편명과 날짜만 고르면 인천공항 정기 시간표로 항공사·공항·인천 쪽 시각을 채운다(설계 §8).
/// 시간표에 없는 편(인천 편이 아님)은 공항을 칩으로 고르고 시각을 고른다. ⛔ 모르는 시각은 지어 넣지 않는다(전부 비워 둘 수 있다 · ADR-0001).
struct TripFlightEntrySheet: View {
    let vm: TripDetailViewModel
    let onSave: (TripBooking) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var base: TripBooking
    @State private var number: String
    @State private var day: Date
    @State private var lookup: Lookup = .idle
    /// 시간표에 없는 상대 공항 쪽 시각(가는 편 = 도착 · 오는 편 = 출발).
    @State private var otherTime: Date
    @State private var hasOtherTime: Bool
    // 시간표에 없을 때 — 공항 · 시각을 고른다.
    @State private var fromCode: String
    @State private var toCode: String
    @State private var departTime: Date
    @State private var hasDeparture: Bool
    @State private var arriveTime: Date
    @State private var hasArrival: Bool
    private let isNewBooking: Bool

    enum Lookup: Equatable {
        case idle
        case loading
        case result(FlightLookupResult)
    }

    /// 자주 쓰는 공항 — 여행에 나온 공항이 먼저 온다.
    private static let commonAirports = ["ICN", "GMP", "PUS", "CJU", "KIX", "ITM", "NRT", "HND", "NGO", "FUK", "CTS", "OKA"]

    /// isNew = nil 이면 저장된 예약인지로 정한다 · false 면 받은 값을 그대로 쓴다(Babycare AI 결과 수정).
    init(booking: TripBooking, vm: TripDetailViewModel, isNew: Bool? = nil, onSave: @escaping (TripBooking) -> Void) {
        self.vm = vm
        self.onSave = onSave
        let cal = vm.calendar
        let isNew = isNew ?? !vm.hasBooking(id: booking.id)
        isNewBooking = isNew
        let firstDay = vm.days.first ?? cal.startOfDay(for: vm.today)
        let inbound = booking.toAirport?.uppercased() == TripFlightEntry.incheon
        // CI(Xcode 26.3) 대비 — 삼항·?? 가 겹친 한 줄을 타입 적은 중간값으로 나눈다(값 같음 · 2026-11-08).
        let preferred: TripWhen? = inbound ? booking.arrive : booking.depart
        let known: TripWhen? = preferred ?? booking.depart ?? booking.arrive
        let anchor: Date = isNew ? firstDay : (known?.startOfDay(cal) ?? firstDay)
        let otherSide: TripWhen? = inbound ? booking.depart : booking.arrive
        let other: Date? = isNew ? nil : otherSide?.time
        // 시각 고르기 창이 처음 보여 주는 값 — 창에서 「확인」을 눌러야 들어간다.
        let pickerStart = cal.date(bySettingHour: 12, minute: 0, second: 0, of: anchor) ?? anchor
        _base = State(initialValue: booking)
        _number = State(initialValue: booking.flightNumber ?? "")
        _day = State(initialValue: anchor)
        _otherTime = State(initialValue: other ?? pickerStart)
        _hasOtherTime = State(initialValue: other != nil)
        _fromCode = State(initialValue: booking.fromAirport ?? "")
        _toCode = State(initialValue: booking.toAirport ?? "")
        _departTime = State(initialValue: isNew ? pickerStart : (booking.depart?.time ?? pickerStart))
        _hasDeparture = State(initialValue: !isNew && booking.depart?.time != nil)
        _arriveTime = State(initialValue: isNew ? pickerStart : (booking.arrive?.time ?? pickerStart))
        _hasArrival = State(initialValue: !isNew && booking.arrive?.time != nil)
    }

    private var cal: Calendar { vm.calendar }
    private var normalized: String? { FlightNumber.normalize(number) }
    /// 편명·날짜가 바뀌면 다시 찾는 열쇠 — 수식어 안에 `??` 를 두면 CI(Xcode 26.3)가 body 를 제때 못 푼다(2026-11-08).
    private var lookupKey: String { "\(normalized ?? "")|\(day.timeIntervalSinceReferenceDate)" }

    private var foundRow: FlightScheduleRow? {
        if case .result(.found(let row)) = lookup { return row }
        return nil
    }

    private var showsManual: Bool {
        switch lookup {
        case .result(.notFound), .result(.failed), .result(.notOnThatDay): return true
        default: return false
        }
    }

    /// 저장할 예약 — 시간표에서 찾았으면 그 줄로, 아니면 고른 공항·시각으로.
    private var draft: TripBooking? {
        guard let flight = normalized else { return nil }
        if let row = foundRow {
            return TripBookingForm.normalized(TripFlightEntry.booking(from: row, day: day, otherTime: hasOtherTime ? otherTime : nil,
                                                                      base: base, calendar: cal))
        }
        guard showsManual else { return nil }
        var b = base
        b.flightNumber = flight
        b.airline = TripFlightEntry.airlineCode(flight)
        b.fromAirport = fromCode.isEmpty ? nil : fromCode
        b.toAirport = toCode.isEmpty ? nil : toCode
        let dep = hasDeparture ? TripEntryChoices.combine(day: day, time: departTime, calendar: cal) : nil
        b.depart = dep.map(TripWhen.at) ?? .day(Trip.dayKey(day, calendar: cal))
        if hasArrival {
            let arr = TripEntryChoices.combine(day: day, time: arriveTime, calendar: cal)
            b.arrive = .at(dep.map { arr > $0 } ?? true ? arr : (cal.date(byAdding: .day, value: 1, to: arr) ?? arr))
        } else {
            b.arrive = nil
        }
        return TripBookingForm.normalized(b)
    }

    private var problem: String? {
        guard normalized != nil else { return number.isEmpty ? nil : "편명을 입력해 주세요 (예: KE725)" }
        if lookup == .loading || lookup == .idle { return nil }
        guard let draft else { return nil }
        return TripBookingForm.problem(draft, calendar: cal)
    }

    var body: some View {
        TripEntryScaffold(title: isNewBooking ? "항공편 추가" : "항공편 수정", actionTitle: isNewBooking ? "추가" : "저장",
                          canSubmit: draft != nil && problem == nil, problem: problem) {
            if let draft {
                onSave(draft)
                dismiss()
            }
        } content: {
            TripEntrySection(title: "편명") {
                TextField("KE725", text: $number)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .tripEntryField(big: true)
            }
            TripEntrySection(title: "날짜", top: 0) {
                TripDayChips(days: vm.days, selection: $day, calendar: cal)
            }
            if lookup != .idle {
                TripEntryBand()
                resultSection
            }
            if showsManual {
                manualSections
            }
        }
        .task(id: lookupKey) {
            guard let flight = normalized else {
                lookup = .idle
                return
            }
            lookup = .loading
            try? await Task.sleep(for: .milliseconds(400)) // 적는 중에는 묻지 않는다
            guard !Task.isCancelled else { return }
            let result = await vm.lookupFlight(number: flight, day: day)
            guard !Task.isCancelled else { return }
            lookup = .result(result)
        }
    }

    // MARK: - 찾은 결과

    @ViewBuilder
    private var resultSection: some View {
        switch lookup {
        case .idle:
            EmptyView()
        case .loading:
            TripEntrySection {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("인천공항 시간표에서 찾는 중")
                        .travelFont(14)
                        .foregroundStyle(TravelStyle.sub)
                }
            }
        case .result(.found(let row)):
            foundSection(row)
        case .result(.notOnThatDay):
            message("고른 날 인천공항 시간표에 없는 편이에요")
        case .result(.notFound):
            message("인천공항 시간표에 없는 편이에요")
        case .result(.failed):
            message("시간표를 불러오지 못했어요")
        }
    }

    private func message(_ text: String) -> some View {
        TripEntrySection {
            Text(text)
                .travelFont(14)
                .foregroundStyle(TravelStyle.sub)
        }
    }

    private func foundSection(_ row: FlightScheduleRow) -> some View {
        let place = TripEntryChoices.airportName(row.counterpartCode) ?? (row.counterpartName ?? "상대 공항")
        let incheonClock = String(format: "%02d:%02d", row.hour, row.minute)
        return TripEntrySection(title: "인천공항 시간표에서 찾았어요") {
            VStack(alignment: .leading, spacing: 4) {
                Text([row.airlineName, row.flightId].compactMap { $0 }.joined(separator: " "))
                    .travelFont(16, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                Text(row.direction == .departure ? "인천 \(incheonClock) 출발 → \(place)" : "\(place) → 인천 \(incheonClock) 도착")
                    .travelFont(14)
                    .foregroundStyle(TravelStyle.body)
                    .monospacedDigit()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(TravelStyle.cardBorder, lineWidth: 1))
            TripOptionalTimeRow(title: "\(place) \(row.direction == .departure ? "도착" : "출발")",
                                hasValue: $hasOtherTime, value: $otherTime, calendar: cal)
        }
    }

    // MARK: - 시간표에 없을 때

    @ViewBuilder
    private var manualSections: some View {
        let codes = airportCodes
        TripEntrySection(title: "출발 공항", top: 0) {
            airportChips(codes, selection: $fromCode)
        }
        TripEntrySection(title: "도착 공항", top: 0) {
            airportChips(codes, selection: $toCode)
        }
        TripEntryBand()
        TripEntrySection(title: "시각") {
            TripOptionalTimeRow(title: "출발", hasValue: $hasDeparture, value: $departTime, calendar: cal)
            TripOptionalTimeRow(title: "도착", hasValue: $hasArrival, value: $arriveTime, calendar: cal)
        }
    }

    private var airportCodes: [String] {
        var out: [String] = []
        for f in vm.flightBookings {
            for code in [f.fromAirport, f.toAirport].compactMap({ $0?.uppercased() }) where !out.contains(code) { out.append(code) }
        }
        for code in Self.commonAirports where !out.contains(code) { out.append(code) }
        return out
    }

    private func airportChips(_ codes: [String], selection: Binding<String>) -> some View {
        TravelWrapLayout {
            ForEach(codes, id: \.self) { code in
                TripChoiceChip(title: TripEntryChoices.airportName(code) ?? code, selected: selection.wrappedValue == code) {
                    selection.wrappedValue = code
                }
            }
        }
    }
}
