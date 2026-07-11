import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(ActivityViewModel.self) var activityVM
    @Environment(BabyViewModel.self) var babyVM
    @Environment(AuthViewModel.self) var authVM
    @Environment(ProductViewModel.self) var productVM
    @Environment(HealthViewModel.self) var healthVM
    @Environment(AnnouncementViewModel.self) var announcementVM
    @Environment(InsightService.self) var insightService
    @Environment(PregnancyViewModel.self) var pregnancyVM

    @State var showBabySelector = false
    @State var showTimerWarningOnSwitch = false
    @State var pendingBabySwitch: Baby?
    @State var editingActivity: Activity?
    @State var productCandidates: [BabyProduct] = []
    @State var savedActivityType: Activity.ActivityType?
    @State var lastSavedActivity: Activity?
    @State var quickInputType: Activity.ActivityType?
    @State var showMoreSection = false
    @State private var showPregnancyNote = false
    // 위젯 유도 해제 (C2) — 기기 UI 상태 (사용자 데이터 아님, @AppStorage 허용 선례: OptionalModuleToggleCard)
    @AppStorage(WidgetPromoPolicy.dismissedKey) private var widgetPromoDismissed = false
    // 파트너 초대 유도 해제 (C3) — 동일 성격의 기기 UI 상태
    @AppStorage(PartnerInvitePromoPolicy.dismissedKey) private var partnerInvitePromoDismissed = false

    // MARK: - Weekly Highlights v2
    // CR-R02: @State 기반 .task 평가는 bootstrap async와 race 가능.
    // computed property로 전환 — RC는 캐시되므로 매 render O(1), bootstrap 완료 즉시 반영.
    // FeatureFlagService cohort 사용 의도: feature flag rollout 단위로 owner userId
    // (cohort는 data path가 아니므로 babyVM.dataUserId() 불필요).
    var isHighlightV2Active: Bool {
        guard let userId = authVM.currentUserId else { return false }
        return FeatureFlagService.shared.isHighlightV2Enabled(userId: userId)
    }
    @State private var selectedHighlight: InsightCandidate?

    let feedingColor = AppColors.feedingColor
    let sleepColor = AppColors.sleepColor
    let diaperColor = AppColors.diaperColor

    let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    // MARK: - V2 Dashboard Layout
    // V2.1 정보 위계: highlightTicker 상단 (매일 새 정보) — alertBanners 직후
    // highlightGrid는 summary 후 (weekly 단위, 한 번 보면 충분)
    // spacing 14 (V1 20 대비 -30%) + summary 카드 padding 컴팩트
    @ViewBuilder
    private var dashboardV2Layout: some View {
        pregnancyPortalCardIfNeeded
        alertBannersSection
        anniversaryIfNeeded
        welcomeBackIfNeeded
        firstRecordGuideIfNeeded
        highlightTickerOrV1Card
        quickActionsSection
        predictionSection
        pregnancyHomeCardIfNeeded
        summaryCardsSection
        timelineSection
        highlightGridIfNeeded
        insightCardsSection
        BadgeHomeStrip()
        widgetPromoIfNeeded
        partnerInvitePromoIfNeeded
        reorderSummaryCard
        moreDisclosureGroup
    }

    /// 웰컴백 (C5) — 3~7일 공백 후 복귀 시. 오늘 기록이 생기면 자동 소멸.
    @ViewBuilder
    private var welcomeBackIfNeeded: some View {
        if !activityVM.isLoading,
           let gap = WelcomeBackPolicy.gapDays(
               lastRecordAt: activityVM.recentWeekActivities.map(\.startTime).max(),
               todayCount: activityVM.todayActivities.count,
               now: Date()
           ) {
            WelcomeBackCard(gapDays: gap)
        }
    }

    /// 파트너 초대 유도 (C3) — 공유 미사용 + 기록 7건+ 사용자에게 해제형 1회 안내.
    @ViewBuilder
    private var partnerInvitePromoIfNeeded: some View {
        if PartnerInvitePromoPolicy.isVisible(
            hasSharedBaby: babyVM.babies.contains { $0.ownerUserId != authVM.currentUserId },
            recordCount: activityVM.todayActivities.count + activityVM.recentWeekActivities.count,
            dismissed: partnerInvitePromoDismissed
        ) {
            PartnerInvitePromoCard {
                partnerInvitePromoDismissed = true
                AnalyticsService.shared.trackEvent(AnalyticsEvents.partnerInvitePromoDismissed)
            }
        }
    }

    /// 기념일 카운트다운 (C4) — 50일·백일·200일·300일·돌 임박(D-7) 시에만.
    @ViewBuilder
    private var anniversaryIfNeeded: some View {
        if let baby = babyVM.selectedBaby,
           let anniversary = AnniversaryPolicy.visible(birthDate: baby.birthDate, now: Date()) {
            AnniversaryCountdownCard(anniversary: anniversary, babyName: baby.name)
        }
    }

    /// 위젯 설치 유도 (C2) — 기록 습관이 생긴 사용자(3건+)에게 해제형 1회 안내.
    @ViewBuilder
    private var widgetPromoIfNeeded: some View {
        if WidgetPromoPolicy.isVisible(
            recordCount: activityVM.todayActivities.count + activityVM.recentWeekActivities.count,
            dismissed: widgetPromoDismissed
        ) {
            WidgetPromoCard {
                widgetPromoDismissed = true
                AnalyticsService.shared.trackEvent(AnalyticsEvents.widgetPromoDismissed)
            }
        }
    }

    /// 첫 기록 가이드 (이탈 방지 P0-1) — 아기 있음 + 오늘/최근 1주 기록 0 + 로딩 아님일 때만.
    @ViewBuilder
    private var firstRecordGuideIfNeeded: some View {
        if FirstRecordGuidePolicy.isVisible(
            hasSelectedBaby: babyVM.selectedBaby != nil,
            todayCount: activityVM.todayActivities.count,
            recentWeekCount: activityVM.recentWeekActivities.count,
            isLoading: activityVM.isLoading
        ) {
            FirstRecordGuideCard { type in
                Task { await quickSave(type: type) }
            }
        }
    }

    private var moreDisclosureGroup: some View {
        DisclosureGroup(isExpanded: $showMoreSection) {
            VStack(spacing: 12) {
                aiAdviceShortcut
                soundShortcutCard
            }
        } label: {
            Text("더보기")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    var body: some View {
        // 우선순위: AppContext 기반 4-state 분기.
        // .babyOnly / .both → baby 대시보드 우선. 카드는 additive.
        // .pregnancyOnly → 임신 전용 뷰.
        // .empty → ContentView가 처리 (이 분기 미도달).
        switch AppContext.resolve(babies: babyVM.babies, pregnancy: pregnancyVM.activePregnancy) {
        case .empty:
            EmptyView()
        case .babyOnly:
            babyDashboard
        case .pregnancyOnly:
            NavigationStack { DashboardPregnancyView() }
        case .both:
            babyDashboard
        }
    }

    private var babyDashboard: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    dashboardV2Layout
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .refreshable {
                await loadData()
                // 주: AI 요약 캐시는 babycare-admin Vercel Cron + Mac worker가 처리
                // (본인 Claude Code Pro 구독). iOS는 Firestore read만 수행.
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    headerView
                }
            }
        }
        .task {
            await loadData()
        }
        // CR-R02: isHighlightV2Active는 computed property로 전환됨 (.task 제거).
        // FeatureFlagService.shared가 @Observable이므로 RC 상태 변경 시 자동 invalidate.
        .sheet(item: $selectedHighlight) { candidate in
            // CR-002: Admin batch가 Firestore에 채워둔 AI summary를 sheet 열릴 때 fetch.
            // 미존재/만료 시 nil → HighlightDetailSheet 내부에서 candidate.detail fallback 표시.
            HighlightDetailSheetContainer(
                candidate: candidate,
                sparkline: insightService.sparklineData(for: candidate.metricKey),
                userId: authVM.currentUserId.flatMap { babyVM.dataUserId(currentUserId: $0) } ?? authVM.currentUserId,
                babyId: babyVM.selectedBaby?.id
            )
        }
        .sheet(item: $editingActivity) { activity in
            ActivityEditSheet(activity: activity) { updated in
                Task {
                    guard let currentUserId = authVM.currentUserId else { return }
                    let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
                    await activityVM.updateActivity(updated, userId: dataUserId)
                }
            }
            .presentationDetents([.medium])
        }
        .overlay(alignment: .top) {
            if let type = savedActivityType {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                    Text("\(type.displayName) 저장됨")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)

                    if lastSavedActivity != nil {
                        Divider()
                            .frame(height: 16)
                            .overlay(.white.opacity(0.5))
                        Button("수정") {
                            editingActivity = lastSavedActivity
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    }

                    // B4: 이어서 기록 제안 — 핵심 루프(수유→기저귀→수면) 다음 1개 원탭
                    if let nextType = NextRecordSuggestionPolicy.suggestion(after: type) {
                        Divider()
                            .frame(height: 16)
                            .overlay(.white.opacity(0.5))
                        Button {
                            AnalyticsService.shared.trackEvent(
                                AnalyticsEvents.nextRecordSuggestionTapped,
                                parameters: [AnalyticsParams.category: nextType.rawValue]
                            )
                            savedActivityType = nil
                            lastSavedActivity = nil
                            Task { await quickSave(type: nextType) }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: nextType.icon)
                                Text("\(nextType.displayName)?")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(type.color))
                        .shadow(color: Color(type.color).opacity(0.4), radius: 8, y: 4)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
        }
        .sheet(item: $quickInputType) { type in
            QuickInputSheet(type: type) { activity in
                Task { await quickSaveWithData(activity) }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: Binding(
            get: { !productCandidates.isEmpty },
            set: { if !$0 { productCandidates = [] } }
        )) {
            ProductPickerSheet(products: productCandidates) { selected in
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    await productVM.deductFromProduct(selected, userId: userId)
                }
                productCandidates = []
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showPregnancyNote) {
            PregnancyNoteRootView(showsExitChip: true, onExit: { showPregnancyNote = false })
        }
    }

    // MARK: - Weekly Highlights XOR (v1 / v2)

    /// AppContext + isHighlightV2Active 기반 XOR 분기.
    /// - `.babyOnly` / `.both` + isHighlightV2Active=true → HighlightTickerView
    /// - `.babyOnly` / `.both` + isHighlightV2Active=false → weeklyInsightsCard (v1)
    /// - `.empty` / `.pregnancyOnly` → EmptyView (v1 fallback도 숨김)
    @ViewBuilder
    private var highlightTickerOrV1Card: some View {
        // CR-007: AppContext + weights를 view 단위로 1회 캐싱.
        let appCtx = AppContext.resolve(babies: babyVM.babies, pregnancy: pregnancyVM.activePregnancy)
        let weights = InsightWeights.fromRC()
        switch appCtx {
        case .empty:
            EmptyView()
        case .pregnancyOnly:
            EmptyView()
        case .babyOnly, .both:
            if isHighlightV2Active {
                HighlightTickerView(
                    candidates: insightService.topHighlights(for: appCtx, weights: weights),
                    onCandidateSelected: { candidate in
                        selectedHighlight = candidate
                    }
                )
            } else {
                weeklyInsightsCard
            }
        }
    }

    /// summaryCardsSection 아래에 배치. V2 활성 + 적합 AppContext 시만 노출.
    @ViewBuilder
    private var highlightGridIfNeeded: some View {
        // CR-007: AppContext + weights를 view 단위로 1회 캐싱.
        let appCtx = AppContext.resolve(babies: babyVM.babies, pregnancy: pregnancyVM.activePregnancy)
        let weights = InsightWeights.fromRC()
        switch appCtx {
        case .empty:
            EmptyView()
        case .pregnancyOnly:
            EmptyView()
        case .babyOnly, .both:
            if isHighlightV2Active {
                let categories: [InsightCategory] = [.feeding, .sleep, .diaper, .health]
                let candidates = insightService.topHighlights(for: appCtx, weights: weights)
                let cards: [WeeklyHighlightGrid.CardData] = categories.map { cat in
                    let match = candidates.first { $0.category == cat }
                    return WeeklyHighlightGrid.CardData(
                        category: cat,
                        metricKey: match?.metricKey ?? cat.rawValue,
                        sparkline: insightService.sparklineData(for: match?.metricKey ?? cat.rawValue),
                        changePercent: match?.changePercent ?? 0
                    )
                }
                WeeklyHighlightGridContainer(cards: cards)
                    .accessibilityIdentifier("weeklyHighlightGrid")
            }
        }
    }

    // MARK: - Pregnancy Portal Card (임신 노트 진입, .both + flag-on)

    /// `.both` + `FeatureFlags.pregnancyModeEnabled` 시에만 홈 최상단에 임신 노트 진입 카드 삽입.
    /// flag-off 또는 .babyOnly 시 EmptyView — 기존 동작과 완전 동일.
    @ViewBuilder
    private var pregnancyPortalCardIfNeeded: some View {
        if FeatureFlags.pregnancyModeEnabled {
            switch AppContext.resolve(babies: babyVM.babies, pregnancy: pregnancyVM.activePregnancy) {
            case .both:
                PregnancyPortalCard(onTap: { showPregnancyNote = true })
            case .empty, .babyOnly, .pregnancyOnly:
                EmptyView()
            }
        }
    }

    // MARK: - Pregnancy Home Card (Additive)

    /// `.both` 컨텍스트일 때만 임신 요약 카드를 삽입. baby UI는 유지.
    @ViewBuilder
    private var pregnancyHomeCardIfNeeded: some View {
        switch AppContext.resolve(babies: babyVM.babies, pregnancy: pregnancyVM.activePregnancy) {
        case .both:
            DashboardPregnancyHomeCard()
        case .empty, .babyOnly, .pregnancyOnly:
            EmptyView()
        }
    }
}
