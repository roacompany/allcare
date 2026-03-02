import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    @State private var selectedTab = 0
    @State private var showRecording = false

    var body: some View {
        Group {
            if authVM.isAuthenticated {
                mainTabView
                    .task {
                        if let userId = authVM.currentUserId {
                            await babyVM.loadBabies(userId: userId)
                        }
                    }
            } else {
                NavigationStack {
                    LoginView()
                }
            }
        }
    }

    // MARK: - Main Tab View

    private var mainTabView: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                Tab("대시보드", systemImage: "house.fill", value: 0) {
                    DashboardView()
                }

                Tab("캘린더", systemImage: "calendar", value: 1) {
                    CalendarView()
                }

                // Spacer tab for center button
                Tab("기록", systemImage: "plus.circle.fill", value: 2) {
                    Color.clear
                }

                Tab("통계", systemImage: "chart.bar.fill", value: 3) {
                    StatsView()
                }

                Tab("더보기", systemImage: "ellipsis", value: 4) {
                    SettingsView()
                }
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 2 {
                    selectedTab = oldValue
                    showRecording = true
                }
            }

            // Center floating button
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
