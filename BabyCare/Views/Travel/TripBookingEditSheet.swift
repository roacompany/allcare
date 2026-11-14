import SwiftUI

/// 숙소·렌터카 추가·수정(시안 Entry-Hotel · Entry-Rental) — 적는 대신 고른다(설계 §8).
/// 숙소는 찾기 화면에서 골라 이름·주소를 같이 채우고, 날짜는 여행 날짜 칩, 장소는 그 여행에 이미 있는 곳 칩 + 찾기 화면.
/// 항공편은 TripFlightEntrySheet(편명 + 날짜만). PO 2026-11-05 시안: 라벨·값·버튼만(설명 줄 없음).
struct TripBookingEditSheet: View {
    let vm: TripDetailViewModel
    let onSave: (TripBooking) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TripBooking
    @State private var search: PlaceSearchModel
    private let isNewBooking: Bool

    /// isNew = nil 이면 저장된 예약인지로 정한다 · false 면 받은 값을 그대로 쓴다(Babycare AI 결과 수정 — 기본값을 덮지 않는다).
    init(booking: TripBooking, vm: TripDetailViewModel, isNew: Bool? = nil, onSave: @escaping (TripBooking) -> Void) {
        self.vm = vm
        self.onSave = onSave
        let isNew = isNew ?? !vm.hasBooking(id: booking.id)
        isNewBooking = isNew
        var b = booking
        // 새 렌터카 — 인수는 가는 편이 내리는 날, 반납은 오는 편이 뜨는 날(날짜만 · 시각은 사람이 넣는다).
        if booking.kind == .rentalCar, isNew {
            if let pickup = vm.rentalPickupDefault { b.pickup = pickup }
            if let back = vm.rentalReturnDefault { b.carReturn = back }
        }
        _draft = State(initialValue: b)
        _search = State(initialValue: PlaceSearchModel(lodgingOnly: booking.kind == .hotel))
    }

    private var cal: Calendar { vm.calendar }

    private var title: String {
        let kind: String
        switch draft.kind {
        case .flight: kind = "항공편"
        case .hotel: kind = "숙소"
        case .rentalCar: kind = "렌터카"
        case .unknown: kind = "예약"
        }
        return "\(kind) \(isNewBooking ? "추가" : "수정")"
    }

    private var problem: String? { TripBookingForm.problem(draft, calendar: cal) }

    var body: some View {
        TripEntryScaffold(title: title, actionTitle: isNewBooking ? "추가" : "저장", canSubmit: problem == nil, problem: problem) {
            onSave(TripBookingForm.normalized(draft))
            dismiss()
        } content: {
            switch draft.kind {
            case .hotel: hotelSections
            case .rentalCar: rentalSections
            case .flight, .unknown:
                TripEntrySection {
                    Text("이 예약은 새 버전 앱에서 수정할 수 있어요.")
                        .travelFont(14)
                        .foregroundStyle(TravelStyle.sub)
                }
            }
        }
        .task { await search.bias(toCity: vm.trip.city) }
    }

    // MARK: - 숙소

    @ViewBuilder
    private var hotelSections: some View {
        TripEntrySection(title: "숙소") {
            TripPlaceField(title: "숙소", text: text(\.name), choices: [], showsAirports: false, search: search) { pick in
                draft = TripBookingForm.pickingHotel(pick, into: draft)
            }
        }
        TripEntryBand()
        TripEntrySection(title: "체크인") {
            TripWhenField(timeTitle: "체크인 시작", days: vm.days, value: $draft.checkIn, calendar: cal)
            TripMinuteRow(title: "체크인 마감", minute: $draft.checkInUntilMinute, calendar: cal)
        }
        TripEntrySection(title: "체크아웃", top: 0) {
            TripWhenField(timeTitle: "시각", days: vm.days, value: $draft.checkOut, calendar: cal)
        }
        TripEntryBand()
        TripEntrySection(title: "무료 취소") {
            TripFreeCancelChips(anchor: draft.checkIn, value: $draft.freeCancel, calendar: cal)
        }
    }

    // MARK: - 렌터카

    @ViewBuilder
    private var rentalSections: some View {
        TripEntrySection(title: "업체") {
            TextField("업체 이름", text: text(\.company))
                .autocorrectionDisabled()
                .tripEntryField()
        }
        TripEntryBand()
        TripEntrySection(title: "인수 장소") {
            TripPlaceField(title: "인수 장소", text: rentalPlace(.pickup), choices: vm.entryPlaces, search: search) { pick in
                draft = TripBookingForm.pickingRentalPlace(pick, at: .pickup, into: draft)
            }
            TripWhenField(timeTitle: "인수 시각", days: vm.days, value: $draft.pickup, calendar: cal)
        }
        TripEntryBand()
        TripEntrySection(title: "반납 장소") {
            TripPlaceField(title: "반납 장소", text: rentalPlace(.carReturn), choices: vm.entryPlaces, search: search) { pick in
                draft = TripBookingForm.pickingRentalPlace(pick, at: .carReturn, into: draft)
            }
            TripWhenField(timeTitle: "반납 시각", days: vm.days, value: $draft.carReturn, calendar: cal)
        }
        TripEntryBand()
        TripEntrySection(title: "무료 취소") {
            TripFreeCancelChips(anchor: draft.pickup, value: $draft.freeCancel, calendar: cal)
        }
    }

    /// 인수·반납 장소 칸 — 칩·직접 입력으로 다른 이름이 되면 그 칸의 주소를 비운다(TripBookingForm).
    private func rentalPlace(_ spot: TripBookingForm.RentalSpot) -> Binding<String> {
        Binding(get: { (spot == .pickup ? draft.pickupPlace : draft.returnPlace) ?? "" },
                set: { draft = TripBookingForm.typingRentalPlace($0.isEmpty ? nil : $0, at: spot, into: draft) })
    }

    private func text(_ kp: WritableKeyPath<TripBooking, String?>) -> Binding<String> {
        Binding(get: { draft[keyPath: kp] ?? "" },
                set: { draft[keyPath: kp] = $0.isEmpty ? nil : $0 })
    }

}

/// 일정 추가·수정(시안 Entry-Move) — 출발지·도착지는 칩(그 여행의 공항·숙소·렌터카 장소·전에 넣은 곳) + 지도 찾기,
/// 소요 시간은 두 곳이 정해지면 지도로 바로 채운다(직접 입력 가능).
struct TripMoveEditSheet: View {
    let vm: TripDetailViewModel
    let onSave: (TripMove) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TripMove
    @State private var search = PlaceSearchModel()
    /// 지도가 낸 소요 시간.
    @State private var route: RouteEstimate?
    @State private var routeMissing = false
    /// 소요 시간을 사람이 직접 입력했으면 지도 값으로 덮지 않는다.
    @State private var minutesTouched: Bool
    /// 출발 시각을 넣었나 — 앞 일이 없는 날은 비어 있다가 사람이 넣는다(지어내지 않는다).
    @State private var hasStart: Bool
    private let isNewMove: Bool
    init(move: TripMove, vm: TripDetailViewModel, onSave: @escaping (TripMove) -> Void) {
        self.vm = vm
        self.onSave = onSave
        let isNew = !vm.trip.moves.contains { $0.id == move.id }
        isNewMove = isNew
        _draft = State(initialValue: move)
        _minutesTouched = State(initialValue: !isNew)
        _hasStart = State(initialValue: !isNew || vm.moveStart(on: move.startAt) != nil)
    }

    private var cal: Calendar { vm.calendar }

    private var canSave: Bool {
        !draft.fromLabel.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.toLabel.trimmingCharacters(in: .whitespaces).isEmpty
            && draft.minutes > 0
            && hasStart
    }

    /// 출발지·도착지 칸 — 칩·직접 입력으로 다른 이름이 되면 그 칸의 주소를 비운다(TripBookingForm).
    private func movePlace(_ end: TripBookingForm.MoveEnd) -> Binding<String> {
        Binding(get: { end == .from ? draft.fromLabel : draft.toLabel },
                set: { draft = TripBookingForm.typingMovePlace($0, at: end, into: draft) })
    }

    private var minutes: Binding<Int> {
        Binding(get: { draft.minutes }, set: {
            draft.minutes = $0
            minutesTouched = true
        })
    }

    var body: some View {
        TripEntryScaffold(title: isNewMove ? "일정 추가" : "일정 수정", actionTitle: isNewMove ? "추가" : "저장", canSubmit: canSave) {
            onSave(draft)
            dismiss()
        } content: {
            TripEntrySection(title: "출발지") {
                TripPlaceField(title: "출발지", text: movePlace(.from), choices: vm.entryPlaces, search: search) { pick in
                    draft = TripBookingForm.pickingMovePlace(pick, at: .from, into: draft)
                }
            }
            TripEntrySection(title: "도착지", top: 0) {
                TripPlaceField(title: "도착지", text: movePlace(.to), choices: vm.entryPlaces, search: search) { pick in
                    draft = TripBookingForm.pickingMovePlace(pick, at: .to, into: draft)
                }
            }
            TripEntryBand()
            TripEntrySection(title: "출발") {
                TripDayChips(days: vm.days, selection: $draft.startAt, calendar: cal)
                TripOptionalTimeRow(title: "시각", hasValue: $hasStart, value: $draft.startAt, calendar: cal)
            }
            TripEntryBand()
            TripEntrySection(title: "소요 시간") {
                routeLine
                HStack(spacing: 12) {
                    Text("직접 입력")
                        .travelFont(15)
                        .foregroundStyle(TravelStyle.ink)
                    Spacer(minLength: 8)
                    Stepper("직접 입력", value: minutes, in: 5...600, step: 5)
                        .labelsHidden()
                    Text(TripDelayPlanner.durationText(draft.minutes))
                        .travelFont(16, .semibold)
                        .foregroundStyle(TravelStyle.ink)
                        .monospacedDigit()
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(RoundedRectangle(cornerRadius: 8).fill(TravelStyle.chip))
                }
                .frame(minHeight: 48)
                if let route, minutesTouched, rounded(route.minutes) != draft.minutes {
                    Button("지도 값으로 (\(TripDelayPlanner.durationText(rounded(route.minutes))))") {
                        draft.minutes = rounded(route.minutes)
                        minutesTouched = false
                    }
                    .travelFont(14)
                    .foregroundStyle(TravelStyle.primary)
                    .buttonStyle(.plain)
                }
                if let url = GoogleMapsLink.directions(from: draft.fromLabel, to: draft.toLabel) {
                    Link(destination: url) {
                        TravelLinkLabel(text: "구글지도로 길 보기", systemImage: "arrow.up.right")
                    }
                }
            }
        }
        .task { await search.bias(toCity: vm.trip.city) }
        .task(id: "\(TripBookingForm.routeText(for: draft, at: .from))\u{1F}\(TripBookingForm.routeText(for: draft, at: .to))") {
            await estimate()
        }
    }

    @ViewBuilder
    private var routeLine: some View {
        if let route {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("차로 약 \(TripDelayPlanner.durationText(route.minutes))")
                    .travelFont(22, .bold)
                    .foregroundStyle(TravelStyle.ink)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Text(route.source.label)
                    .travelFont(13)
                    .foregroundStyle(TravelStyle.sub)
            }
        } else if routeMissing {
            Text("지도에서 길을 찾지 못했어요")
                .travelFont(14)
                .foregroundStyle(TravelStyle.sub)
        }
    }

    private func rounded(_ minutes: Int) -> Int {
        min(600, max(5, Int((Double(minutes) / 5).rounded()) * 5))
    }

    /// 두 곳이 정해지면 차 시간 — 적는 중에는 묻지 않는다(0.6초 쉼).
    private func estimate() async {
        // 찾아 고른 곳은 주소로 묻는다(같은 이름이 다른 지역에도 있다 · 2026-11-14)
        let from = TripBookingForm.routeText(for: draft, at: .from).trimmingCharacters(in: .whitespaces)
        let to = TripBookingForm.routeText(for: draft, at: .to).trimmingCharacters(in: .whitespaces)
        guard !from.isEmpty, !to.isEmpty else {
            route = nil
            routeMissing = false
            return
        }
        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }
        let found = await vm.drivingRoute(from: from, to: to)
        // 그사이 장소를 바꿨으면 늦게 온 답은 버린다(새 장소의 값을 덮으면 안 된다).
        guard !Task.isCancelled else { return }
        guard let r = found else {
            route = nil
            routeMissing = true
            return
        }
        routeMissing = false
        route = r
        if !minutesTouched {
            draft.minutes = rounded(r.minutes)
        }
    }
}
