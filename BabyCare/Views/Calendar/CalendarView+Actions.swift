import SwiftUI

extension CalendarView {
    // MARK: - Add Button (FAB)

    var addButton: some View {
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

    func openRecording() {
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

    func toggleTodo(_ todo: TodoItem) async {
        guard let userId = authVM.currentUserId else { return }
        await todoVM.toggleComplete(todo, userId: userId)
        // 로컬 업데이트
        if let index = calendarVM.todosForDate.firstIndex(where: { $0.id == todo.id }) {
            calendarVM.todosForDate[index].isCompleted.toggle()
        }
    }

    func loadData() async {
        guard let currentUserId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        await calendarVM.loadMonthActivities(userId: dataUserId, babyId: babyId)
        await calendarVM.loadActivitiesForDate(userId: dataUserId, babyId: babyId)
    }

    func loadMonthData() async {
        guard let currentUserId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        await calendarVM.loadMonthActivities(userId: dataUserId, babyId: babyId)
    }

    func loadDateData() async {
        guard let currentUserId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        await calendarVM.loadActivitiesForDate(userId: dataUserId, babyId: babyId)
    }
}
