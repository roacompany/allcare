import SwiftUI

struct CalendarView: View {
    @Environment(CalendarViewModel.self) private var calendarVM
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var editingActivity: Activity?

    private let weekdays = ["월", "화", "수", "목", "금", "토", "일"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month Navigation
                monthHeader

                // Calendar Grid
                calendarGrid
                    .padding(.horizontal)

                Divider()
                    .padding(.vertical, 8)

                // Activities for selected date
                activitiesList
            }
            .navigationTitle("캘린더")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadData()
            }
            .onChange(of: calendarVM.currentMonth) {
                Task { await loadMonthData() }
            }
            .onChange(of: calendarVM.selectedDate) {
                Task { await loadDateData() }
            }
            .sheet(item: $editingActivity) { activity in
                ActivityEditSheet(activity: activity) { updated in
                    Task {
                        guard let userId = authVM.currentUserId else { return }
                        await activityVM.updateActivity(updated, userId: userId)
                        // 캘린더 목록도 갱신
                        if let index = calendarVM.activitiesForDate.firstIndex(where: { $0.id == updated.id }) {
                            calendarVM.activitiesForDate[index] = updated
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                calendarVM.previousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            Text(calendarVM.monthTitle)
                .font(.title3.weight(.semibold))

            Spacer()

            Button {
                calendarVM.nextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding()
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 4) {
            // Weekday headers
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            let days = calendarVM.daysInMonth
            let firstWeekday = calendarVM.firstWeekdayOfMonth

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                // Empty cells before first day
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Text("")
                        .frame(height: 44)
                }

                // Day cells
                ForEach(days, id: \.self) { date in
                    dayCell(date: date)
                }
            }
        }
    }

    private func dayCell(date: Date) -> some View {
        let isSelected = date.isSameDay(as: calendarVM.selectedDate)
        let isToday = date.isToday
        let dots = calendarVM.activityDots[date.startOfDay] ?? []

        return Button {
            calendarVM.selectDate(date)
        } label: {
            VStack(spacing: 2) {
                Text(DateFormatters.dayOfMonth.string(from: date))
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isSelected ? .white : isToday ? .blue : .primary)

                // Activity dots
                HStack(spacing: 2) {
                    if dots.contains(.feeding) {
                        Circle().fill(Color(hex: "FF9FB5")).frame(width: 4, height: 4)
                    }
                    if dots.contains(.sleep) {
                        Circle().fill(Color(hex: "9FB5FF")).frame(width: 4, height: 4)
                    }
                    if dots.contains(.diaper) {
                        Circle().fill(Color(hex: "FFD59F")).frame(width: 4, height: 4)
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

    // MARK: - Activities List

    private var activitiesList: some View {
        Group {
            if calendarVM.activitiesForDate.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "기록 없음",
                    message: "\(DateFormatters.shortDate.string(from: calendarVM.selectedDate))의 기록이 없습니다."
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
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
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Data Loading

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
