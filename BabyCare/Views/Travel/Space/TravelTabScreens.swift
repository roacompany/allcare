import SwiftUI

/// 일정 칸(시안 Day-Plan · 캔버스 Version 84) — 머리 「일정」 + 날짜 칸(1일차~) + 그날 시간표.
/// 고른 날은 여행 공간이 쥔다 — 홈 「일정 전체」가 그날로 바꾼다.
struct TravelPlanView: View {
    let vm: TripDetailViewModel
    @Binding var day: Date?
    var onShowTasks: () -> Void = {}
    @State private var entry = TripEntryState()

    var body: some View {
        VStack(spacing: 0) {
            TravelScreenHeader(title: "일정", subtitle: TripHeaderText.subtitle(vm.trip, calendar: vm.calendar))
            TravelList {
                TripStatusRows(vm: vm)
                TripScheduleSection(vm: vm, selection: $day,
                                    onAddMove: { entry.move = TripEntryDrafts.move(on: $0, vm: vm) },
                                    onEdit: edit,
                                    onShowTasks: onShowTasks)
            }
        }
        .background(TravelStyle.page)
        .tripEntrySheets(vm: vm, state: $entry)
    }

    /// 일정 줄을 누르면 그 예약·일정을 고친다.
    private func edit(_ target: Itinerary.Line.Target) {
        switch target {
        case .booking(let id): entry.booking = vm.trip.bookings.first { $0.id == id }
        case .move(let id): entry.move = vm.trip.moves.first { $0.id == id }
        }
    }
}

/// 예약 칸(시안 Trip-Bookings · 캔버스 Version 84) — 머리 「예약」 + 예약 추가 · 가는 날 시간표 · 다른 날 예약 · 일정.
struct TravelBookingsView: View {
    let vm: TripDetailViewModel
    @State private var entry = TripEntryState()

    var body: some View {
        VStack(spacing: 0) {
            TravelScreenHeader(title: "예약", subtitle: TripHeaderText.subtitle(vm.trip, calendar: vm.calendar))
            TravelList {
                TripStatusRows(vm: vm)
                TripBookingsSection(vm: vm,
                                    onEdit: { entry.booking = $0 },
                                    onEditMove: { entry.move = $0 },
                                    onAdd: { entry.booking = TripEntryDrafts.booking($0, vm: vm) },
                                    onCapture: { entry.capture = TripCaptureRequest(items: $0) })
            }
        }
        .background(TravelStyle.page)
        .tripEntrySheets(vm: vm, state: $entry)
    }
}

/// 여행이 지워졌거나 저장에 실패했을 때 — 칸마다 목록 맨 위 한 줄.
struct TripStatusRows: View {
    let vm: TripDetailViewModel

    var body: some View {
        if vm.isDeleted {
            Label("이 여행은 삭제됐어요", systemImage: "trash")
                .travelFont(14)
                .foregroundStyle(TravelStyle.sub)
                .padding(.vertical, 10)
                .travelRow()
        }
        if let message = vm.errorMessage {
            Label(message, systemImage: "exclamationmark.circle")
                .travelFont(14)
                .foregroundStyle(TravelStyle.sub)
                .padding(.vertical, 10)
                .travelRow()
        }
    }
}
