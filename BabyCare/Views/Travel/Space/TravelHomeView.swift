import SwiftUI

/// 여행 공간 홈(시안 Main · Home-Flight · 캔버스 Version 84) — 여행 머리(도시 ⌄ · 수정 · D-day 칩 · 기간) ·
/// 오늘 떠나는 편 · 다음 일정(그날 예약·이동 + 아이 칩) · 출발 전 할 일 · 아이 요약.
/// 모양 = 시안 숫자 그대로(TravelStyle) — 흰 바탕 납작 칸 · 8px 회색 띠 · 16 굵은 머리말.
struct TravelHomeView: View {
    let vm: TripDetailViewModel
    let trips: [Trip]
    let onSelect: (Trip) -> Void
    let onCreate: () -> Void
    /// 도시 ⌄ 메뉴 「여행 삭제」(확인 뒤 지운다).
    let onDelete: (Trip) -> Void
    /// 여행 수정 시트의 「여행 삭제」 — 없으면 그 버튼을 안 보인다.
    var onDeleteTrip: (() -> Void)?
    /// 「일정 전체」 — 일정 칸을 그날로 연다.
    let onShowSchedule: (Date) -> Void
    /// 「n개」 — 준비 칸 할 일(전체)로.
    let onShowTasks: () -> Void
    /// 「아이 정보」 — 아이 화면을 밀어 연다.
    let onShowChild: () -> Void

    @State private var editingInfo = false

    var body: some View {
        let summary = TravelHomeSummary.build(tasks: vm.tasks, states: vm.trip.taskStates, today: vm.today, calendar: vm.calendar)
        let days = vm.days
        let focus = TravelHomeSchedule.focusDay(days: days, today: vm.today, calendar: vm.calendar)
        TravelList {
            header
                .travelRow(top: 16, bottom: 18)
            TripStatusRows(vm: vm)
            if let flight = vm.todayFlight {
                TravelBandRow()
                TravelFlightSections(vm: vm, flight: flight)
            }
            if let focus {
                TravelBandRow()
                scheduleSection(focus, days: days)
            }
            TravelBandRow()
            taskSection(summary, days: days)
            TravelBandRow()
            TravelSectionHeader(title: "아이", trailing: "아이 정보", action: onShowChild)
                .travelRow()
            childSummary
                .travelRow(bottom: 12)
        }
        .refreshable {
            await vm.refreshFlightStatus()
        }
        .sheet(isPresented: $editingInfo) {
            TripCreateSheet(editing: vm.trip, calendar: vm.calendar, onDelete: onDeleteTrip) { city, startDay, endDay in
                Task { await vm.updateTripInfo(city: city, startDay: startDay, endDay: endDay) }
            }
        }
    }

    // MARK: - 머리(시안 Main) — 도시 22 굵게 ⌄(여행 고르기) · 오른쪽 회색 「수정」 · 칩 「D-21」 + 기간 14

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Menu {
                    ForEach(trips) { trip in
                        Button {
                            onSelect(trip)
                        } label: {
                            if trip.id == vm.trip.id {
                                // 이름을 고친 뒤에도 지금 여행은 최신 이름으로(목록은 열 때 읽은 사본).
                                Label(vm.trip.city, systemImage: "checkmark")
                            } else {
                                Text(trip.city)
                            }
                        }
                    }
                    Divider()
                    Button {
                        onCreate()
                    } label: {
                        Label("새 여행 만들기", systemImage: "plus")
                    }
                    Button(role: .destructive) {
                        onDelete(vm.trip)
                    } label: {
                        Label("여행 삭제", systemImage: "trash")
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(vm.trip.city)
                            .travelFont(22, .bold, tracking: -0.02)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(TravelStyle.ink)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("여행 바꾸기, 지금 \(vm.trip.city)")
                Spacer(minLength: 8)
                Button {
                    editingInfo = true
                } label: {
                    Text("수정")
                        .travelFont(14)
                        .foregroundStyle(TravelStyle.sub)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("여행 수정")
                .accessibilityIdentifier("travel.editTrip")
            }
            HStack(alignment: .center, spacing: 8) {
                Text(TripHeaderText.badge(vm.trip, today: vm.today, calendar: vm.calendar))
                    .travelFont(13, .bold)
                    .foregroundStyle(TravelStyle.primary)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .frame(minHeight: 24)
                    .background(RoundedRectangle(cornerRadius: 4).fill(TravelStyle.rangeBand))
                Text(TripHeaderText.homeDates(vm.trip, calendar: vm.calendar))
                    .travelFont(14)
                    .foregroundStyle(TravelStyle.body)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 다음 일정(시안 Main) — 머리 + 「일정 전체 ›」 · 그날 예약·이동 줄

    @ViewBuilder
    private func scheduleSection(_ day: Date, days: [Date]) -> some View {
        let rows = vm.itinerary.days.first { $0.date == day }?.homeLines ?? []
        TravelSectionHeader(title: TravelHomeSchedule.title(day: day, days: days, today: vm.today, calendar: vm.calendar),
                            trailing: "일정 전체", action: { onShowSchedule(day) })
            .travelRow()
        if rows.isEmpty {
            Text("이날은 등록한 예약이 없어요.")
                .travelFont(14)
                .foregroundStyle(TravelStyle.sub)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { TravelHairline() }
                .travelRow(bottom: 6)
        } else {
            ForEach(rows) { row in
                TravelHomeScheduleLine(row: row)
                    .travelRow(bottom: row.id == rows.last?.id ? 6 : 0)
            }
        }
    }

    // MARK: - 출발 전 할 일(시안 Main) — 머리 + 「n개 ›」 · 앞 3개

    @ViewBuilder
    private func taskSection(_ summary: TravelHomeSummary, days: [Date]) -> some View {
        let rows = summary.homeRows
        TravelSectionHeader(title: TravelHomeSchedule.taskTitle(days: days, today: vm.today, calendar: vm.calendar),
                            trailing: "\(summary.openCount)개", action: onShowTasks)
            .travelRow()
        if rows.isEmpty {
            Text(vm.tasks.isEmpty ? "예약을 추가하면 할 일과 마감이 생겨요." : "할 일을 모두 끝냈어요.")
                .travelFont(14)
                .foregroundStyle(TravelStyle.sub)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { TravelHairline() }
                .travelRow(bottom: 4)
        } else {
            ForEach(rows) { task in
                TravelHomeTaskRow(task: task, state: vm.state(for: task.id), now: vm.today, calendar: vm.calendar,
                                  onToggle: { Task { await vm.toggleDone(task.id) } },
                                  onAssign: { a in Task { await vm.setAssignee(a, for: task.id) } })
                    .travelRow(bottom: task.id == rows.last?.id ? 4 : 0)
            }
        }
    }

    // MARK: - 아이 요약(시안: 이름 칸 112 · 14 · 줄 사이 4)

    private var childSummary: some View {
        let start = Trip.date(fromDayKey: vm.trip.startDay, calendar: vm.calendar) ?? vm.today
        return VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 4) {
                childLine("출발일 월령", "\(TravelChildText.months(at: start, birthDate: vm.child.birthDate, calendar: vm.calendar))개월")
                childLine("낮잠", napStarts ?? "기록 없음")
                childLine("밤잠", vm.rhythm?.bedtimeMinute.map(TravelChildText.clock) ?? "기록 없음")
            }
            Text(childFootnote)
                .travelFont(13)
                .foregroundStyle(TravelStyle.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func childLine(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .travelFont(14)
                .foregroundStyle(TravelStyle.sub)
                .frame(width: 112, alignment: .leading)
            Text(value)
                .travelFont(14)
                .foregroundStyle(TravelStyle.ink)
                .monospacedDigit()
        }
    }

    private var napStarts: String? {
        guard let naps = vm.rhythm?.naps, !naps.isEmpty else { return nil }
        return naps.map { TravelChildText.clock($0.startMinute) }.joined(separator: ", ") + "쯤"
    }

    private var childFootnote: String {
        if vm.childLoadFailed { return "아기 기록을 불러오지 못했어요." }
        if vm.rhythm?.isRough == true { return "최근 7일 기록으로 계산했어요 · 기록이 적어 대략이에요" }
        return "최근 7일 기록으로 계산했어요"
    }
}

/// 다음 일정 한 줄(시안 Main) — 위 1px 선 · 시각 46(14 굵게) · 제목 15 굵게(600) · 아래 13 회색 · 아이 칩(12 · #A15C00 · #FFF4E5).
struct TravelHomeScheduleLine: View {
    let row: Itinerary.HomeLine

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(row.clock)
                    .travelFont(14, .bold)
                    .foregroundStyle(row.isOpen ? TravelStyle.amber : TravelStyle.ink)
                    .monospacedDigit()
                if let note = row.clockNote {
                    Text(note)
                        .travelFont(11)
                        .foregroundStyle(TravelStyle.sub)
                }
            }
            .frame(width: 46, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .travelFont(15, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                if let detail = row.detail {
                    Text(detail)
                        .travelFont(13)
                        .foregroundStyle(TravelStyle.sub)
                        .monospacedDigit()
                }
                if let note = row.childNote {
                    Text(note)
                        .travelFont(12)
                        .foregroundStyle(TravelStyle.amber)
                        .monospacedDigit()
                        .padding(.vertical, 3)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 4).fill(TravelStyle.amberSoft))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { TravelHairline() }
        .accessibilityElement(children: .combine)
    }
}

/// 할 일 한 줄(시안 Main 「출발 전 할 일」) — 위 1px 선 · 체크 22 · 제목 15 · 담당 칩(19) + 마감 13 · 오른쪽 D-day 14 굵게.
struct TravelHomeTaskRow: View {
    let task: TripTask
    let state: TripTaskState?
    let now: Date
    let calendar: Calendar
    let onToggle: () -> Void
    var onAssign: ((TripAssignee) -> Void)?

    private var isDone: Bool { state?.isDone == true }

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
                HStack(alignment: .center, spacing: 6) {
                    if let onAssign {
                        TravelAssigneeChipMenu(state: state, small: true, onAssign: onAssign)
                    } else {
                        TravelChip(text: TravelAssigneeChipText.text(state?.assignee),
                                   tone: TravelAssigneeChipText.isMissing(state?.assignee) ? .red : .neutral, small: true)
                    }
                    Group {
                        if let d = focusDeadline {
                            Text("\(d.label) 마감 \(d.text(calendar: calendar))")
                        } else if let detail = task.detail {
                            Text(detail)
                        } else {
                            Text(TripDateText.recommended(task.recommendedOn, calendar: calendar))
                        }
                    }
                    .travelFont(13)
                    .foregroundStyle(TravelStyle.sub)
                    .monospacedDigit()
                    .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            if let d = focusDeadline, !isDone {
                Text(TripDateText.dDayText(TripTaskOrdering.dDay(to: d.at, now: now, calendar: calendar)))
                    .travelFont(14, .bold)
                    .monospacedDigit()
                    .foregroundStyle(TripTaskOrdering.isUrgent(d.at, now: now, calendar: calendar) ? TravelStyle.red : TravelStyle.ink)
            }
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { TravelHairline() }
    }
}
