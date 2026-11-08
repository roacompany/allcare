import SwiftUI

/// 여행 만들기 · 수정 — 여행 일정 앱처럼(PO 2026-11-06 「여행일정 앱처럼... 제발....」 · 캔버스 시안 Trip-Edit).
/// 여행지 = 도시 칩(✕ 로 빼기 · 「+ 도시 추가」) · 여행 기간 = 달력에서 시작·끝 누르기 · 아래 고정 버튼(만들기 / 저장).
/// 저장 모양은 그대로 — city 는 「·」로 이은 글자(예: 「오사카·교토」) · startDay/endDay.
struct TripCreateSheet: View {
    let onCreate: (_ city: String, _ startDay: String, _ endDay: String) -> Void
    private let isEditing: Bool
    /// 수정일 때만 — 내용 끝 빨간 「여행 삭제」(확인 뒤).
    private let onDelete: (() -> Void)?
    private let calendar: Calendar

    @Environment(\.dismiss) private var dismiss
    @State private var cities: [String]
    @State private var selection: TripDateRangeSelection
    @State private var month: Date
    @State private var addingCity = false
    @State private var cityDraft = ""
    @State private var confirmDelete = false
    @FocusState private var cityFocused: Bool

    /// 새 여행 — 여행지·기간은 비워 두고 이번 달 달력부터.
    init(calendar: Calendar = .current, onCreate: @escaping (_ city: String, _ startDay: String, _ endDay: String) -> Void) {
        self.onCreate = onCreate
        self.isEditing = false
        self.onDelete = nil
        self.calendar = calendar
        _cities = State(initialValue: [])
        _selection = State(initialValue: TripDateRangeSelection())
        _month = State(initialValue: TripMonthGrid.monthStart(Date(), calendar: calendar))
    }

    /// 있는 여행 수정(예약·체크는 그대로).
    init(editing trip: Trip, calendar: Calendar = .current, onDelete: (() -> Void)? = nil,
         onSave: @escaping (_ city: String, _ startDay: String, _ endDay: String) -> Void) {
        self.onCreate = onSave
        self.isEditing = true
        self.onDelete = onDelete
        self.calendar = calendar
        let start = Trip.date(fromDayKey: trip.startDay, calendar: calendar)
        let end = Trip.date(fromDayKey: trip.endDay, calendar: calendar)
        _cities = State(initialValue: TripCityList.split(trip.city))
        _selection = State(initialValue: TripDateRangeSelection(start: start, end: end))
        _month = State(initialValue: TripMonthGrid.monthStart(start ?? Date(), calendar: calendar))
    }

    /// 입력칸에 적고 아직 안 넣은 도시도 같이 친다(바로 「저장」을 눌러도 빠지지 않게).
    private var finalCities: [String] { TripCityList.adding(cityDraft, to: cities) }

    var body: some View {
        TripEntryScaffold(title: isEditing ? "여행 수정" : "여행 만들기", actionTitle: isEditing ? "저장" : "만들기",
                          canSubmit: TripEditForm.canSave(cities: finalCities, selection: selection), onSubmit: submit) {
            destinations
            TripEntryBand()
            period
            if isEditing, onDelete != nil {
                Button {
                    confirmDelete = true
                } label: {
                    Text("여행 삭제")
                        .travelFont(14)
                        .foregroundStyle(TravelStyle.red)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .confirmationDialog("이 여행을 삭제할까요?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("여행 삭제", role: .destructive) {
                dismiss()
                onDelete?()
            }
        } message: {
            Text("예약과 체크한 할 일도 함께 삭제돼요. 되돌릴 수 없어요.")
        }
    }

    // MARK: - 여행지

    private var destinations: some View {
        TripEntrySection(title: "여행지") {
            TravelWrapLayout {
                ForEach(cities, id: \.self) { name in
                    TripCityChip(name: name) { cities.removeAll { $0 == name } }
                }
                TravelAddChip(title: "도시 추가") {
                    addingCity = true
                    cityFocused = true
                }
            }
            if addingCity {
                TextField("도시 이름", text: $cityDraft)
                    .focused($cityFocused)
                    .submitLabel(.done)
                    .onSubmit(addDraft)
                    .tripEntryField()
                let suggestions = TripCityList.suggestions(excluding: cities)
                if !suggestions.isEmpty {
                    TravelWrapLayout {
                        ForEach(suggestions, id: \.self) { name in
                            TripChoiceChip(title: name, selected: false) {
                                cities = TripCityList.adding(name, to: cities)
                            }
                        }
                    }
                }
            }
        }
    }

    private func addDraft() {
        cities = TripCityList.adding(cityDraft, to: cities)
        cityDraft = ""
    }

    // MARK: - 여행 기간

    private var period: some View {
        TripEntrySection(title: "여행 기간") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                spanText
                    .travelFont(20, .bold, tracking: -0.02)
                    .monospacedDigit()
                if let start = selection.start, let end = selection.end {
                    Text(TripDateRangeText.nightsDays(start: start, end: end, calendar: calendar))
                        .travelFont(15)
                        .foregroundStyle(TravelStyle.sub)
                }
            }
            TripRangeCalendar(month: $month, selection: $selection, calendar: calendar)
        }
    }

    /// 「5.10(월) – 5.14(금)」 · 끝만 비면 「5.10(월) – 귀국일」 · 다 비면 「출발일 – 귀국일」(빈 자리는 흐린 글자).
    private var spanText: Text {
        switch (selection.start, selection.end) {
        case let (start?, end?):
            return Text(TripDateRangeText.span(start: start, end: end, calendar: calendar)).foregroundStyle(TravelStyle.ink)
        case let (start?, nil):
            return Text("\(TripDateText.day(start, calendar: calendar)) – ").foregroundStyle(TravelStyle.ink)
                + Text("귀국일").foregroundStyle(TravelStyle.faint)
        default:
            return Text("출발일 – 귀국일").foregroundStyle(TravelStyle.faint)
        }
    }

    private func submit() {
        guard let start = selection.start, let end = selection.end else { return }
        onCreate(TripCityList.join(finalCities), Trip.dayKey(start, calendar: calendar), Trip.dayKey(max(end, start), calendar: calendar))
        dismiss()
    }
}

/// 도시 칩 — 회색 36 · 둥근 18 · 15 굵게 · ✕ 로 빼기(시안 Trip-Edit 여행지).
struct TripCityChip: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .travelFont(15, .semibold)
                .foregroundStyle(TravelStyle.ink)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TravelStyle.faint)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name) 빼기")
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(minHeight: 36)
        .background(Capsule().fill(TravelStyle.chip))
    }
}

/// 여행 기간 달력 — 일요일 시작 · 요일 일~토(일요일 빨강) · ‹ 2026년 11월 › · 칸 44 ·
/// 시작·끝 = primary 동그라미 흰 글씨 · 사이 = 연한 파랑 띠(시안 Trip-Edit).
struct TripRangeCalendar: View {
    @Binding var month: Date
    @Binding var selection: TripDateRangeSelection
    let calendar: Calendar

    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    private var weeks: [[Date?]] {
        let cells = TripMonthGrid.cells(month: month, calendar: calendar)
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                monthButton(-1, systemImage: "chevron.left", label: "이전 달")
                Spacer()
                Text(TripMonthGrid.title(month, calendar: calendar))
                    .travelFont(16, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                    .monospacedDigit()
                Spacer()
                monthButton(1, systemImage: "chevron.right", label: "다음 달")
            }
            .frame(height: 40)
            // 지연 그리기(LazyVGrid) 금지 — 달력이 화면 밖으로 밀리면 높이를 짐작해 위 칸으로 올라탄다(2026-11-06 실측).
            Grid(horizontalSpacing: 0, verticalSpacing: 4) {
                GridRow {
                    ForEach(Array(weekdays.enumerated()), id: \.offset) { index, name in
                        Text(name)
                            .travelFont(12)
                            .foregroundStyle(index == 0 ? TravelStyle.red : TravelStyle.sub)
                            .frame(maxWidth: .infinity, minHeight: 20)
                    }
                }
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    GridRow {
                        ForEach(Array(week.enumerated()), id: \.offset) { column, day in
                            if let day {
                                dayCell(day, column: column)
                            } else {
                                Color.clear.frame(height: 44)
                            }
                        }
                    }
                }
            }
        }
    }

    private func monthButton(_ step: Int, systemImage: String, label: String) -> some View {
        Button {
            month = TripMonthGrid.shift(month, by: step, calendar: calendar)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(TravelStyle.body)
                .frame(width: 44, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func dayCell(_ day: Date, column: Int) -> some View {
        let role = selection.role(of: day, calendar: calendar)
        let edge = role == .start || role == .end || role == .single
        return Button {
            selection.tap(day, calendar: calendar)
        } label: {
            ZStack {
                band(role)
                if edge {
                    Circle().fill(TravelStyle.primary).frame(width: 40, height: 40)
                }
                Text("\(calendar.component(.day, from: day))")
                    .travelFont(16, edge ? .bold : .regular)
                    .foregroundStyle(edge ? Color.white : (column == 0 ? TravelStyle.red : TravelStyle.ink))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TripDateText.day(day, calendar: calendar))
        .accessibilityAddTraits(edge ? [.isSelected] : [])
    }

    @ViewBuilder
    private func band(_ role: TripDateRangeSelection.Role) -> some View {
        switch role {
        case .inside:
            TravelStyle.rangeBand
        case .start:
            HStack(spacing: 0) {
                Color.clear
                TravelStyle.rangeBand
            }
        case .end:
            HStack(spacing: 0) {
                TravelStyle.rangeBand
                Color.clear
            }
        case .none, .single:
            Color.clear
        }
    }
}
