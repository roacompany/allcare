import SwiftUI

extension DashboardView {
    // MARK: - Actions

    func loadData() async {
        guard let userId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }

        // 알림 권한 요청 — 데이터 로딩을 차단하지 않도록 별도 Task
        Task { _ = await NotificationService.shared.requestPermission() }

        // 아기 월령을 수유 예측에 반영
        let ageMonths = Calendar.current.dateComponents([.month], from: baby.birthDate, to: Date()).month ?? 3
        activityVM.babyAgeInMonths = ageMonths

        // 병렬 로딩: 활동 + 건강 + 용품 + 공지
        async let loadActivities: Void = activityVM.loadTodayActivities(userId: userId, babyId: baby.id)
        async let loadHealth: Void = healthVM.loadAll(userId: userId, babyId: baby.id, babyName: baby.name)
        async let loadProducts: Void = productVM.loadProducts(userId: userId)
        async let loadAnnouncements: Void = announcementVM.loadAnnouncements()

        _ = await (loadActivities, loadHealth, loadProducts, loadAnnouncements)

        // 스케줄 자동 생성 (필요 시)
        await healthVM.generateScheduleIfNeeded(
            babyId: baby.id,
            birthDate: baby.birthDate,
            userId: userId,
            babyName: baby.name
        )

        // 위젯 데이터 동기화
        activityVM.syncWidgetData(babyName: baby.name, babyAge: baby.ageText)
    }

    func quickSave(type: Activity.ActivityType) async {
        // 추가 입력이 필요한 타입은 미니 입력 시트 표시
        if type.needsQuickInput {
            quickInputType = type
            return
        }

        guard let userId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        await activityVM.quickSave(userId: userId, babyId: baby.id, type: type)

        // 성공 피드백: 햅틱 + 토스트
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        lastSavedActivity = activityVM.todayActivities.first
        withAnimation(.spring(duration: 0.3)) {
            savedActivityType = type
        }
        // 3초 후 토스트 제거
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { savedActivityType = nil; lastSavedActivity = nil }
        }

        if let candidates = await productVM.deductStockForActivity(type, userId: userId) {
            productCandidates = candidates
        }
    }

    func quickSaveWithData(_ activity: Activity) async {
        guard let userId = authVM.currentUserId else { return }
        await activityVM.savePrebuiltActivity(activity, userId: userId)

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        lastSavedActivity = activityVM.todayActivities.first
        withAnimation(.spring(duration: 0.3)) {
            savedActivityType = activity.type
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { savedActivityType = nil; lastSavedActivity = nil }
        }
    }
}
