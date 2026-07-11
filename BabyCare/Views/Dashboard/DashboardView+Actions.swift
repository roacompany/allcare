import SwiftUI
import UserNotifications

extension DashboardView {
    // MARK: - Actions

    func loadData() async {
        guard let currentUserId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId

        // 알림 권한 요청 — 데이터 로딩을 차단하지 않도록 별도 Task
        Task {
            do {
                _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            } catch {
                logSilent("알림 권한 요청 실패", error: error, logger: AppLogger.push)
            }
        }

        // 아기 월령을 수유 예측에 반영
        let ageMonths = Calendar.current.dateComponents([.month], from: baby.birthDate, to: Date()).month ?? 3
        activityVM.babyAgeInMonths = ageMonths

        // 병렬 로딩: 활동 + 건강 + 용품 + 공지
        async let loadActivities: Void = activityVM.loadTodayActivities(userId: dataUserId, babyId: baby.id)
        async let loadHealth: Void = healthVM.loadAll(userId: dataUserId, babyId: baby.id, babyName: baby.name)
        async let loadProducts: Void = productVM.loadProducts(userId: currentUserId)
        async let loadAnnouncements: Void = announcementVM.loadAnnouncements()

        _ = await (loadActivities, loadHealth, loadProducts, loadAnnouncements)

        // 스케줄 자동 생성 (필요 시)
        await healthVM.generateScheduleIfNeeded(
            babyId: baby.id,
            birthDate: baby.birthDate,
            userId: dataUserId,
            babyName: baby.name
        )

        // 위젯 데이터 동기화
        activityVM.syncWidgetData(babyName: baby.name, babyAge: baby.ageText)

        // 인사이트 카드 갱신
        insightService.refresh(
            todayActivities: activityVM.todayActivities,
            recentActivities: activityVM.recentWeekActivities,
            recentTemperatureActivities: activityVM.recentTemperatureActivities,
            baby: babyVM.selectedBaby,
            pendingMilestones: healthVM.pendingMilestones,
            upcomingVaccinations: healthVM.upcomingVaccinations
        )
    }

    func quickSave(type: Activity.ActivityType) async {
        // 상세 입력이 필요한 타입은 통합 기록 시트로 (RecordEntryRule 단일 정책 — 기존 needsQuickInput 대체)
        if RecordEntryRule.mode(for: type) == .detail {
            quickInputType = type
            return
        }

        guard let currentUserId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        await activityVM.quickSave(userId: dataUserId, currentUserId: currentUserId, babyId: baby.id, type: type)
        if activityVM.errorMessage == nil {
            // 저장 성공 후 발화. category = 영어 rawValue (한글 displayName 금지 — GA4 차원 파편화)
            AnalyticsService.shared.trackEvent(AnalyticsEvents.dashboardQuickRecord, parameters: [AnalyticsParams.category: type.rawValue])
        }

        showSavedFeedback(for: type)

        if let candidates = await productVM.deductStockForActivity(type, userId: currentUserId) {
            productCandidates = candidates
        }
    }

    /// 저장 성공 피드백 — 햅틱 + 대시보드 토스트(savedActivityType). 그리드 즉시저장 + 통합 시트 공용.
    func showSavedFeedback(for type: Activity.ActivityType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        lastSavedActivity = activityVM.todayActivities.first
        withAnimation(.spring(duration: 0.3)) {
            savedActivityType = type
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { savedActivityType = nil; lastSavedActivity = nil }
        }
    }

}
