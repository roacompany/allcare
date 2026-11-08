import PhotosUI
import SwiftUI

/// 예약 칸(시안 「여행: 예약」) — 가는 날 시간표(시각 · 번호 · 정류장 · 사이 이동) · 띠 · 다른 날 예약 · 띠 · 이동.
/// 줄을 누르면 고치고, 밀어서 지운다(확인 뒤). 지도 그림은 아직 없다(구글 지도 그림은 키가 있어야 한다).
struct TripBookingsSection: View {
    let vm: TripDetailViewModel
    let onEdit: (TripBooking) -> Void
    let onEditMove: (TripMove) -> Void
    /// 「예약 추가」 칩(항공편 · 숙소 · 렌터카) — 메뉴 대신 보이게(시안 Trip-Bookings).
    var onAdd: (TripBooking.Kind) -> Void = { _ in }
    /// 「Babycare AI로 추가」 — 고른 예약 확인 이미지.
    var onCapture: ([PhotosPickerItem]) -> Void = { _ in }

    @Environment(\.openURL) private var openURL
    @State private var pendingDelete: TripBooking?
    @State private var pendingMoveDelete: TripMove?
    @State private var pickerItems: [PhotosPickerItem] = []

    private var cal: Calendar { vm.calendar }

    var body: some View {
        let plan = vm.itinerary.bookings

        addArea
        TravelBandRow()
        if !plan.dayOne.isEmpty {
            dayOneHeader(plan)
            ForEach(Array(plan.dayOne.enumerated()), id: \.element.id) { index, stop in
                stopRow(stop, number: index + 1, isLast: index == plan.dayOne.count - 1)
                if let leg = stop.legAfter {
                    connector {
                        legText(leg, caution: stop.caution)
                    }
                }
            }
        }
        if !plan.otherDays.isEmpty {
            if !plan.dayOne.isEmpty { TravelBandRow() }
            TravelSectionHeader(title: plan.dayOne.isEmpty ? "예약" : "다른 날 예약")
                .padding(.top, plan.dayOne.isEmpty ? 4 : 0)
                .travelRow()
            ForEach(plan.otherDays) { stop in
                otherRow(stop)
            }
        }
        if !vm.trip.moves.isEmpty {
            TravelBandRow()
            TravelSectionHeader(title: "일정")
                .travelRow()
        }
        ForEach(vm.trip.moves) { m in
            Button { onEditMove(m) } label: {
                HStack(alignment: .top, spacing: 12) {
                    icon("arrow.triangle.turn.up.right.diamond")
                    VStack(alignment: .leading, spacing: 2) {
                        title("\(m.fromLabel) → \(m.toLabel)")
                        line("\(TripDateText.dayTime(m.startAt, calendar: cal)), 약 \(m.minutes)분")
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { TravelHairline() }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .travelRow()
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { pendingMoveDelete = m } label: { Label("삭제", systemImage: "trash") }
            }
        }
        Color.clear
            .frame(height: 16)
            .travelRow()
    }

    // MARK: - 예약 추가(시안 Trip-Bookings · PO 판 문구) — Babycare AI로 추가 · + 항공편 · + 숙소 · + 렌터카

    private var addArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("예약 추가")
                .travelFont(16, .semibold)
                .foregroundStyle(TravelStyle.ink)
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                TripCaptureButtonLabel()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("travel.captureAdd")
            HStack(spacing: 8) {
                TravelAddChip(title: "항공편", wide: true) { onAdd(.flight) }
                TravelAddChip(title: "숙소", wide: true) { onAdd(.hotel) }
                TravelAddChip(title: "렌터카", wide: true) { onAdd(.rentalCar) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .travelRow(top: 14, bottom: 16)
        .onChange(of: pickerItems) { _, picked in
            guard !picked.isEmpty else { return }
            onCapture(picked)
            pickerItems = []
        }
        .confirmationDialog("이 예약을 삭제할까요?", isPresented: bookingDeleteBinding, titleVisibility: .visible, presenting: pendingDelete) { b in
            Button("삭제", role: .destructive) { Task { await vm.removeBooking(id: b.id) } }
        }
        .confirmationDialog("이 일정을 삭제할까요?", isPresented: moveDeleteBinding, titleVisibility: .visible, presenting: pendingMoveDelete) { m in
            Button("삭제", role: .destructive) { Task { await vm.removeMove(id: m.id) } }
        }
    }

    // MARK: - 가는 날(시안: 머리 16 + 「이동 시간은 ○○ 기준」 12 · 「이 길을 구글지도에서 열기」 회색 테두리 버튼)

    @ViewBuilder
    private func dayOneHeader(_ plan: Itinerary.Bookings) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("가는 날" + (vm.days.first.map { ", \(TripDateText.day($0, calendar: cal))" } ?? ""))
                    .travelFont(16, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                Spacer(minLength: 8)
                if let source = plan.sourceLabel {
                    Text("이동 시간은 \(source)")
                        .travelFont(12)
                        .foregroundStyle(TravelStyle.sub)
                }
            }
            if let url = dayOneRoute(plan.dayOne) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text("이 길을 구글지도에서 열기")
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(TravelOutlineButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .travelRow(top: 14, bottom: 4)
    }

    /// 첫 정류장 → 마지막 정류장 길(구글지도 앱으로 연다).
    private func dayOneRoute(_ stops: [Itinerary.Stop]) -> URL? {
        guard stops.count >= 2, let from = place(stops.first), let to = place(stops.last) else { return nil }
        return GoogleMapsLink.directions(from: from, to: to)
    }

    private func place(_ stop: Itinerary.Stop?) -> String? {
        guard let stop else { return nil }
        switch stop.kind {
        case .flight: return stop.booking.toAirport.map { TripRoutePlace.query(for: $0, trip: vm.trip) ?? $0 }
        case .carPickup: return stop.booking.pickupPlace
        case .hotel: return stop.booking.address ?? stop.booking.name
        case .carReturn, .carRental: return nil
        }
    }

    /// 가는 날 한 정류장(시안: 시각 44 · 번호 22 검은 동그라미 · 내용 15/13).
    private func stopRow(_ stop: Itinerary.Stop, number: Int, isLast: Bool) -> some View {
        let b = stop.booking
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(stop.clock)
                    .travelFont(14, .bold)
                    .foregroundStyle(stop.isOpen ? TravelStyle.amber : TravelStyle.ink)
                    .monospacedDigit()
                if let note = stop.clockNote {
                    Text(note)
                        .travelFont(11)
                        .foregroundStyle(TravelStyle.sub)
                }
            }
            .padding(.top, 9)
            .frame(width: 44, alignment: .leading)
            ZStack(alignment: .top) {
                TravelStyle.cardBorder
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .opacity(isLast ? 0 : 1)
                Text("\(number)")
                    .travelFont(12, .bold)
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(TravelStyle.ink))
                    .padding(.top, 8)
            }
            .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                editable(b) {
                    title(stop.title)
                    ForEach(stop.details, id: \.self) { line($0) }
                }
                switch stop.kind {
                case .flight:
                    TripFlightLiveLine(state: vm.flightState(for: b), isIncheon: vm.isIncheonFlight(b), calendar: cal)
                case .carPickup:
                    mapLink(b.pickupPlace, label: "렌터카 영업소")
                case .hotel:
                    mapLink(b.address ?? b.name, label: b.name ?? "숙소")
                case .carReturn, .carRental:
                    EmptyView()
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .onTapGesture { onEdit(b) }
        .travelRow()
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { pendingDelete = b } label: { Label("삭제", systemImage: "trash") }
        }
    }

    /// 사이 이동 글자 · 밤잠과 맞닿으면 상자(시안 Trip-Bookings).
    private func legText(_ leg: Itinerary.Line, caution: Itinerary.Caution?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(leg.title)
                    .foregroundStyle(TravelStyle.body)
                if let detail = leg.detail {
                    Text(detail)
                        .foregroundStyle(TravelStyle.sub)
                }
            }
            .travelFont(13)
            .monospacedDigit()
            .padding(.top, 4)
            if let caution {
                VStack(alignment: .leading, spacing: 4) {
                    Text(caution.title)
                        .travelFont(13, .semibold)
                        .foregroundStyle(TravelStyle.red)
                    Text(caution.timing)
                        .travelFont(13)
                        .travelLineHeight(1.5, size: 13)
                        .foregroundStyle(TravelStyle.body)
                        .monospacedDigit()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(TravelStyle.redSoft))
            }
        }
    }

    /// 정류장 사이(시안: 점선 · 13 #333D4B).
    private func connector<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Color.clear.frame(width: 44, height: 1)
            TravelDashedRail()
                .stroke(TravelStyle.checkBorder, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                .frame(width: 22)
                .frame(maxHeight: .infinity)
            content()
                .padding(.top, 0)
                .padding(.bottom, 8)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .travelRow()
    }

    // MARK: - 다른 날 예약(시안: 위 1px 선 · 아이콘 22 · 제목 15 · 회색 13)

    private func otherRow(_ stop: Itinerary.Stop) -> some View {
        let b = stop.booking
        return HStack(alignment: .top, spacing: 12) {
            icon(otherIcon(stop.kind))
            VStack(alignment: .leading, spacing: 2) {
                editable(b) {
                    title(stop.title)
                    ForEach(stop.details, id: \.self) { line($0) }
                }
                if stop.kind == .flight {
                    TripFlightLiveLine(state: vm.flightState(for: b), isIncheon: vm.isIncheonFlight(b), calendar: cal)
                }
                if stop.kind == .hotel {
                    mapLink(b.address ?? b.name, label: b.name ?? "숙소")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { TravelHairline() }
        .contentShape(Rectangle())
        .onTapGesture { onEdit(b) }
        .travelRow()
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { pendingDelete = b } label: { Label("삭제", systemImage: "trash") }
        }
    }

    private func otherIcon(_ kind: Itinerary.Stop.Kind) -> String {
        switch kind {
        case .flight: return "airplane"
        case .carReturn, .carRental, .carPickup: return "car"
        case .hotel: return "bed.double"
        }
    }

    /// 지도 링크 바로 위 글자 — 손가락 탭은 가장 가까운 눌리는 곳으로 끌려가서, 제목을 눌러도 지도가 열렸다(2026-11-06 실측).
    /// 글자 칸도 눌리는 곳으로 두어 제목을 맞힌 탭은 수정으로 간다.
    private func editable<Content: View>(_ b: TripBooking, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            content()
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit(b) }
    }

    @ViewBuilder
    private func mapLink(_ query: String?, label: String) -> some View {
        if let query, let url = GoogleMapsLink.place(query) {
            // 🩸 목록 줄 안에 Link·Button 이 있으면 그것이 줄 전체의 탭을 가져간다(.borderless 도 안 듣는다) —
            //    줄을 누르면 수정 대신 구글지도가 열렸다(2026-11-06). 그래서 버튼이 아니라 제스처로 제 자리만 받는다.
            TravelLinkLabel(text: "구글지도에서 열기")
                .contentShape(Rectangle())
                .onTapGesture { openURL(url) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(label) 구글지도에서 열기")
                .accessibilityAddTraits(.isButton)
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17))
            .foregroundStyle(TravelStyle.sub)
            .frame(width: 22, height: 22)
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .travelFont(15)
            .foregroundStyle(TravelStyle.ink)
            .frame(minHeight: 22, alignment: .leading)
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .travelFont(13)
            .foregroundStyle(TravelStyle.sub)
            .monospacedDigit()
    }

    private var bookingDeleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private var moveDeleteBinding: Binding<Bool> {
        Binding(get: { pendingMoveDelete != nil }, set: { if !$0 { pendingMoveDelete = nil } })
    }
}
