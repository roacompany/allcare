import SwiftUI

struct CalendarView: View {
    @Environment(CalendarViewModel.self) private var calendarVM
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(TodoViewModel.self) private var todoVM

    @State private var editingActivity: Activity?
    @State private var showRecording = false

    private let weekdays = ["월", "화", "수", "목", "금", "토", "일"]
    private let feedingColor = Color(hex: "FF9FB5")
    private let sleepColor = Color(hex: "9FB5FF")
    private let diaperColor = Color(hex: "FFD59F")

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    monthHeader
                    calendarGrid
                        .padding(.horizontal)

                    Divider()
                        .padding(.vertical, 6)

                    dateHeader

                    eventsList
                }

                // FAB: 기록 추가
                addButton
            }
            .navigationTitle("캘린더")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadData() }
            .onChange(of: calendarVM.currentMonth) {
                Task { await loadMonthData() }
            }
            .onChange(of: calendarVM.selectedDate) {
                Task { await loadDateData() }
            }
            .onChange(of: babyVM.selectedBaby?.id) {
                Task { await loadData() }
            }
            .sheet(item: $editingActivity) { activity in
                ActivityEditSheet(activity: activity) { updated in
                    Task {
                        guard let userId = authVM.currentUserId else { return }
                        await activityVM.updateActivity(updated, userId: userId)
                        if let index = calendarVM.activitiesForDate.firstIndex(where: { $0.id == updated.id }) {
                            calendarVM.activitiesForDate[index] = updated
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showRecording, onDismiss: {
                activityVM.resetForm()
                Task { await loadDateData() }
            }) {
                RecordingView(initialCategory: nil)
            }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Button {
                calendarVM.previousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            Text(calendarVM.monthTitle)
                .font(.title3.weight(.semibold))

            // "오늘" 버튼 (현재 달이 아닐 때만)
            if !calendarVM.isCurrentMonth {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        calendarVM.goToToday()
                    }
                } label: {
                    Text("오늘")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor, in: Capsule())
                }
            }

            Spacer()

            Button {
                calendarVM.nextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 4) {
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(day == "토" ? .blue : day == "일" ? .red : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let days = calendarVM.daysInMonth
            let firstWeekday = calendarVM.firstWeekdayOfMonth

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Text("")
                        .frame(height: 44)
                }

                ForEach(days, id: \.self) { date in
                    dayCell(date: date)
                }
            }
        }
    }

    private func dayCell(date: Date) -> some View {
        let isSelected = date.isSameDay(as: calendarVM.selectedDate)
        let isToday = date.isToday
        let events = calendarVM.eventDots[date.startOfDay] ?? []

        return Button {
            calendarVM.selectDate(date)
        } label: {
            VStack(spacing: 2) {
                Text(DateFormatters.dayOfMonth.string(from: date))
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isSelected ? .white : isToday ? .blue : .primary)

                HStack(spacing: 2) {
                    if events.contains(.activity(.feeding)) {
                        Circle().fill(Color(hex: "FF9FB5")).frame(width: 4, height: 4)
                    }
                    if events.contains(.activity(.sleep)) {
                        Circle().fill(Color(hex: "9FB5FF")).frame(width: 4, height: 4)
                    }
                    if events.contains(.activity(.diaper)) {
                        Circle().fill(Color(hex: "FFD59F")).frame(width: 4, height: 4)
                    }
                    if events.contains(.hospitalVisit) {
                        Circle().fill(Color(hex: "82B1FF")).frame(width: 4, height: 4)
                    }
                    if events.contains(.vaccination) {
                        Circle().fill(Color(hex: "FF8A80")).frame(width: 4, height: 4)
                    }
                    if events.contains(.todo) {
                        Circle().fill(Color(hex: "A078D4")).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                isSelected
                    ? Color.accentColor
                    : isToday ? Color.accentColor.opacity(0.1) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date Header & Daily Summary

    private var dateHeader: some View {
        VStack(spacing: 8) {
            // 날짜 타이틀
            HStack {
                Text(DateFormatters.shortDate.string(from: calendarVM.selectedDate))
                    .font(.headline)
                if calendarVM.selectedDate.isToday {
                    Text("오늘")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                Spacer()
            }
            .padding(.horizontal)

            // 일일 요약 (데이터가 있을 때만)
            if calendarVM.hasDailySummary {
                HStack(spacing: 16) {
                    summaryChip(
                        icon: "cup.and.saucer.fill",
                        value: "\(calendarVM.feedingCount)회",
                        detail: calendarVM.totalMl > 0 ? "\(Int(calendarVM.totalMl))ml" : nil,
                        color: feedingColor
                    )
                    summaryChip(
                        icon: "moon.zzz.fill",
                        value: String(format: "%.1f시간", calendarVM.sleepHours),
                        detail: nil,
                        color: sleepColor
                    )
                    summaryChip(
                        icon: "humidity.fill",
                        value: "\(calendarVM.diaperCount)회",
                        detail: nil,
                        color: diaperColor
                    )
                }
                .padding(.horizontal)
            }
        }
    }

    private func summaryChip(icon: String, value: String, detail: String?, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.caption.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Events List

    private var hasAnyEvents: Bool {
        !calendarVM.activitiesForDate.isEmpty ||
        !calendarVM.hospitalVisitsForDate.isEmpty ||
        !calendarVM.vaccinationsForDate.isEmpty ||
        !calendarVM.todosForDate.isEmpty
    }

    private var eventsList: some View {
        Group {
            if calendarVM.isLoadingDate {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("기록을 불러오는 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else if !hasAnyEvents {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "기록 없음",
                    message: "이 날짜에 기록이 없습니다.\n아래 버튼으로 활동을 기록해보세요.",
                    actionTitle: "기록 추가",
                    action: { openRecording() }
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    // 할 일
                    if !calendarVM.todosForDate.isEmpty {
                        Section {
                            ForEach(calendarVM.todosForDate) { todo in
                                CalendarTodoRow(todo: todo) {
                                    Task { await toggleTodo(todo) }
                                }
                            }
                        } header: {
                            Label("할 일", systemImage: "checklist")
                        }
                    }

                    // 예방접종
                    if !calendarVM.vaccinationsForDate.isEmpty {
                        Section("예방접종") {
                            ForEach(calendarVM.vaccinationsForDate) { vax in
                                CalendarVaccinationRow(vaccination: vax)
                            }
                        }
                    }

                    // 병원 방문
                    if !calendarVM.hospitalVisitsForDate.isEmpty {
                        Section("병원 방문") {
                            ForEach(calendarVM.hospitalVisitsForDate) { visit in
                                CalendarHospitalRow(visit: visit)
                            }
                        }
                    }

                    // 활동 기록
                    if !calendarVM.activitiesForDate.isEmpty {
                        Section("활동 기록") {
                            ForEach(calendarVM.activitiesForDate) { activity in
                                ActivityRow(activity: activity)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingActivity = activity
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task {
                                                guard let userId = authVM.currentUserId else { return }
                                                await activityVM.deleteActivity(activity, userId: userId)
                                                calendarVM.activitiesForDate.removeAll { $0.id == activity.id }
                                            }
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            editingActivity = activity
                                        } label: {
                                            Label("수정", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Add Button (FAB)

    private var addButton: some View {
        Button {
            openRecording()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.accentColor.gradient)
                        .shadow(color: .accentColor.opacity(0.4), radius: 8, y: 4)
                )
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Actions

    private func openRecording() {
        // 선택된 날짜의 정오를 기본 시작 시간으로 설정
        let calendar = Calendar.current
        let selectedDay = calendarVM.selectedDate
        if selectedDay.isToday {
            activityVM.manualStartTime = Date()
            activityVM.isTimeAdjusted = false
        } else {
            // 과거 날짜: 해당 날짜 정오로 설정
            let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDay) ?? selectedDay
            activityVM.manualStartTime = noon
            activityVM.isTimeAdjusted = true
        }
        showRecording = true
    }

    private func toggleTodo(_ todo: TodoItem) async {
        guard let userId = authVM.currentUserId else { return }
        await todoVM.toggleComplete(todo, userId: userId)
        // 로컬 업데이트
        if let index = calendarVM.todosForDate.firstIndex(where: { $0.id == todo.id }) {
            calendarVM.todosForDate[index].isCompleted.toggle()
        }
    }

    private func loadData() async {
        guard let userId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        await calendarVM.loadMonthActivities(userId: userId, babyId: babyId)
        await calendarVM.loadActivitiesForDate(userId: userId, babyId: babyId)
    }

    private func loadMonthData() async {
        guard let userId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        await calendarVM.loadMonthActivities(userId: userId, babyId: babyId)
    }

    private func loadDateData() async {
        guard let userId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        await calendarVM.loadActivitiesForDate(userId: userId, babyId: babyId)
    }
}

// MARK: - Calendar Todo Row

private struct CalendarTodoRow: View {
    let todo: TodoItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(todo.isCompleted ? .green : Color(hex: "A078D4"))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text(todo.category.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color(hex: "A078D4")))

                    if let desc = todo.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Calendar Hospital Row

private struct CalendarHospitalRow: View {
    let visit: HospitalVisit

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: visit.visitType.color).opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: visit.visitType.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: visit.visitType.color))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(visit.hospitalName)
                        .font(.subheadline.weight(.medium))
                    Text(visit.visitType.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color(hex: visit.visitType.color)))
                }
                if let purpose = visit.purpose, !purpose.isEmpty {
                    Text(purpose)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(DateFormatters.shortTime.string(from: visit.visitDate))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Calendar Vaccination Row

private struct CalendarVaccinationRow: View {
    let vaccination: Vaccination

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "FF8A80").opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: "syringe.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "FF8A80"))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(vaccination.vaccine.displayName)
                        .font(.subheadline.weight(.medium))
                    Text("\(vaccination.doseNumber)차")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color(hex: "FF8A80")))
                }
                if vaccination.isCompleted {
                    Text("접종 완료")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "4CAF50"))
                } else if vaccination.isOverdue {
                    Text("접종 지연")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("접종 예정")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if let hospital = vaccination.hospital, !hospital.isEmpty {
                Text(hospital)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
