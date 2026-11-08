import SwiftUI

// MARK: - 추가 시트 부품 — 캔버스 시안 Entry-* 그대로(흰 바탕 · 굵은 회색 라벨 14 · 회색 입력칸 52 · 8px 띠 · 줄바꿈 칩 36 · 아래 고정 버튼 52)

/// 추가·수정 시트 틀 — 위 「취소」 + 가운데 제목 · 흰 바탕으로 굴러가는 칸들 · 아래 고정 버튼(시안 Entry-*).
struct TripEntryScaffold<Content: View>: View {
    let title: String
    let actionTitle: String
    let canSubmit: Bool
    var problem: String?
    let onSubmit: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(TravelStyle.page)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if let problem {
                        Text(problem)
                            .travelFont(13)
                            .foregroundStyle(TravelStyle.sub)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(actionTitle, action: onSubmit)
                        .buttonStyle(TripEntryPrimaryButtonStyle())
                        .disabled(!canSubmit)
                }
                .padding(.horizontal, TravelStyle.gutter)
                .padding(.vertical, 12)
                .background(TravelStyle.page.overlay(alignment: .top) { TravelHairline() })
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TravelStyle.page, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}

/// 아래 고정 버튼 — 높이 52 · 모서리 6 · primary 바탕 흰 글자 16 굵게(시안 「추가」).
struct TripEntryPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .travelFont(16, .semibold)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 6).fill(TravelStyle.primary))
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.35)
    }
}

/// 칸 하나 — 라벨(14 굵게 #333D4B) + 내용 · 좌우 16 · 위아래 16.
struct TripEntrySection<Content: View>: View {
    var title: String?
    var top: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .travelFont(14, .semibold)
                    .foregroundStyle(TravelStyle.body)
            }
            content()
        }
        .padding(.horizontal, TravelStyle.gutter)
        .padding(.top, top)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 칸 나눔 — 8px 회색 띠(시트 폭 끝까지).
struct TripEntryBand: View {
    var body: some View {
        TravelStyle.band.frame(maxWidth: .infinity).frame(height: TravelStyle.bandHeight)
    }
}

extension View {
    /// 회색 입력칸 — 높이 52 · 모서리 8 · #F2F4F6 · 글자 16(편명은 20 굵게).
    func tripEntryField(big: Bool = false) -> some View {
        travelFont(big ? 20 : 16, big ? .bold : .regular)
            .foregroundStyle(TravelStyle.ink)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(TravelStyle.chip))
    }
}

/// 줄바꿈 놓기 — 칩이 넘치면 다음 줄로(시안 flex-wrap · 사이 8).
struct TravelWrapLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = proposal.width ?? (rows.map(\.width).max() ?? 0)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = fitted(subviews[index], width: bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// 한 줄보다 긴 칩은 줄 폭까지만 — 글자가 말줄임으로 줄어든다(찾아서 고른 긴 이름이 화면 밖으로 나가지 않게).
    private func fitted(_ subview: LayoutSubview, width: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        return ideal.width > width ? subview.sizeThatFits(ProposedViewSize(width: width, height: nil)) : ideal
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = fitted(subviews[index], width: width)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(indices: [], y: current.y + current.height + lineSpacing, width: 0, height: 0)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// 고르기 칩 하나 — 높이 36 · 둥근 18 · 좌우 14 · 14(고른 칩 = #191F2B 바탕 흰 글자 굵게 · 나머지 = #F2F4F6 바탕 #333D4B).
struct TripChoiceChip: View {
    let title: String
    /// 앞 아이콘(시안 「다른 곳 찾기」 돋보기 — 왼쪽 여백 11 · 사이 4).
    var systemImage: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .medium))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .travelFont(14, selected ? .semibold : .regular)
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .foregroundStyle(selected ? Color.white : TravelStyle.body)
            .padding(.leading, systemImage == nil ? 14 : 11)
            .padding(.trailing, 14)
            .frame(minHeight: 36)
            .background(Capsule().fill(selected ? TravelStyle.ink : TravelStyle.chip))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// 「+」 추가 버튼 — 파란 테두리 · 둥근 6 · 파란 글씨(시안 「완료로 표시」와 같은 모양 · PO 2026-11-06 「다시 그려」).
/// 예약 칸은 같은 폭 세 칸(wide · 높이 44 · 15), 일정 칸은 작게(높이 36 · 14).
struct TravelAddChip: View {
    let title: String
    var wide = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: wide ? 14 : 13, weight: .bold))
                Text(title)
                    .travelFont(wide ? 15 : 14, .semibold)
            }
            .foregroundStyle(TravelStyle.primary)
            .padding(.horizontal, wide ? 8 : 12)
            .frame(maxWidth: wide ? .infinity : nil, minHeight: wide ? 44 : 36)
            .background(RoundedRectangle(cornerRadius: 6).fill(TravelStyle.page))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(TravelStyle.primary, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title.hasSuffix("추가") ? title : "\(title) 추가")
    }
}

/// 날짜 고르기 — 여행 날짜 칩(줄바꿈) + 「다른 날」(달력). 시각은 그대로 두고 날짜만 바꾼다.
struct TripDayChips: View {
    let days: [Date]
    @Binding var selection: Date
    let calendar: Calendar

    @State private var showCalendar = false

    private var isOtherDay: Bool { !days.contains { calendar.isDate($0, inSameDayAs: selection) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TravelWrapLayout {
                ForEach(days, id: \.self) { day in
                    TripChoiceChip(title: TripDateText.day(day, calendar: calendar),
                                   selected: !showCalendar && calendar.isDate(day, inSameDayAs: selection)) {
                        selection = TripEntryChoices.combine(day: day, time: selection, calendar: calendar)
                        showCalendar = false
                    }
                }
                TripChoiceChip(title: "다른 날", selected: showCalendar || isOtherDay) {
                    showCalendar = true
                }
            }
            if showCalendar || isOtherDay {
                DatePicker("날짜", selection: $selection, displayedComponents: .date)
                    .environment(\.calendar, calendar)
                    .travelFont(15)
            }
        }
    }
}

/// 비워 둘 수 있는 시각 — 비었으면 「입력」, 넣었으면 시각 + 「비우기」(시안 항공편 상대 공항 도착).
/// 🩸 시각 고르기를 칸에 바로 두면 처음 값이 고른 값으로 저장된다(빌드 113 의 14:00 · 00:00) — 창에서 「확인」을 눌러야 들어간다.
struct TripOptionalTimeRow: View {
    let title: String
    @Binding var hasValue: Bool
    @Binding var value: Date
    let calendar: Calendar
    /// 시각 고르기가 처음 보이는 시.
    var startHour = 12

    @State private var picking = false

    private var start: Date {
        hasValue ? value : (calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: value) ?? value)
    }

    private var text: String {
        hasValue ? TripDateText.time(value, calendar: calendar) : "입력"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(title)
                .travelFont(15)
                .foregroundStyle(TravelStyle.ink)
            Spacer(minLength: 8)
            Button { picking = true } label: {
                Text(text)
                    .travelFont(16, .semibold)
                    .foregroundStyle(hasValue ? TravelStyle.ink : TravelStyle.sub)
                    .monospacedDigit()
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(TravelStyle.chip))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) \(text)")
            .accessibilityIdentifier("time.\(title).input")
            if hasValue {
                Button("비우기") { hasValue = false }
                    .travelFont(13)
                    .foregroundStyle(TravelStyle.sub)
                    .buttonStyle(.plain)
            }
        }
        .frame(minHeight: 48)
        .sheet(isPresented: $picking) {
            TripTimePickerSheet(title: title, start: start, calendar: calendar) { picked in
                hasValue = true
                value = picked
            }
            .presentationDetents([.height(320)])
        }
    }
}

/// 시각 고르기 창 — 취소하면 아무것도 안 바뀐다.
private struct TripTimePickerSheet: View {
    let title: String
    let calendar: Calendar
    let onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var picked: Date

    init(title: String, start: Date, calendar: Calendar, onPick: @escaping (Date) -> Void) {
        self.title = title
        self.calendar = calendar
        self.onPick = onPick
        _picked = State(initialValue: start)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("취소") { dismiss() }
                    .travelFont(16)
                    .foregroundStyle(TravelStyle.ink)
                Spacer(minLength: 8)
                Text(title)
                    .travelFont(16, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                Spacer(minLength: 8)
                Button("확인") {
                    onPick(picked)
                    dismiss()
                }
                .travelFont(16, .semibold)
                .foregroundStyle(TravelStyle.primary)
                .accessibilityIdentifier("time.confirm")
            }
            .padding(.horizontal, TravelStyle.gutter)
            .frame(height: 52)
            DatePicker(title, selection: $picked, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.calendar, calendar)
            Spacer(minLength: 0)
        }
        .background(TravelStyle.page)
    }
}

/// 일시의 시각 칸 — 비워 두면 날짜만 저장한다(ADR-0001).
struct TripWhenTimeRow: View {
    let title: String
    @Binding var value: TripWhen?
    /// 일시가 아직 없을 때의 날.
    let day: Date
    let calendar: Calendar

    private var currentDay: Date { value?.startOfDay(calendar) ?? day }

    private var hasTime: Binding<Bool> {
        Binding(get: { value?.time != nil }, set: { on in
            // 켤 때는 뒤따르는 시각이 값을 넣는다 — 여기서 시각을 지어 넣지 않는다.
            if !on { value = .day(Trip.dayKey(currentDay, calendar: calendar)) }
        })
    }

    private var time: Binding<Date> {
        Binding(get: { value?.time ?? currentDay },
                set: { value = .at(TripEntryChoices.combine(day: currentDay, time: $0, calendar: calendar)) })
    }

    var body: some View {
        TripOptionalTimeRow(title: title, hasValue: hasTime, value: time, calendar: calendar)
    }
}

/// 일시 한 칸 — 날짜 칩 + 비워 둘 수 있는 시각.
struct TripWhenField: View {
    let timeTitle: String
    let days: [Date]
    @Binding var value: TripWhen?
    let calendar: Calendar

    private var firstDay: Date { days.first ?? calendar.startOfDay(for: Date()) }

    private var pickedDay: Binding<Date> {
        Binding(get: { value?.startOfDay(calendar) ?? firstDay },
                set: { value = value?.movedTo($0, calendar: calendar) ?? .day(Trip.dayKey($0, calendar: calendar)) })
    }

    var body: some View {
        TripDayChips(days: days, selection: pickedDay, calendar: calendar)
        TripWhenTimeRow(title: timeTitle, value: $value, day: firstDay, calendar: calendar)
    }
}

/// 하루 중 몇 분째로 저장하는 시각 — 체크인 마감(시안 Entry-Hotel).
struct TripMinuteRow: View {
    let title: String
    @Binding var minute: Int?
    let calendar: Calendar

    private static let pickerStartMinute = 22 * 60

    private var base: Date { calendar.startOfDay(for: Date()) }

    private var hasValue: Binding<Bool> {
        Binding(get: { minute != nil }, set: { minute = $0 ? Self.pickerStartMinute : nil })
    }

    private var value: Binding<Date> {
        Binding(get: { calendar.date(byAdding: .minute, value: minute ?? Self.pickerStartMinute, to: base) ?? base },
                set: { picked in
                    let c = calendar.dateComponents([.hour, .minute], from: picked)
                    minute = (c.hour ?? 0) * 60 + (c.minute ?? 0)
                })
    }

    var body: some View {
        TripOptionalTimeRow(title: title, hasValue: hasValue, value: value, calendar: calendar, startHour: Self.pickerStartMinute / 60)
    }
}

/// 무료 취소 — 없음 · 1·2·3·7일 전 · 다른 날(시안 Entry-Hotel · Entry-Rental). 기준 = 체크인·인수 일시.
struct TripFreeCancelChips: View {
    let anchor: TripWhen?
    @Binding var value: TripWhen?
    let calendar: Calendar

    @State private var showOther = false
    private static let offsets = [1, 2, 3, 7]

    /// 기준이 날짜만이면 기한도 날짜만이다.
    private func day(_ n: Int) -> TripWhen? {
        anchor?.daysBefore(n, calendar: calendar)
    }

    private var matchedOffset: Int? {
        guard let value else { return nil }
        return Self.offsets.first { n in day(n) == value }
    }

    private var today: Date { calendar.startOfDay(for: Date()) }

    private var pickedDay: Binding<Date> {
        Binding(get: { value?.startOfDay(calendar) ?? today },
                set: { value = value?.movedTo($0, calendar: calendar) ?? .day(Trip.dayKey($0, calendar: calendar)) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TravelWrapLayout {
                TripChoiceChip(title: "없음", selected: value == nil && !showOther) {
                    value = nil
                    showOther = false
                }
                if anchor != nil {
                    ForEach(Self.offsets, id: \.self) { n in
                        TripChoiceChip(title: "\(n)일 전", selected: !showOther && matchedOffset == n) {
                            value = day(n)
                            showOther = false
                        }
                    }
                }
                TripChoiceChip(title: "다른 날", selected: showOther || (value != nil && matchedOffset == nil)) {
                    showOther = true
                    if value == nil { value = day(1) ?? .day(Trip.dayKey(today, calendar: calendar)) }
                }
            }
            if showOther || (value != nil && matchedOffset == nil) {
                DatePicker("무료 취소", selection: pickedDay, displayedComponents: .date)
                    .environment(\.calendar, calendar)
                    .travelFont(15)
                TripWhenTimeRow(title: "기한 시각", value: $value, day: today, calendar: calendar)
            }
        }
    }
}

/// 장소 고르기(시안 Entry-Move · Entry-Rental · Entry-Hotel) — 그 여행에 이미 있는 곳은 칩, 다른 곳은 찾기 화면.
/// 고를 칩이 없으면(숙소) 회색 칸 하나 — 눌러서 찾기 화면을 연다. 넣는 창에는 글자 칸을 두지 않는다(자판에 후보가 가린다).
struct TripPlaceField: View {
    /// 칸 이름 — 찾기 화면 제목 · 「○○ 검색」.
    let title: String
    @Binding var text: String
    let choices: [String]
    var showsAirports = true
    let search: PlaceSearchModel
    /// 찾은 곳을 골랐을 때(숙소는 이름·주소를 같이 채운다). nil 이면 이름만 넣는다.
    var onPick: ((PlaceSearchModel.Pick) -> Void)?

    @State private var searching = false

    private var picked: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Group {
            if choices.isEmpty {
                searchBox
            } else {
                TravelWrapLayout {
                    ForEach(TripEntryChoices.chips(choices: choices, value: text), id: \.self) { place in
                        TripChoiceChip(title: place, selected: picked == place) {
                            text = TripEntryChoices.tapping(place, value: text)
                        }
                    }
                    TripChoiceChip(title: "다른 곳 찾기", systemImage: "magnifyingglass", selected: false) { searching = true }
                }
            }
        }
        .sheet(isPresented: $searching) {
            TripPlaceSearchSheet(title: title, initialText: choices.isEmpty ? picked : "", showsAirports: showsAirports,
                                 needsAddress: onPick != nil, search: search) { pick in
                if let onPick { onPick(pick) } else { text = pick.name }
            }
        }
    }

    private var searchBox: some View {
        Button {
            searching = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(TravelStyle.sub)
                    .accessibilityHidden(true)
                Text(picked.isEmpty ? "\(title) 검색" : picked)
                    .travelFont(16)
                    .foregroundStyle(picked.isEmpty ? TravelStyle.faint : TravelStyle.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(TravelStyle.chip))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
