import SwiftUI

/// ① 여정 탭 루트 — 주차 타임라인 척추 (SCREENS.md §①여정).
/// "오늘" 섹션(데일리팁·크기비교·QuickLog·동적승격·체크리스트) + 미래 검진 마일스톤 + 면책.
/// 과거 주차 응집 카드(초음파/일기 썸네일)는 후속 플랜(D 정서기록 의존).
@MainActor
struct PregnancyJourneyView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM

    private let weekStore = PregnancyWeekContentStore.loadBundled()

    @State private var activeSheet: JourneySheet?
    @State private var showTransitionSheet = false
    @State private var showChecklist = false

    private enum JourneySheet: Int, Identifiable {
        case kick, weight, symptom
        var id: Int { rawValue }
    }

    private var content: PregnancyJourneyContent {
        PregnancyJourneyContent(
            currentWeek: pregnancyVM.currentWeekAndDay?.weeks,
            checklistItems: pregnancyVM.checklistItems,
            prenatalVisits: pregnancyVM.prenatalVisits
        )
    }

    private var weekContent: PregnancyWeekContent? {
        guard let week = pregnancyVM.currentWeekAndDay?.weeks else { return nil }
        return weekStore.content(forWeek: week)
    }

    private var isMultiFetus: Bool {
        (pregnancyVM.activePregnancy?.fetusCount ?? 1) > 1
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DS2.Spacing.lg, pinnedViews: [.sectionHeaders]) {
                Section {
                    todaySection
                    futureSection
                    JourneyDisclaimerBanner(multiFetus: isMultiFetus)
                } header: {
                    JourneyStickyHeader(
                        weekAndDay: pregnancyVM.currentWeekAndDay,
                        dDay: pregnancyVM.dDay
                    )
                }
            }
            .padding(.horizontal, DS2.Spacing.lg)
            .padding(.bottom, DS2.Spacing.xl)
        }
        .navigationTitle("여정")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showChecklist) {
            PregnancyChecklistView()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .kick: KickRecordingSheet()
            case .weight: PregnancyWeightEntrySheet()
            case .symptom: PregnancySymptomMemoSheet()
            }
        }
        .sheet(isPresented: $showTransitionSheet) {
            if let pregnancy = pregnancyVM.activePregnancy {
                PregnancyTransitionSheet(pregnancy: pregnancy)
            }
        }
    }

    // MARK: - 오늘 섹션

    @ViewBuilder private var todaySection: some View {
        if let wc = weekContent {
            DailyTipCard(tip: wc.tip)
            BabySizeCompareCard(week: wc.week, fruitSize: wc.fruitSize, milestone: wc.milestone)
        }

        JourneyQuickLogStrip(
            onKick: { activeSheet = .kick },
            onSymptom: { activeSheet = .symptom },
            onWeight: { activeSheet = .weight }
        )

        ForEach(Array(content.promotedCards.enumerated()), id: \.offset) { _, card in
            // 검진/진통 타이머 상세 화면은 후속(③ PrenatalCareView 콘텐츠·ContractionTimerView 미구현).
            JourneyPromotedCardView(card: card, action: {})
        }

        if !content.topIncompleteChecklist.isEmpty {
            ChecklistPreviewCard(items: content.topIncompleteChecklist, onSeeAll: { showChecklist = true })
        }

        if pregnancyVM.dDay != nil {
            birthCTABanner
        }
    }

    // MARK: - 미래 섹션

    @ViewBuilder private var futureSection: some View {
        if !content.futureMilestones.isEmpty {
            VisitMilestoneList(milestones: content.futureMilestones)
        }
    }

    // MARK: - 출산 CTA

    private var birthCTABanner: some View {
        Button { showTransitionSheet = true } label: {
            HStack(spacing: DS2.Spacing.md) {
                Image(systemName: "heart.circle.fill").font(.title2).foregroundStyle(DS2.Color.pregnancy)
                VStack(alignment: .leading, spacing: 2) {
                    Text("출산했어요!").font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
                    Text("아기 정보를 등록하고 육아 모드로 전환하세요.")
                        .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.subheadline).foregroundStyle(.tertiary)
            }
            .padding(DS2.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS2.Color.pregnancy.opacity(0.12), in: RoundedRectangle(cornerRadius: DS2.Radius.md))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let vm = PregnancyViewModel()
    vm.activePregnancy = Pregnancy(
        lmpDate: Calendar.current.date(byAdding: .day, value: -168, to: Date()),
        dueDate: Calendar.current.date(byAdding: .day, value: 112, to: Date()),
        fetusCount: 1, babyNickname: "둘째"
    )
    return NavigationStack { PregnancyJourneyView() }
        .environment(vm)
        .environment(AuthViewModel())
        .tint(DS2.Color.pregnancy)
}
#endif
