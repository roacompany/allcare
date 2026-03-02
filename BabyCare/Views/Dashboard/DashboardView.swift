import SwiftUI

struct DashboardView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(ProductViewModel.self) private var productVM
    @Environment(HealthViewModel.self) private var healthVM

    @State private var showBabySelector = false
    @State private var editingActivity: Activity?
    @State private var productCandidates: [BabyProduct] = []

    private let feedingColor = Color(hex: "FF9FB5")
    private let sleepColor = Color(hex: "9FB5FF")
    private let diaperColor = Color(hex: "FFD59F")

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    alertBannersSection
                    aiAdviceShortcut
                    predictionSection
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
        .sheet(item: $editingActivity) { activity in
            ActivityEditSheet(activity: activity) { updated in
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    await activityVM.updateActivity(updated, userId: userId)
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: Binding(
            get: { !productCandidates.isEmpty },
            set: { if !$0 { productCandidates = [] } }
        )) {
            ProductPickerSheet(products: productCandidates) { selected in
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    await productVM.deductFromProduct(selected, userId: userId)
                }
                productCandidates = []
            }
            .presentationDetents([.medium])
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
                if let baby = babyVM.selectedBaby {
                    Text(baby.gender.emoji)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(baby.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(baby.ageText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("아기 선택")
                        .font(.headline)
                        .foregroundStyle(.primary)
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

    // MARK: - Alert Banners

    @ViewBuilder
    private var alertBannersSection: some View {
        VStack(spacing: 8) {
            // 접종 지연 알림
            if !healthVM.overdueVaccinations.isEmpty {
                DashboardAlertBanner(
                    icon: "exclamationmark.triangle.fill",
                    message: "접종 지연 \(healthVM.overdueVaccinations.count)건",
                    color: .red
                )
            }

            // 접종 예정 알림
            if !healthVM.upcomingVaccinations.isEmpty {
                DashboardAlertBanner(
                    icon: "syringe.fill",
                    message: "30일 이내 접종 \(healthVM.upcomingVaccinations.count)건",
                    color: .orange
                )
            }

            // 재고 부족 알림
            if !productVM.lowStockProducts.isEmpty {
                DashboardAlertBanner(
                    icon: "bag.fill",
                    message: "재고 부족: \(productVM.lowStockProducts.map(\.name).joined(separator: ", "))",
                    color: Color(hex: "FF9F9F")
                )
            }

            // 유통기한 임박 알림
            if !productVM.expiringSoonProducts.isEmpty {
                DashboardAlertBanner(
                    icon: "clock.badge.exclamationmark.fill",
                    message: "유통기한 임박 \(productVM.expiringSoonProducts.count)건",
                    color: .yellow
                )
            }
        }
    }

    // MARK: - AI Advice Shortcut

    private var aiAdviceShortcut: some View {
        NavigationLink {
            AIAdviceView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI 육아 조언")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("궁금한 점을 물어보세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.purple.opacity(0.06))
            )
        }
    }

    // MARK: - Prediction

    @ViewBuilder
    private var predictionSection: some View {
        if let predictionText = activityVM.nextFeedingText {
            HStack(spacing: 12) {
                Image(systemName: activityVM.isFeedingOverdue
                       ? "exclamationmark.circle.fill"
                       : "clock.fill")
                    .font(.title3)
                    .foregroundStyle(activityVM.isFeedingOverdue ? .red : feedingColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("다음 수유 예상")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(predictionText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(activityVM.isFeedingOverdue ? .red : .primary)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(activityVM.isFeedingOverdue
                          ? Color.red.opacity(0.08)
                          : feedingColor.opacity(0.08))
            )
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

            NavigationLink {
                StatsView()
            } label: {
                HStack {
                    Text("통계 자세히 보기")
                        .font(.caption.weight(.medium))
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var feedingSummaryCard: some View {
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

    private var sleepSummaryCard: some View {
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

    private var diaperSummaryCard: some View {
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

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("빠른 기록")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: gridColumns, spacing: 10) {
                QuickActionButton(type: .feedingBreast) {
                    await quickSave(type: .feedingBreast)
                }
                QuickActionButton(type: .feedingSolid) {
                    await quickSave(type: .feedingSolid)
                }
                QuickActionButton(type: .feedingSnack) {
                    await quickSave(type: .feedingSnack)
                }
                QuickActionButton(type: .diaperWet) {
                    await quickSave(type: .diaperWet)
                }
                QuickActionButton(type: .diaperDirty) {
                    await quickSave(type: .diaperDirty)
                }
                QuickActionButton(type: .diaperBoth) {
                    await quickSave(type: .diaperBoth)
                }
                QuickActionButton(type: .bath) {
                    await quickSave(type: .bath)
                }
                QuickActionButton(type: .medication) {
                    await quickSave(type: .medication)
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
                                        guard let userId = authVM.currentUserId else { return }
                                        await activityVM.deleteActivity(activity, userId: userId)
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

        // 알림 권한 요청
        _ = await NotificationService.shared.requestPermission()

        // 병렬 로딩: 활동 + 건강 + 용품
        async let loadActivities: Void = activityVM.loadTodayActivities(userId: userId, babyId: baby.id)
        async let loadHealth: Void = healthVM.loadAll(userId: userId, babyId: baby.id, babyName: baby.name)
        async let loadProducts: Void = productVM.loadProducts(userId: userId)

        _ = await (loadActivities, loadHealth, loadProducts)

        // 스케줄 자동 생성 (필요 시)
        await healthVM.generateScheduleIfNeeded(
            babyId: baby.id,
            birthDate: baby.birthDate,
            userId: userId,
            babyName: baby.name
        )

        // 위젯 데이터 동기화
        activityVM.syncWidgetData(babyName: baby.name, babyAge: baby.ageText)
    }

    private func quickSave(type: Activity.ActivityType) async {
        guard let userId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        await activityVM.quickSave(userId: userId, babyId: baby.id, type: type)
        if let candidates = await productVM.deductStockForActivity(type, userId: userId) {
            productCandidates = candidates
        }
    }
}

// MARK: - Dashboard Alert Banner

private struct DashboardAlertBanner: View {
    let icon: String
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

// MARK: - Activity Edit Sheet

struct ActivityEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let activity: Activity
    let onSave: (Activity) -> Void

    @State private var editedStartTime: Date
    @State private var editedEndTime: Date?

    init(activity: Activity, onSave: @escaping (Activity) -> Void) {
        self.activity = activity
        self.onSave = onSave
        _editedStartTime = State(initialValue: activity.startTime)
        _editedEndTime = State(initialValue: activity.endTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(activity.type.color).opacity(0.18))
                                .frame(width: 36, height: 36)
                            Image(systemName: activity.type.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(Color(activity.type.color))
                        }
                        Text(activity.type.displayName)
                            .font(.headline)
                    }
                }

                Section("시작 시간") {
                    DatePicker(
                        "시작",
                        selection: $editedStartTime,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                }

                if activity.endTime != nil || activity.duration != nil {
                    Section("종료 시간") {
                        DatePicker(
                            "종료",
                            selection: Binding(
                                get: { editedEndTime ?? editedStartTime },
                                set: { editedEndTime = $0 }
                            ),
                            in: editedStartTime...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }
            .navigationTitle("시간 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        var updated = activity
                        updated.startTime = editedStartTime
                        if let end = editedEndTime {
                            updated.endTime = end
                            updated.duration = end.timeIntervalSince(editedStartTime)
                        } else if activity.duration != nil {
                            let duration = (activity.endTime ?? activity.startTime.addingTimeInterval(activity.duration ?? 0))
                                .timeIntervalSince(activity.startTime)
                            updated.endTime = editedStartTime.addingTimeInterval(duration)
                        }
                        onSave(updated)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
        .environment(ProductViewModel())
        .environment(HealthViewModel())
}
