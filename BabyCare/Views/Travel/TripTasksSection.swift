import SwiftUI

/// 할 일 칸(시안 「여행: 할 일」) — 담당 거르기 알약 · 주(월요일 시작)로 묶은 목록 · D-day 와 빨강은 마감에만(마감 3일 전부터).
/// TravelList 안에서 줄 여러 개를 낸다.
struct TripTasksSection: View {
    let vm: TripDetailViewModel
    /// 여행 공간에서만 — 담당으로 거르기.
    var filter: Binding<TripAssigneeFilter>?
    @State private var openedCard: TripTask?

    var body: some View {
        let all = vm.tasks
        let tasks = filter.map { $0.wrappedValue.apply(all, states: vm.trip.taskStates) } ?? all
        if let filter, !all.isEmpty {
            TripAssigneeChips(selection: filter, counts: chipCounts(all))
                .padding(.vertical, 10)
                .travelRow()
        }
        if vm.childLoadFailed {
            Label("아기 기록을 불러오지 못해 이유식·배시넷 안내가 빠졌을 수 있어요.", systemImage: "exclamationmark.circle")
                .travelFont(13)
                .foregroundStyle(TravelStyle.sub)
                .padding(.vertical, 8)
                .travelRow()
        }
        TravelBandRow()
        if tasks.isEmpty {
            Text(all.isEmpty ? "예약 칸에서 항공편·숙소·렌터카를 추가하면 규칙에 맞는 할 일과 마감이 생겨요."
                             : "이 담당으로 정한 할 일이 없어요.")
                .travelFont(14)
                .foregroundStyle(TravelStyle.sub)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .travelRow()
        } else {
            let start = Trip.date(fromDayKey: vm.trip.startDay, calendar: vm.calendar) ?? vm.today
            let groups = TripTaskWeekGroups.build(tasks: tasks, today: vm.today, tripStart: start, calendar: vm.calendar)
            ForEach(Array(groups.enumerated()), id: \.element.range) { index, group in
                if index > 0 { TravelBandRow() }
                TravelSectionHeader(title: group.title, trailing: group.range, minHeight: 40)
                    .travelRow()
                ForEach(group.tasks) { task in
                    TripTaskRow(task: task, state: vm.state(for: task.id), now: vm.today, calendar: vm.calendar,
                                onToggle: { Task { await vm.toggleDone(task.id) } },
                                onAssign: { a in Task { await vm.setAssignee(a, for: task.id) } },
                                onOpen: { openedCard = task })
                        .travelRow()
                }
            }
            Color.clear
                .frame(height: 12)
                .travelRow()
                .sheet(item: $openedCard) { task in
                    TripRuleCardSheet(card: TripRuleCatalog.card(task.key), childNote: task.childNote)
                }
        }
    }

    /// 알약 옆 숫자 — 「전체 13」 · 「담당 없음 4」(안 끝난 일만).
    private func chipCounts(_ all: [TripTask]) -> [TripAssigneeFilter: Int] {
        let open = all.filter { vm.state(for: $0.id)?.isDone != true }
        return [.all: open.count,
                .unassigned: TripAssigneeFilter.unassigned.apply(open, states: vm.trip.taskStates).count]
    }
}

/// 할 일 한 줄(시안) — 위 1px 선 · 체크 22 · 제목 15 · 담당 칩(19) 옆에 설명·마감 줄(13) · 오른쪽 D-day 14 굵게.
struct TripTaskRow: View {
    let task: TripTask
    let state: TripTaskState?
    let now: Date
    let calendar: Calendar
    let onToggle: () -> Void
    let onAssign: (TripAssignee) -> Void
    let onOpen: () -> Void

    private var isDone: Bool { state?.isDone == true }

    /// D-day 에 쓸 마감 — 아직 안 지난 첫 마감, 다 지났으면 마지막 마감.
    private var focusDeadline: TripDeadline? {
        task.deadlines.first { TripTaskOrdering.dDay(to: $0.at, now: now, calendar: calendar) >= 0 } ?? task.deadlines.last
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                TravelCheckCircle(isOn: isDone)
                    .padding(.top, 1)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isDone ? "완료 취소" : "완료로 표시")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .travelFont(15)
                    .travelLineHeight(1.35, size: 15)
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? TravelStyle.sub : TravelStyle.ink)
                HStack(alignment: .top, spacing: 6) {
                    TravelAssigneeChipMenu(state: state, small: true, onAssign: onAssign)
                    VStack(alignment: .leading, spacing: 2) {
                        if let detail = task.detail {
                            Text(detail)
                                .foregroundStyle(TravelStyle.sub)
                        }
                        ForEach(task.deadlines, id: \.self) { d in
                            Text("\(d.label) 마감 \(d.text(calendar: calendar))")
                                .foregroundStyle(!isDone && TripTaskOrdering.isUrgent(d.at, now: now, calendar: calendar)
                                                 ? TravelStyle.red : TravelStyle.sub)
                        }
                        ForEach(task.openDeadlines, id: \.self) { leg in
                            Text("\(leg) 마감: 출발 시각을 넣으면 나와요")
                                .foregroundStyle(TravelStyle.sub)
                        }
                        if let note = task.childNote {
                            Text(note)
                                .foregroundStyle(task.childNoteIsAlert ? TravelStyle.red : TravelStyle.sub)
                        }
                    }
                    .travelFont(13)
                    .monospacedDigit()
                    .padding(.top, 1)
                }
            }
            Spacer(minLength: 8)
            if let d = focusDeadline, !isDone {
                let n = TripTaskOrdering.dDay(to: d.at, now: now, calendar: calendar)
                Text(TripDateText.dDayText(n))
                    .travelFont(14, .bold)
                    .monospacedDigit()
                    .foregroundStyle(TripTaskOrdering.isUrgent(d.at, now: now, calendar: calendar) ? TravelStyle.red : TravelStyle.ink)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { TravelHairline() }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }
}

/// 규칙 카드(시안 Rule-Card) — 위 막대 「규칙 카드」 · 제목 20 굵게 · 「우리 아이」 빨간 상자 · 띠 · 규칙 내용 표(이름 칸 84 · #F7F8FA).
struct TripRuleCardSheet: View {
    let card: TripRuleCard
    let childNote: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.title)
                            .travelFont(20, .bold, tracking: -0.02)
                            .travelLineHeight(1.4, size: 20)
                            .foregroundStyle(TravelStyle.ink)
                        Text(card.summary)
                            .travelFont(15)
                            .travelLineHeight(1.5, size: 15)
                            .foregroundStyle(TravelStyle.body)
                        if let childNote {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("우리 아이")
                                    .travelFont(14, .semibold)
                                    .foregroundStyle(TravelStyle.red)
                                Text(childNote)
                                    .travelFont(14)
                                    .travelLineHeight(1.5, size: 14)
                                    .foregroundStyle(TravelStyle.body)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(TravelStyle.redSoft))
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, TravelStyle.gutter)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    TravelStyle.band.frame(height: TravelStyle.bandHeight)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("규칙 내용")
                            .travelFont(16, .semibold)
                            .foregroundStyle(TravelStyle.ink)
                        VStack(spacing: 0) {
                            if let exception = card.exception { tableRow("예외") { cellText(exception) } }
                            if let penalty = card.penalty { tableRow("위반 시") { cellText(penalty, weight: .semibold) } }
                            tableRow("근거") {
                                VStack(alignment: .leading, spacing: 0) {
                                    if card.sources.isEmpty {
                                        cellText("규칙이 아니라 챙기면 좋은 일이에요.")
                                    }
                                    ForEach(card.sources, id: \.self) { source in
                                        Link(destination: source.url) {
                                            TravelLinkLabel(text: source.title, systemImage: "arrow.up.right")
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                }
                            }
                            if let checked = card.sources.first?.checkedOn {
                                tableRow("확인일") {
                                    VStack(alignment: .leading, spacing: 2) {
                                        cellText(checked)
                                            .monospacedDigit()
                                        Text(card.sources.compactMap(\.note).first ?? "출처가 바뀌면 다시 확인하고 날짜를 고쳐요")
                                            .travelFont(12)
                                            .foregroundStyle(TravelStyle.sub)
                                    }
                                }
                            }
                        }
                        .overlay(alignment: .top) { TravelStyle.tableTop.frame(height: 1) }
                        Text("출발 전에 공식 안내를 한 번 더 확인해 주세요. 규칙은 바뀔 수 있어요.")
                            .travelFont(13)
                            .travelLineHeight(1.5, size: 13)
                            .foregroundStyle(TravelStyle.sub)
                    }
                    .padding(.horizontal, TravelStyle.gutter)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .background(TravelStyle.page)
            .navigationTitle("규칙 카드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    /// 표 한 줄(시안: 이름 칸 84 · #F7F8FA · 13 회색 / 값 14 · 여백 12 · 아래 1px 선).
    private func tableRow<Value: View>(_ name: String, @ViewBuilder value: () -> Value) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(name)
                .travelFont(13)
                .foregroundStyle(TravelStyle.sub)
                .padding(12)
                .frame(width: 84, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .background(TravelStyle.box)
            value()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .bottom) { TravelHairline() }
    }

    private func cellText(_ text: String, weight: Font.Weight = .regular) -> some View {
        Text(text)
            .travelFont(14, weight)
            .travelLineHeight(1.5, size: 14)
            .foregroundStyle(TravelStyle.ink)
    }
}

/// 담당으로 거르기(시안 여행: 할 일) — 알약 높이 36 · 모서리 18 · 테두리 #D5D9DF · 13 · 고르면 primary 테두리·글자 굵게.
/// 숫자 = 「전체 13」 · 「담당 없음 4」(빨강).
struct TripAssigneeChips: View {
    @Binding var selection: TripAssigneeFilter
    var counts: [TripAssigneeFilter: Int] = [:]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TripAssigneeFilter.allCases) { item in
                    let selected = item == selection
                    Button {
                        selection = item
                    } label: {
                        HStack(spacing: 3) {
                            Text(item.label)
                            if let n = counts[item], n > 0 {
                                Text("\(n)")
                                    .foregroundStyle(item == .unassigned ? TravelStyle.red : (selected ? TravelStyle.primary : TravelStyle.body))
                            }
                        }
                        .travelFont(13, selected ? .semibold : .regular)
                        .monospacedDigit()
                        .foregroundStyle(selected ? TravelStyle.primary : TravelStyle.body)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(Capsule().fill(TravelStyle.page))
                        .overlay(Capsule().strokeBorder(selected ? TravelStyle.primary : TravelStyle.pillBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}
