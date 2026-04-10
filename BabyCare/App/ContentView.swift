import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(ProductViewModel.self) private var productVM
    @State private var selectedTab: Int = {
        if let tabArg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("UI_TESTING_TAB=") }),
           let tab = Int(tabArg.replacingOccurrences(of: "UI_TESTING_TAB=", with: "")) {
            return tab
        }
        return 0
    }()
    @State private var showRecording = false
    @State private var initialRecordingCategory: Activity.ActivityCategory?
    @State private var reorderProduct: BabyProduct?

    @Binding var deepLinkDestination: DeepLinkRouter.Destination?

    private let networkMonitor = NetworkMonitor.shared
    private let offlineQueue = OfflineQueue.shared

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

            if offlineQueue.pendingCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                    Text("\(offlineQueue.pendingCount)개 기록 동기화 대기 중")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.8))
            }

            Group {
                if authVM.isAuthenticated {
                    if !babyVM.hasInitialLoad {
                        // 런치스크린과 동일한 빈 화면 — 사용자가 전환을 눈치채지 못함
                        Color(.systemBackground)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if babyVM.babies.isEmpty {
                        onboardingView
                    } else {
                        mainTabView
                    }
                } else {
                    LoginView()
                }
            }
            .animation(.easeIn(duration: 0.25), value: babyVM.hasInitialLoad)
        }
        .task {
            // 강제 종료 전 진행 중이던 타이머 복구
            activityVM.resumeTimerIfNeeded()
            if let userId = authVM.currentUserId {
                await authVM.migrateFamilySharingIfNeeded(userId: userId)
                await babyVM.loadBabies(userId: userId)
                // Analytics: User Properties 초기 설정
                AnalyticsService.shared.updateUserProperties(
                    babyCount: babyVM.babies.count,
                    familySharingEnabled: babyVM.babies.contains { $0.ownerUserId != userId },
                    theme: ThemeManager.shared.currentMode.rawValue
                )
            }
        }
        .onChange(of: authVM.isAuthenticated) { _, isAuth in
            if isAuth, let userId = authVM.currentUserId {
                Task {
                    await authVM.migrateFamilySharingIfNeeded(userId: userId)
                    await babyVM.loadBabies(userId: userId)
                }
            }
        }
        .onChange(of: deepLinkDestination) { _, destination in
            guard let destination else { return }
            handleDeepLink(destination)
            deepLinkDestination = nil
        }
        .onReceive(NotificationRouter.shared.$pendingDestination) { destination in
            guard let destination else { return }
            handleNotificationDestination(destination)
            NotificationRouter.shared.pendingDestination = nil
        }
        .sheet(item: $reorderProduct) { product in
            NavigationStack {
                ProductDetailView(product: product)
            }
        }
    }

    // MARK: - Notification Routing

    private func handleNotificationDestination(_ destination: NotificationRouter.Destination) {
        guard authVM.isAuthenticated else { return }

        switch destination {
        case .dashboard:
            selectedTab = 0

        case .announcements:
            selectedTab = 4 // 설정 탭

        case .reorderProduct(let productId, let coupangURLString):
            if let urlString = coupangURLString, let url = URL(string: urlString) {
                // 쿠팡 URL이 있으면 Safari 직접 열기 (가장 빠른 구매 경로)
                UIApplication.shared.open(url)
            } else {
                // 쿠팡 URL 없으면 용품 상세 화면으로 이동
                if let product = productVM.products.first(where: { $0.id == productId }) {
                    reorderProduct = product
                }
            }
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ destination: DeepLinkRouter.Destination) {
        guard authVM.isAuthenticated, !babyVM.babies.isEmpty else { return }

        switch destination {
        case .record:
            initialRecordingCategory = nil
            showRecording = true

        case .recordCategory(let category):
            switch category {
            case .feeding: initialRecordingCategory = .feeding
            case .sleep:   initialRecordingCategory = .sleep
            case .diaper:  initialRecordingCategory = .diaper
            }
            showRecording = true

        case .quickSave(let quickType):
            guard let currentUserId = authVM.currentUserId,
                  let baby = babyVM.selectedBaby else { return }
            let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
            let activityType: Activity.ActivityType = switch quickType {
            case .feedingBreast: .feedingBreast
            case .diaperWet: .diaperWet
            }
            Task {
                await activityVM.quickSave(userId: dataUserId, babyId: baby.id, type: activityType)
                activityVM.syncWidgetData(babyName: baby.name, babyAge: baby.ageText)
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
                    .foregroundStyle(AppColors.primaryAccent)

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
                        .background(AppColors.primaryAccent)
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

            // 중간 자리: 빈 뷰 (+ 버튼 역할)
            Color.clear
                .tabItem {
                    Label("기록하기", systemImage: "plus.circle.fill")
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
                // + 탭 선택 → sheet 열고 이전 탭으로 복원
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedTab = oldValue
                initialRecordingCategory = nil
                showRecording = true
            } else {
                // 탭 전환 페이지뷰 트래킹
                let screenNames = [0: AnalyticsScreens.dashboard, 1: AnalyticsScreens.calendar,
                                   3: AnalyticsScreens.health, 4: AnalyticsScreens.settings]
                if let screenName = screenNames[newValue] {
                    AnalyticsService.shared.trackScreen(screenName)
                }
            }
        }
        .sheet(isPresented: $showRecording, onDismiss: {
            activityVM.resetForm()
            initialRecordingCategory = nil
        }) {
            RecordingView(isPresented: $showRecording, initialCategory: initialRecordingCategory)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                FloatingTimerBanner { category in
                    initialRecordingCategory = category
                    showRecording = true
                }
                FloatingMiniPlayer()
                if AdExperimentVariant.currentVariant.shouldShowBanner(forTab: selectedTab) {
                    AdBannerView()
                        .frame(height: AdBannerView.currentBannerHeight())
                }
            }
            .padding(.bottom, 52) // TabBar 위
        }
    }
}
