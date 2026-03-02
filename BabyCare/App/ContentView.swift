import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    @State private var selectedTab = 0
    @State private var showRecording = false

    var body: some View {
        Group {
            if authVM.isAuthenticated {
                if babyVM.babies.isEmpty && !babyVM.isLoading {
                    onboardingView
                } else {
                    mainTabView
                }
            } else {
                NavigationStack {
                    LoginView()
                }
            }
        }
        .task {
            if let userId = authVM.currentUserId {
                await babyVM.loadBabies(userId: userId)
            }
        }
    }

    // MARK: - Onboarding

    private var onboardingView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color(hex: "FF9FB5"))

                Text("환영합니다!")
                    .font(.title.weight(.bold))

                Text("아기 정보를 등록하고\n올케어를 시작해보세요")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    babyVM.showAddBaby = true
                } label: {
                    Text("아기 등록하기")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "FF9FB5"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .sheet(isPresented: Bindable(babyVM).showAddBaby) {
                AddBabyView()
            }
        }
    }

    // MARK: - Main Tab View (홈 | 기록 | + | 건강 | 설정)

    private var mainTabView: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("홈", systemImage: "house.fill")
                    }
                    .tag(0)

                CalendarView()
                    .tabItem {
                        Label("기록", systemImage: "calendar")
                    }
                    .tag(1)

                Color.clear
                    .tabItem {
                        Label("기록", systemImage: "plus.circle.fill")
                    }
                    .tag(2)

                HealthView()
                    .tabItem {
                        Label("건강", systemImage: "heart.text.clipboard.fill")
                    }
                    .tag(3)

                SettingsView()
                    .tabItem {
                        Label("설정", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 2 {
                    selectedTab = oldValue
                    showRecording = true
                }
            }

            // 중앙 플로팅 + 버튼
            Button {
                showRecording = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "FF9FB5"), Color(hex: "FFB5C2")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(hex: "FF9FB5").opacity(0.4), radius: 8, y: 4)
                    )
            }
            .offset(y: -20)
        }
        .sheet(isPresented: $showRecording) {
            RecordingView()
        }
    }
}
