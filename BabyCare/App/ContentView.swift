import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(ActivityViewModel.self) private var activityVM

    @State private var selectedTab = 0
    @State private var showRecording = false

    private let networkMonitor = NetworkMonitor.shared

    var body: some View {
        VStack(spacing: 0) {
            if !networkMonitor.isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.caption2)
                    Text("오프라인 모드 — 저장된 데이터를 표시합니다")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.orange)
            }

            Group {
                if authVM.isAuthenticated {
                    if babyVM.isLoading && babyVM.babies.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                            Text("데이터를 불러오는 중...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if babyVM.babies.isEmpty {
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
        }
        .task {
            if let userId = authVM.currentUserId {
                await babyVM.loadBabies(userId: userId)
            }
        }
        .onChange(of: authVM.isAuthenticated) { _, isAuth in
            if isAuth, let userId = authVM.currentUserId {
                Task { await babyVM.loadBabies(userId: userId) }
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

            HealthView()
                .tabItem {
                    Label("건강", systemImage: "heart.text.clipboard.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .overlay(alignment: .bottom) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showRecording = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
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
            .offset(y: -28)
        }
        .sheet(isPresented: $showRecording, onDismiss: {
            activityVM.resetForm()
        }) {
            RecordingView()
        }
    }
}
