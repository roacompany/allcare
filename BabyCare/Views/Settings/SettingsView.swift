import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AnnouncementViewModel.self) private var announcementVM
    @Environment(ThemeManager.self) private var themeManager

    @State private var showAddBaby = false
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @AppStorage("analytics_opt_out") private var analyticsOptOut = false

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
                Section(header: Text("바로가기"), footer: Text("대시보드에서도 접근할 수 있습니다")) {
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
                        BadgeGalleryView()
                    } label: {
                        Label("내 배지", systemImage: "rosette")
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

                // 화면 모드
                Section("화면 모드") {
                    @Bindable var tm = themeManager
                    Picker("화면 모드", selection: $tm.currentMode) {
                        ForEach(ThemeManager.AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // App Settings
                Section {
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

                    Toggle(isOn: Binding(
                        get: { !analyticsOptOut },
                        set: { newValue in
                            analyticsOptOut = !newValue
                            AnalyticsService.shared.setEnabled(newValue)
                        }
                    )) {
                        Label("앱 사용 데이터 공유", systemImage: "chart.bar.fill")
                    }
                    .tint(.pink)

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
                } header: {
                    Text("앱 설정")
                } footer: {
                    if !analyticsOptOut {
                        Text("앱 개선을 위해 사용 통계를 익명으로 수집합니다. 개인 기록은 포함되지 않습니다.")
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

                    Button(role: .destructive) {
                        showDeleteAccountAlert = true
                    } label: {
                        Label("계정 삭제", systemImage: "person.crop.circle.badge.minus")
                    }
                }

                Section("법적 고지") {
                    Link(destination: URL(string: "https://roacompany.github.io/allcare/privacy.html")!) {
                        Label("개인정보 처리방침", systemImage: "hand.raised.fill")
                    }

                    Link(destination: URL(string: "https://roacompany.github.io/allcare/terms.html")!) {
                        Label("서비스 이용약관", systemImage: "doc.text.fill")
                    }
                }

                Section("정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "").foregroundStyle(.secondary)
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
            .alert("계정 삭제", isPresented: $showDeleteAccountAlert) {
                Button("취소", role: .cancel) {}
                Button("계정 삭제", role: .destructive) {
                    Task { await authVM.deleteAccount() }
                }
            } message: {
                Text("계정을 삭제하면 모든 기록이 영구적으로 삭제되며 복구할 수 없습니다.\n\n삭제 전에 설정 > 통계에서 데이터를 내보낼 수 있습니다.\n\n정말 삭제하시겠습니까?")
            }
            .alert("오류", isPresented: .init(get: { authVM.errorMessage != nil }, set: { if !$0 { authVM.errorMessage = nil } })) {
                Button("확인") { authVM.errorMessage = nil }
            } message: {
                Text(authVM.errorMessage ?? "")
            }
        }
    }
}
