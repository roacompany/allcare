import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

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
                }

                // App Settings
                Section("앱 설정") {
                    NavigationLink {
                        Text("알림 설정")
                    } label: {
                        Label("알림", systemImage: "bell.fill")
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
