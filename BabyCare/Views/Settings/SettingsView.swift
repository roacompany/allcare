import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AnnouncementViewModel.self) private var announcementVM

    @State private var showAddBaby = false
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Baby Management
                Section("아기 관리") {
                    ForEach(babyVM.babies) { baby in
                        NavigationLink {
                            BabyDetailView(baby: baby)
                        } label: {
                            HStack(spacing: 12) {
                                Text(baby.gender.emoji)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text(baby.name)
                                        .font(.body.weight(.medium))
                                    Text(baby.ageText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Button {
                        showAddBaby = true
                    } label: {
                        Label("아기 추가", systemImage: "plus.circle.fill")
                    }
                }

                // 용품 관리 (별도 탭 없이 여기서 접근)
                Section("관리") {
                    NavigationLink {
                        ProductListView()
                    } label: {
                        Label("용품 관리", systemImage: "bag.fill")
                    }

                    NavigationLink {
                        TodoView()
                    } label: {
                        Label("할 일", systemImage: "checklist")
                    }

                    NavigationLink {
                        RoutineView()
                    } label: {
                        Label("루틴", systemImage: "list.clipboard")
                    }

                    NavigationLink {
                        PurchaseHistoryView()
                    } label: {
                        Label("구매 분석", systemImage: "chart.bar.xaxis")
                    }

                    NavigationLink {
                        StatsView()
                    } label: {
                        Label("통계", systemImage: "chart.bar.fill")
                    }

                    NavigationLink {
                        SoundPlayerView()
                    } label: {
                        Label("소리", systemImage: "speaker.wave.2.fill")
                    }
                }

                // App Settings
                Section("앱 설정") {
                    NavigationLink {
                        AnnouncementListView()
                    } label: {
                        Label {
                            HStack {
                                Text("공지사항")
                                Spacer()
                                if announcementVM.hasUnread {
                                    Text("\(announcementVM.unreadCount)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(.red))
                                }
                            }
                        } icon: {
                            Image(systemName: "megaphone.fill")
                        }
                    }

                    NavigationLink {
                        QuickRecordSettingsView()
                    } label: {
                        Label("빠른 기록 설정", systemImage: "square.grid.2x2.fill")
                    }

                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("알림", systemImage: "bell.fill")
                    }

                    NavigationLink {
                        FamilySharingView()
                    } label: {
                        Label("가족 공유", systemImage: "person.2.fill")
                    }

                    NavigationLink {
                        AIAdviceView()
                    } label: {
                        Label("AI 육아 조언", systemImage: "bubble.left.and.text.bubble.right.fill")
                    }
                }

                // Admin (visible only to admin users)
                if AdminConfig.isAdmin(authVM.currentUserId) {
                    Section("관리자") {
                        NavigationLink {
                            AdminDashboardView()
                        } label: {
                            Label("관리자 패널", systemImage: "shield.fill")
                        }
                    }
                }

                // Account
                Section("계정") {
                    if authVM.isAuthenticated {
                        HStack {
                            Text("계정 ID")
                            Spacer()
                            Text(authVM.currentUserId ?? "-")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }

                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section("정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("1.0.0").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("설정")
            .sheet(isPresented: $showAddBaby) {
                AddBabyView()
            }
            .alert("로그아웃", isPresented: $showLogoutAlert) {
                Button("취소", role: .cancel) {}
                Button("로그아웃", role: .destructive) {
                    authVM.signOut()
                }
            } message: {
                Text("정말 로그아웃 하시겠습니까?")
            }
        }
    }
}

// MARK: - NotificationSettingsView

struct NotificationSettingsView: View {
    @State private var rules = ActivityReminderSettings.rules
    @State private var vaccinationEnabled = NotificationSettings.vaccinationReminderEnabled
    @State private var vaccinationDays = NotificationSettings.vaccinationDaysBefore
    @State private var reorderEnabled = NotificationSettings.reorderReminderEnabled

    private let intervalOptions: [Int] = [30, 60, 90, 120, 180, 240, 360, 480, 720, 1440]

    private let vaccinationDayOptions: [Int] = [0, 1, 3, 7, 14, 30]

    var body: some View {
        List {
            // 활동별 알림
            Section {
                ForEach($rules) { $rule in
                    Toggle(isOn: $rule.enabled) {
                        HStack(spacing: 10) {
                            if let type = rule.type {
                                Image(systemName: type.icon)
                                    .font(.body)
                                    .foregroundStyle(Color(type.color))
                                    .frame(width: 24)
                            }
                            Text(rule.displayName)
                        }
                    }
                    .onChange(of: rule.enabled) { _, newVal in
                        saveRules()
                        if !newVal, let type = rule.type {
                            NotificationService.shared.cancelActivityReminder(type: type)
                        }
                    }

                    if rule.enabled {
                        Picker(selection: $rule.intervalMinutes) {
                            ForEach(intervalOptions, id: \.self) { mins in
                                Text(intervalLabel(mins)).tag(mins)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Color.clear.frame(width: 24)
                                Text("알림 간격")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onChange(of: rule.intervalMinutes) { _, _ in
                            saveRules()
                        }
                    }
                }
            } header: {
                Text("활동 기록 알림")
            } footer: {
                Text("기록 후 설정한 시간이 지나면 알림을 보냅니다. 원하는 활동만 켜세요.")
            }

            // 접종 알림
            Section {
                Toggle("접종 알림", isOn: $vaccinationEnabled)
                    .onChange(of: vaccinationEnabled) { _, val in
                        NotificationSettings.vaccinationReminderEnabled = val
                    }

                if vaccinationEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("알림 시점")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        FlowLayout(spacing: 8) {
                            ForEach(vaccinationDayOptions, id: \.self) { day in
                                let isSelected = vaccinationDays.contains(day)
                                Button {
                                    toggleVaccinationDay(day)
                                } label: {
                                    Text(vaccinationDayLabel(day))
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
                                        )
                                        .foregroundStyle(isSelected ? .blue : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("예방접종")
            } footer: {
                Text("예정된 접종일 기준, 선택한 시점에 알림을 보냅니다.")
            }

            // 재구매
            Section {
                Toggle("재구매 알림", isOn: $reorderEnabled)
                    .onChange(of: reorderEnabled) { _, val in
                        NotificationSettings.reorderReminderEnabled = val
                    }
            } header: {
                Text("용품")
            } footer: {
                Text("용품 재고가 설정한 기준 이하로 떨어지면 알림을 보냅니다.")
            }
        }
        .navigationTitle("알림 설정")
    }

    private func saveRules() {
        ActivityReminderSettings.rules = rules
    }

    private func intervalLabel(_ minutes: Int) -> String {
        if minutes >= 1440 {
            return "\(minutes / 1440)일"
        } else if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
        }
        return "\(minutes)분"
    }

    private func toggleVaccinationDay(_ day: Int) {
        if vaccinationDays.contains(day) {
            guard vaccinationDays.count > 1 else { return }
            vaccinationDays.removeAll { $0 == day }
        } else {
            vaccinationDays.append(day)
            vaccinationDays.sort(by: >)
        }
        NotificationSettings.vaccinationDaysBefore = vaccinationDays
    }

    private func vaccinationDayLabel(_ day: Int) -> String {
        switch day {
        case 0: "당일"
        case 1: "1일 전"
        default: "\(day)일 전"
        }
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
