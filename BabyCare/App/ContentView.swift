import StoreKit
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(ProductViewModel.self) private var productVM
    @Environment(PregnancyViewModel.self) private var pregnancyVM
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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    private let reviewService = AppReviewPromptService.shared

    private let networkMonitor = NetworkMonitor.shared
    private let offlineQueue = OfflineQueue.shared

    @State private var showPregnancyOnboarding = false
    @State private var showPendingRecoveryModal = false
    @State private var showPregnancyNote = false

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
                    } else {
                        let context = AppContext.resolve(
                            babies: babyVM.babies,
                            pregnancy: pregnancyVM.activePregnancy
                        )
                        switch context {
                        case .empty:
                            onboardingView
                        case .babyOnly:
                            mainTabView
                        case .pregnancyOnly:
                            if FeatureFlags.pregnancyModeEnabled {
                                PregnancyNoteRootView(showsExitChip: false, onExit: {})
                            } else {
                                mainTabView
                            }
                        case .both:
                            mainTabView
                        }
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
                // 임신 모드 데이터 로드 + 위젯 동기화
                if FeatureFlags.pregnancyModeEnabled {
                    await pregnancyVM.loadActivePregnancy(userId: userId)
                }
                // Analytics: User Properties 초기 설정
                AnalyticsService.shared.updateUserProperties(
                    babyCount: babyVM.babies.count,
                    familySharingEnabled: babyVM.babies.contains { $0.ownerUserId != userId },
                    theme: ThemeManager.shared.currentMode.rawValue
                )
                await runBadgeBackfillIfNeeded(userId: userId)
                await FirestoreService.shared.updateLastAccessedAt(userId: userId)
            }
        }
        .onChange(of: pregnancyVM.pendingOrphan) { _, orphan in
            // DP-4: pending 1개 orphan 감지 시 모달 표시.
            // babyVM.hasInitialLoad guard: 로딩 경쟁 방지.
            if orphan != nil && babyVM.hasInitialLoad {
                showPendingRecoveryModal = true
            }
        }
        .sheet(isPresented: $showPendingRecoveryModal) {
            PregnancyRecoveryModal()
        }
        .onChange(of: authVM.isAuthenticated) { _, isAuth in
            if isAuth, let userId = authVM.currentUserId {
                Task {
                    await authVM.migrateFamilySharingIfNeeded(userId: userId)
                    await babyVM.loadBabies(userId: userId)
                    if FeatureFlags.pregnancyModeEnabled {
                        await pregnancyVM.loadActivePregnancy(userId: userId)
                    }
                    await runBadgeBackfillIfNeeded(userId: userId)
                    await FirestoreService.shared.updateLastAccessedAt(userId: userId)
                }
            } else {
                // 로그아웃/계정 전환: 이전 계정의 사용자 스코프 상태 전부 초기화(데이터 잔존 차단).
                AppState.shared.resetUserScopedState()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                presentAutoReviewIfClean()
                scheduleWeeklyInsightIfNeeded()
                // 백그라운드에서 돌아올 때 pending orphan 재체크 (PLAN P2-2)
                if babyVM.hasInitialLoad {
                    pregnancyVM.detectPendingOrphan()
                }
                if let userId = authVM.currentUserId {
                    Task { await FirestoreService.shared.updateLastAccessedAt(userId: userId) }
                }
            }
        }
        .onChange(of: reviewService.pendingTrigger) { _, _ in
            presentAutoReviewIfClean()
        }
        .onChange(of: AppState.shared.badgePresenter.current == nil) { _, _ in
            presentAutoReviewIfClean()
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

    // MARK: - App Review Prompt (초크포인트)

    /// 대기 트리거가 있고 scene 활성 + 배지 스낵바 없음일 때만, 정착 지연 후 시스템 평가 시트 1회.
    /// scene 비활성/스낵바 표시 중에는 소진하지 않고 대기(그 1샷을 허공에 날리지 않음).
    private func presentAutoReviewIfClean() {
        guard reviewService.pendingTrigger != nil else { return }
        guard scenePhase == .active else { return }
        let presenter = AppState.shared.badgePresenter
        guard presenter.current == nil, presenter.pending.isEmpty else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700)) // 스낵바 트랜지션 정착
            // 정착 지연 동안 앱이 백그라운드로 가면 그 1샷을 소진하지 않고 대기.
            // (scenePhase 캡처값은 stale → 라이브 UIApplication.applicationState 사용)
            guard UIApplication.shared.applicationState == .active else { return }
            guard presenter.current == nil, presenter.pending.isEmpty else { return }
            guard let trigger = reviewService.consumePending() else { return }
            requestReview()
            AnalyticsService.shared.trackEvent(
                AnalyticsEvents.reviewPromptRequested,
                parameters: [AnalyticsParams.trigger: trigger.rawValue, AnalyticsParams.source: "auto"]
            )
        }
    }

    // MARK: - Badge Backfill (1회 idempotent)

    private func runBadgeBackfillIfNeeded(userId: String) async {
        // 본인 소유 아기만 백필 대상 (공유 아기는 오너 측 stats에 포함되므로 오너가 백필)
        let ownedBabyIds = babyVM.babies
            .filter { $0.ownerUserId == userId }
            .map(\.id)
        guard !ownedBabyIds.isEmpty else { return }

        // 현재 루틴 최대 streak — 백필된 연속 루틴 배지 판정용
        let routines: [Routine]
        do {
            routines = try await FirestoreService.shared.fetchRoutines(userId: userId)
        } catch {
            logSilent("배지 백필용 routine 로드 실패", error: error, logger: AppLogger.firestore)
            routines = []
        }
        let maxStreak = routines.compactMap { $0.currentStreak }.max() ?? 0

        let earned = await BadgeEvaluator().backfillIfNeeded(
            userId: userId,
            ownedBabyIds: ownedBabyIds,
            currentRoutineMaxStreak: maxStreak
        )
        AppState.shared.badgePresenter.enqueue(earned)
    }

    // MARK: - Weekly Insight

    private func scheduleWeeklyInsightIfNeeded() {
        let calendar = Calendar.current
        guard calendar.component(.weekday, from: Date()) == 2 else { return }
        let today = calendar.startOfDay(for: Date())
        guard ActivityReminderSettings.lastWeeklyInsightDate != today else { return }
        NotificationService.shared.scheduleWeeklyInsight(topInsightTitle: "지난주 육아 패턴 변화를 확인해보세요")
        ActivityReminderSettings.lastWeeklyInsightDate = today
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
                await activityVM.quickSave(userId: dataUserId, currentUserId: currentUserId, babyId: baby.id, type: activityType)
                activityVM.syncWidgetData(babyName: baby.name, babyAge: baby.ageText)
            }
        }
    }

    // MARK: - Onboarding

    private var onboardingView: some View {
        onboardingViewV2
    }

    /// DS2 V2: 위계 명확 (primary CTA + secondary) + brand wordmark + 8pt grid spacing.
    private var onboardingViewV2: some View {
        NavigationStack {
            VStack(spacing: DS2.Spacing.xl) {
                Spacer()

                // Brand
                VStack(spacing: DS2.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(DS2.Color.accent.opacity(0.12))
                            .frame(width: 120, height: 120)
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(DS2.Color.accent)
                    }
                    VStack(spacing: DS2.Spacing.xs) {
                        Text("BabyCare")
                            .font(DS2.Font.largeTitle)
                        Text("우리 아이의 소중한 순간을 기록하세요")
                            .font(DS2.Font.body)
                            .foregroundStyle(DS2.Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                // CTA (primary + secondary 위계)
                VStack(spacing: DS2.Spacing.md) {
                    DS2Button("아기 등록하기", icon: "plus.circle.fill", style: .primary) {
                        babyVM.showAddBaby = true
                    }
                    if FeatureFlags.pregnancyModeEnabled {
                        DS2Button("임신 중이에요", icon: "figure.and.child.holdinghands", style: .secondary) {
                            showPregnancyOnboarding = true
                        }
                    }
                }
                .padding(.horizontal, DS2.Spacing.xl)
                .padding(.bottom, DS2.Spacing.xxl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS2.Color.surfacePrimary.ignoresSafeArea())
            .sheet(isPresented: Bindable(babyVM).showAddBaby) {
                AddBabyView()
            }
            .sheet(isPresented: $showPregnancyOnboarding) {
                PregnancyRegistrationView()
            }
        }
    }

    // MARK: - Main Tab View (홈 | 기록 | + | 건강 | 설정)

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .onAppear {
                    // screen_view는 탭 루트 onAppear로 일원화 — 앱 시작 첫 노출(기본 탭)도 계측됨
                    AnalyticsService.shared.trackScreen(AnalyticsScreens.dashboard)
                }
                .tabItem {
                    Label("홈", systemImage: "house.fill")
                }
                .tag(0)

            CalendarView()
                .onAppear {
                    AnalyticsService.shared.trackScreen(AnalyticsScreens.calendar)
                }
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
                .onAppear {
                    AnalyticsService.shared.trackScreen(AnalyticsScreens.health)
                }
                .tabItem {
                    Label("건강", systemImage: "heart.text.clipboard.fill")
                }
                .tag(3)

            SettingsView()
                .onAppear {
                    AnalyticsService.shared.trackScreen(AnalyticsScreens.settings)
                }
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
            }
            // screen_view는 각 탭 루트의 onAppear로 일원화 (첫 진입 포함, 이중 발화 방지)
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
            }
            .padding(.bottom, 52) // TabBar 위
        }
        .overlay(alignment: .top) {
            BadgeSnackbarView(presenter: AppState.shared.badgePresenter) {
                // 설정 탭으로 이동 → 사용자가 "내 배지" row 탭하여 갤러리 진입
                selectedTab = 4
                NotificationCenter.default.post(name: .showBadgeGallery, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let showBadgeGallery = Notification.Name("showBadgeGallery")
}
