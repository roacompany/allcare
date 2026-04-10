import SwiftUI

extension CalendarView {
    // MARK: - Date Header & Daily Summary

    var dateHeader: some View {
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

    func summaryChip(icon: String, value: String, detail: String?, color: Color) -> some View {
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

    var hasAnyEvents: Bool {
        !calendarVM.activitiesForDate.isEmpty ||
        !calendarVM.hospitalVisitsForDate.isEmpty ||
        !calendarVM.vaccinationsForDate.isEmpty ||
        !calendarVM.todosForDate.isEmpty
    }

    var eventsList: some View {
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
                    // 인라인 광고 (Calendar 탭)
                    if AdExperimentVariant.currentVariant.shouldShowBanner(forTab: 1) {
                        Section {
                            AdBannerView()
                                .frame(maxWidth: .infinity)
                                .frame(height: AdBannerView.currentBannerHeight())
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }

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
                                                guard let currentUserId = authVM.currentUserId else { return }
                                                let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
                                                await activityVM.deleteActivity(activity, userId: dataUserId)
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
}
