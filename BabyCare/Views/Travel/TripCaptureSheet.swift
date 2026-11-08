import PhotosUI
import SwiftUI

/// Babycare AI로 추가 — 고른 예약 확인 이미지를 폰 안에서 읽어 찾은 예약을 보여 주고, 고른 것만 추가한다(시안 Entry-Capture · PO 2026-11-05 손수 고친 판).
/// 화면 낱말 = PO 판 그대로: 제목 「by Babycare AI」 · 「이미지에서 예약 N건을 찾았어요」 · 설명 줄 없음.
struct TripCaptureSheet: View {
    let vm: TripDetailViewModel
    let picks: [PhotosPickerItem]

    @Environment(\.dismiss) private var dismiss
    @State private var outcome: CaptureOutcome?
    @State private var items: [CapturedBooking] = []
    @State private var editing: CapturedBooking?
    @State private var adding = false

    private var cal: Calendar { vm.calendar }
    private var selectedCount: Int { items.filter { $0.selected && canAdd($0) }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(TravelStyle.page)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !items.isEmpty {
                    Button("\(selectedCount)건 추가") {
                        Task { await add() }
                    }
                    .buttonStyle(TripEntryPrimaryButtonStyle())
                    .disabled(selectedCount == 0 || adding)
                    .padding(.horizontal, TravelStyle.gutter)
                    .padding(.vertical, 12)
                    .background(TravelStyle.page.overlay(alignment: .top) { TravelHairline() })
                }
            }
            .navigationTitle("by Babycare AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TravelStyle.page, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .task { await read() }
            .sheet(item: $editing) { item in
                editSheet(item)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let outcome {
            if items.isEmpty {
                TripEntrySection {
                    Text(outcome.failed ? "이미지를 읽지 못했어요" : "예약 정보를 찾지 못했어요. 항공편·숙소·렌터카 추가로 직접 입력해 주세요.")
                        .travelFont(15)
                        .travelLineHeight(1.5, size: 15)
                        .foregroundStyle(TravelStyle.body)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("이미지에서 예약 \(items.count)건을 찾았어요")
                        .travelFont(18, .bold, tracking: -0.02)
                        .foregroundStyle(TravelStyle.ink)
                    if outcome.reader == .rulesFlightsOnly {
                        Text("이 기기에서는 항공편만 읽어요")
                            .travelFont(13)
                            .foregroundStyle(TravelStyle.sub)
                    }
                }
                .padding(.horizontal, TravelStyle.gutter)
                .padding(.vertical, 16)
                group("항공편", kind: .flight)
                group("숙소", kind: .hotel)
                group("렌터카", kind: .rentalCar)
            }
        } else {
            HStack(spacing: 10) {
                ProgressView()
                Text("이미지 \(picks.count)장을 읽는 중")
                    .travelFont(15)
                    .foregroundStyle(TravelStyle.body)
            }
            .padding(.horizontal, TravelStyle.gutter)
            .padding(.vertical, 20)
        }
    }

    @ViewBuilder
    private func group(_ title: String, kind: TripBooking.Kind) -> some View {
        let rows = items.filter { $0.booking.kind == kind }
        if !rows.isEmpty {
            TripEntryBand()
            VStack(alignment: .leading, spacing: 0) {
                Text("\(title) \(rows.count)")
                    .travelFont(16, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                    .padding(.bottom, 4)
                ForEach(rows) { item in
                    TravelHairline()
                    row(item)
                }
            }
            .padding(.horizontal, TravelStyle.gutter)
            .padding(.top, 14)
            .padding(.bottom, 4)
        }
    }

    private func row(_ item: CapturedBooking) -> some View {
        let problem = TripBookingForm.problem(item.booking, calendar: vm.calendar)
        let checked = item.selected && problem == nil
        return HStack(alignment: .top, spacing: 12) {
            Button {
                toggle(item)
            } label: {
                TravelCheckCircle(isOn: checked)
                    .padding(.top, 1)
            }
            .buttonStyle(.plain)
            .disabled(problem != nil)
            .accessibilityLabel(checked ? "추가 안 함" : "추가")
            VStack(alignment: .leading, spacing: 3) {
                Text(CaptureBookingText.title(item.booking))
                    .travelFont(15, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                let detail = CaptureBookingText.detail(item.booking, calendar: cal)
                if !detail.isEmpty {
                    Text(detail)
                        .travelFont(13)
                        .travelLineHeight(1.5, size: 13)
                        .foregroundStyle(TravelStyle.body)
                        .monospacedDigit()
                }
                if !item.needs.isEmpty {
                    Text(CaptureBookingText.needs(item.needs))
                        .travelFont(13, .semibold)
                        .foregroundStyle(TravelStyle.red)
                }
                if item.isDuplicate {
                    Text("이미 있음")
                        .travelFont(13)
                        .foregroundStyle(TravelStyle.sub)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("수정") { editing = item }
                .travelFont(13)
                .foregroundStyle(TravelStyle.sub)
                .frame(minHeight: 32)
                .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func editSheet(_ item: CapturedBooking) -> some View {
        if item.booking.kind == .flight {
            TripFlightEntrySheet(booking: item.booking, vm: vm, isNew: false) { saved in replace(item, with: saved) }
        } else {
            TripBookingEditSheet(booking: item.booking, vm: vm, isNew: false) { saved in replace(item, with: saved) }
        }
    }

    private func canAdd(_ item: CapturedBooking) -> Bool {
        TripBookingForm.problem(item.booking, calendar: vm.calendar) == nil
    }

    private func toggle(_ item: CapturedBooking) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].selected.toggle()
    }

    /// 수정에서 고친 뒤 — 확인 필요를 다시 재고, 추가할 것으로 켠다.
    private func replace(_ item: CapturedBooking, with booking: TripBooking) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i] = CaptureBookingBuilder.edited(items[i], booking: booking, calendar: cal)
        items[i].selected = true
    }

    private func read() async {
        guard outcome == nil else { return }
        var images: [Data] = []
        for pick in picks {
            do {
                if let data = try await pick.loadTransferable(type: Data.self) { images.append(data) }
            } catch {
                logSilent("예약 이미지를 못 가져옴", error: error, logger: AppLogger.travel)
            }
        }
        let result = await vm.readCaptures(images)
        items = result.items
        outcome = result
    }

    private func add() async {
        adding = true
        await vm.addCaptured(items.filter(canAdd))
        adding = false
        dismiss()
    }
}

/// Babycare AI로 추가 버튼(시안 Trip-Bookings 「예약 추가」 · PO 판 문구) — 회색 상자 · 흰 사진 칸 · 제목 15 굵게 · 부제 13.
struct TripCaptureButtonLabel: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(TravelStyle.ink)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(TravelStyle.page))
            VStack(alignment: .leading, spacing: 2) {
                Text("Babycare AI로 추가")
                    .travelFont(15, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                Text("예약확인 이미지를 읽고 정리합니다")
                    .travelFont(13)
                    .foregroundStyle(TravelStyle.sub)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TravelStyle.sub)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(TravelStyle.chip))
        .contentShape(Rectangle())
    }
}
