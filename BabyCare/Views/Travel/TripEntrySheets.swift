import PhotosUI
import SwiftUI

/// 예약·일정 추가·수정 시트가 열려 있는 상태 — 일정 칸 · 예약 칸이 같이 쓴다(시트 배선은 한 곳 · tripEntrySheets).
struct TripEntryState {
    /// 항공편 · 숙소 · 렌터카 추가·수정.
    var booking: TripBooking?
    /// 일정(이동) 추가·수정.
    var move: TripMove?
    /// Babycare AI로 추가 — 고른 예약 확인 이미지.
    var capture: TripCaptureRequest?
}

struct TripCaptureRequest: Identifiable {
    let id = UUID()
    let items: [PhotosPickerItem]
}

/// 새로 넣을 때의 처음 값.
enum TripEntryDrafts {
    /// 새 예약 — 항공사·시각은 비워 두고 날짜만 여행 첫날(TripBookingForm).
    @MainActor
    static func booking(_ kind: TripBooking.Kind, vm: TripDetailViewModel) -> TripBooking {
        let base = Trip.date(fromDayKey: vm.trip.startDay, calendar: vm.calendar) ?? vm.calendar.startOfDay(for: vm.today)
        return TripBookingForm.newBooking(kind, tripStart: base, calendar: vm.calendar)
    }

    /// 새 일정 — 그날 가장 늦게 끝나는 일 뒤(도착·렌터카 인수·이전 일정). 앞 일이 없으면 시각은 사람이 넣는다.
    @MainActor
    static func move(on day: Date, vm: TripDetailViewModel) -> TripMove {
        let base = vm.calendar.startOfDay(for: day)
        // 앞 일이 없는 날은 넣는 창이 「입력」으로 시작한다 — 이 값은 시각 고르기의 시작점일 뿐 저장되지 않는다.
        let start = vm.moveStart(on: base) ?? vm.calendar.date(bySettingHour: 12, minute: 0, second: 0, of: base) ?? base
        return TripMove(id: UUID().uuidString, startAt: start, minutes: 60, fromLabel: "", toLabel: "")
    }
}

private struct TripEntrySheetsModifier: ViewModifier {
    let vm: TripDetailViewModel
    @Binding var state: TripEntryState

    func body(content: Content) -> some View {
        content
            .sheet(item: $state.capture) { request in
                TripCaptureSheet(vm: vm, picks: request.items)
            }
            .sheet(item: $state.booking) { booking in
                // 항공편은 편명 + 날짜만(시간표로 채움) · 숙소·렌터카는 고르기(설계 §8).
                if booking.kind == .flight {
                    TripFlightEntrySheet(booking: booking, vm: vm) { saved in
                        Task { await vm.upsertBooking(saved) }
                    }
                } else {
                    TripBookingEditSheet(booking: booking, vm: vm) { saved in
                        Task { await vm.upsertBooking(saved) }
                    }
                }
            }
            .sheet(item: $state.move) { move in
                TripMoveEditSheet(move: move, vm: vm) { saved in
                    Task { await vm.upsertMove(saved) }
                }
            }
    }
}

extension View {
    /// 예약·일정 추가·수정 · Babycare AI로 추가 시트.
    func tripEntrySheets(vm: TripDetailViewModel, state: Binding<TripEntryState>) -> some View {
        modifier(TripEntrySheetsModifier(vm: vm, state: state))
    }
}
