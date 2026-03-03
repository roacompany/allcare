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
                        StatsView()
                    } label: {
                        Label("통계", systemImage: "chart.bar.fill")
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
    @State private var feedingEnabled = NotificationSettings.feedingReminderEnabled
    @State private var feedingHours = NotificationSettings.feedingIntervalHours
    @State private var vaccinationEnabled = NotificationSettings.vaccinationReminderEnabled
    @State private var reorderEnabled = NotificationSettings.reorderReminderEnabled

    private let intervalOptions: [Double] = [1.5, 2, 2.5, 3, 3.5, 4, 5, 6]

    var body: some View {
        List {
            Section {
                Toggle("수유 알림", isOn: $feedingEnabled)
                    .onChange(of: feedingEnabled) { _, val in
                        NotificationSettings.feedingReminderEnabled = val
                        if !val { NotificationService.shared.cancelFeedingReminders() }
                    }

                if feedingEnabled {
                    Picker("수유 간격", selection: $feedingHours) {
                        ForEach(intervalOptions, id: \.self) { hours in
                            Text(hours.truncatingRemainder(dividingBy: 1) == 0
                                 ? "\(Int(hours))시간"
                                 : "\(Int(hours))시간 \(Int(hours.truncatingRemainder(dividingBy: 1) * 60))분")
                                .tag(hours)
                        }
                    }
                    .onChange(of: feedingHours) { _, val in
                        NotificationSettings.feedingIntervalHours = val
                    }
                }
            } header: {
                Text("수유")
            } footer: {
                Text("수유 기록 후 설정한 간격이 지나면 알림을 보냅니다.")
            }

            Section {
                Toggle("접종 알림", isOn: $vaccinationEnabled)
                    .onChange(of: vaccinationEnabled) { _, val in
                        NotificationSettings.vaccinationReminderEnabled = val
                    }
            } header: {
                Text("예방접종")
            } footer: {
                Text("예정된 접종 7일 전, 1일 전에 알림을 보냅니다.")
            }

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
}
