import SwiftUI

struct DashboardView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var showBabySelector = false

    private let feedingColor = Color(hex: "FF9FB5")
    private let sleepColor = Color(hex: "9FB5FF")
    private let diaperColor = Color(hex: "FFD59F")

    private let quickActionTypes: [Activity.ActivityType] = [
        .feedingBreast,
        .feedingBottle,
        .feedingSolid,
        .feedingSnack,
        .sleep,
        .diaperWet,
        .diaperDirty,
        .diaperBoth,
        .bath,
        .temperature,
        .medication
    ]

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCardsSection
                    quickActionsSection
                    timelineSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .refreshable {
                await loadData()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    headerView
                }
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        Button {
            if babyVM.babies.count > 1 {
                showBabySelector = true
            }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .center, spacing: 2) {
                    if let baby = babyVM.selectedBaby {
                        Text(baby.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(baby.ageText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("아기 선택")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }

                if babyVM.babies.count > 1 {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog("아기 선택", isPresented: $showBabySelector, titleVisibility: .visible) {
            ForEach(babyVM.babies) { baby in
                Button(baby.name) {
                    babyVM.selectBaby(baby)
                    Task { await loadData() }
                }
            }
            Button("취소", role: .cancel) {}
        }
    }

    // MARK: - Summary Cards

    private var summaryCardsSection: some View {
        VStack(spacing: 12) {
            feedingSummaryCard
            HStack(spacing: 12) {
                sleepSummaryCard
                diaperSummaryCard
            }
        }
    }

    private var feedingSummaryCard: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(feedingColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(feedingColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("수유")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let last = activityVM.lastFeeding {
                        Text(last.startTime.timeAgo())
                            .font(.headline)
                            .foregroundStyle(.primary)
                    } else {
                        Text("기록 없음")
                            .font(.headline)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("오늘")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(activityVM.todayFeedingCount)회")
                        .font(.title3.bold())
                        .foregroundStyle(feedingColor)
                    if activityVM.todayTotalMl > 0 {
                        Text("\(Int(activityVM.todayTotalMl))ml")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var sleepSummaryCard: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(sleepColor.opacity(0.2))
                            .frame(width: 38, height: 38)
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(sleepColor)
                    }
                    Spacer()
                    Text("오늘")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("수면")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let last = activityVM.lastSleep {
                    Text(last.startTime.timeAgo())
                        .font(.callout.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else {
                    Text("기록 없음")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }

                Text(activityVM.todaySleepDuration > 0
                     ? activityVM.todaySleepDuration.shortDuration
                     : "0분")
                    .font(.title3.bold())
                    .foregroundStyle(sleepColor)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var diaperSummaryCard: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(diaperColor.opacity(0.2))
                            .frame(width: 38, height: 38)
                        Image(systemName: "humidity.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(diaperColor)
                    }
                    Spacer()
                    Text("오늘")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("기저귀")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let last = activityVM.lastDiaper {
                    Text(last.startTime.timeAgo())
                        .font(.callout.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else {
                    Text("기록 없음")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }

                Text("\(activityVM.todayDiaperCount)회")
                    .font(.title3.bold())
                    .foregroundStyle(diaperColor)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("빠른 기록")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(quickActionTypes, id: \.self) { type in
                    QuickActionButton(type: type) {
                        await quickSave(type: type)
                    }
                }
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
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

    private var emptyTimelineView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
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

    // MARK: - Actions

    private func loadData() async {
        guard let userId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        await activityVM.loadTodayActivities(userId: userId, babyId: baby.id)
    }

    private func quickSave(type: Activity.ActivityType) async {
        guard let userId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        await activityVM.quickSave(userId: userId, babyId: baby.id, type: type)
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let type: Activity.ActivityType
    let action: () async -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(type.color).opacity(0.15))
                        .frame(height: 52)
                    Image(systemName: type.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(Color(type.color))
                }
                Text(type.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Timeline Row

private struct TimelineRow: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(activity.type.color).opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: activity.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color(activity.type.color))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.type.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if let durationText = activity.durationText {
                        Text(durationText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let amountText = activity.amountText {
                        Text(amountText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let note = activity.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(activity.startTime.timeAgo())
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
}
