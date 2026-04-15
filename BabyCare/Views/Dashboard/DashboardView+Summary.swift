import SwiftUI

extension DashboardView {
    // MARK: - Insight Cards

    var insightCardsSection: some View {
        DashboardInsightCards(insights: insightService.insights)
    }

    // MARK: - Quick Actions

    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("빠른 기록")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(QuickRecordSettings.enabledTypes, id: \.self) { type in
                    QuickActionButton(type: type) {
                        await quickSave(type: type)
                    }
                }
            }
        }
    }

    // MARK: - Timeline

    var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘의 기록")
                .font(.headline)
                .foregroundStyle(.primary)

            if activityVM.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 32)
                    Spacer()
                }
            } else if activityVM.todayActivities.isEmpty {
                emptyTimelineView
            } else {
                VStack(spacing: 0) {
                    ForEach(activityVM.todayActivities) { activity in
                        TimelineRow(activity: activity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingActivity = activity
                            }
                            .contextMenu {
                                Button {
                                    editingActivity = activity
                                } label: {
                                    Label("시간 수정", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    Task {
                                        guard let currentUserId = authVM.currentUserId else { return }
                                        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
                                        await activityVM.deleteActivity(activity, userId: dataUserId)
                                    }
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                        if activity.id != activityVM.todayActivities.last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    var emptyTimelineView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text("활동이 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("빠른 기록 버튼으로 첫 번째 기록을 추가해보세요")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .cardStyle()
    }

}
