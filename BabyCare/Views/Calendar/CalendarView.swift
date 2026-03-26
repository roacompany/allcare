import SwiftUI

struct CalendarView: View {
    @Environment(CalendarViewModel.self) var calendarVM
    @Environment(ActivityViewModel.self) var activityVM
    @Environment(BabyViewModel.self) var babyVM
    @Environment(AuthViewModel.self) var authVM
    @Environment(TodoViewModel.self) var todoVM

    @State var editingActivity: Activity?
    @State var showRecording = false
    @State var showBabySelector = false

    let weekdays = ["월", "화", "수", "목", "금", "토", "일"]
    let feedingColor = AppColors.feedingColor
    let sleepColor = AppColors.sleepColor
    let diaperColor = AppColors.diaperColor

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
            .toolbar {
                if babyVM.babies.count > 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showBabySelector = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(babyVM.selectedBaby?.name ?? "아기")
                                    .font(.subheadline.weight(.medium))
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                        }
                        .confirmationDialog("아기 선택", isPresented: $showBabySelector, titleVisibility: .visible) {
                            ForEach(babyVM.babies) { baby in
                                Button(baby.name) {
                                    babyVM.selectBaby(baby)
                                }
                            }
                            Button("취소", role: .cancel) {}
                        }
                    }
                }
            }
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
}
