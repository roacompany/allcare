import SwiftUI

/// ③ 검진 탭 루트 (서브프로젝트 5).
/// A=면책+타임라인 · B=다음 검진 히어로+노드→검진 추가 · C=산모수첩 미러+국민행복카드 바우처.
/// 후속 Phase D: 주차별 체크리스트 · 진료준비 질문 · 음식 안전. (SCREENS.md §③검진)
@MainActor
struct PrenatalCareView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var formPrefill: VisitFormPrefill?
    @State private var showMirrorDetail = false
    @State private var showFoodSafety = false

    /// 검진 추가 시트 프리필(빈 값 = 빈 폼). Identifiable 로 .sheet(item:) 트리거.
    private struct VisitFormPrefill: Identifiable {
        let id = UUID()
        let visitType: String?
        let date: Date?
    }

    private var currentWeek: Int? { pregnancyVM.currentWeekAndDay?.weeks }

    private var nextVisit: PrenatalVisit? {
        PrenatalVisitPlanner.nextRelevantVisit(in: pregnancyVM.prenatalVisits)
    }

    private var recommendedItem: KoreanPrenatalScheduleItem? {
        KoreanPrenatalSchedule.currentItem(currentWeek: currentWeek)
    }

    private var mirrorMeasurements: [MaternalMeasurement] {
        MaternalRecordMirror.latestMeasurements(vitals: pregnancyVM.vitalEntries, weights: pregnancyVM.weightEntries)
    }

    private var checklistItems: [PregnancyChecklistItem] { pregnancyVM.checklistItems }

    private var weeklyHighlights: [PregnancyChecklistItem] {
        PregnancyChecklistPlanner.weeklyHighlights(checklistItems, currentWeek: currentWeek, limit: 3)
    }

    /// 공유 임신 데이터는 소유자 path 로 저장(#19/#41) — authVM.currentUserId 직접 전달 금지.
    private var ownerUserId: String? {
        pregnancyVM.dataUserId(currentUserId: authVM.currentUserId)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS2.Spacing.xl) {
                PrenatalDisclaimerBanner()

                NextVisitHeroCard(
                    visit: nextVisit,
                    recommendedItem: recommendedItem,
                    onAdd: { formPrefill = VisitFormPrefill(visitType: nil, date: nil) },
                    onToggleComplete: toggleNextVisit
                )

                KoreanPrenatalTimelineCard(
                    currentWeek: currentWeek,
                    visits: pregnancyVM.prenatalVisits,
                    lmpDate: pregnancyVM.activePregnancy?.lmpDate
                ) { item in
                    formPrefill = VisitFormPrefill(
                        visitType: item.visitTypeHint,
                        date: PrenatalVisitPlanner.suggestedDate(for: item, lmpDate: pregnancyVM.activePregnancy?.lmpDate)
                    )
                }

                HappyCardVoucherCard(
                    fetusCount: pregnancyVM.activePregnancy?.fetusCount,
                    usedAmount: pregnancyVM.activePregnancy?.voucherUsedAmount,
                    onSaveUsed: saveVoucherUsed
                )

                MaternalRecordMirrorCard(
                    measurements: mirrorMeasurements,
                    onSeeAll: { showMirrorDetail = true }
                )

                WeeklyChecklistMiniCard(
                    highlights: weeklyHighlights,
                    completedCount: checklistItems.filter { $0.isCompleted }.count,
                    totalCount: checklistItems.count,
                    completionRate: PregnancyChecklistPlanner.completionRate(checklistItems),
                    onToggle: toggleChecklist
                )

                VisitQuestionMemoCard(
                    visit: nextVisit,
                    onAdd: addQuestion,
                    onToggle: toggleQuestion,
                    onDelete: deleteQuestion
                )

                FoodSafetyQuickRow { showFoodSafety = true }
            }
            .padding(.horizontal, DS2.Spacing.lg)
            .padding(.vertical, DS2.Spacing.lg)
        }
        .navigationTitle("검진")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $formPrefill) { prefill in
            PrenatalVisitFormSheet(prefillVisitType: prefill.visitType, prefillDate: prefill.date)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showMirrorDetail) {
            MaternalRecordDetailSheet(vitals: pregnancyVM.vitalEntries, weights: pregnancyVM.weightEntries)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showFoodSafety) {
            FoodSafetySheet()
        }
    }

    // MARK: - Actions (저장은 모두 소유자 path `ownerUserId` 경유 — #41 공유 격리)

    private func toggleNextVisit() {
        guard let visit = nextVisit, let owner = ownerUserId else { return }
        Task { await pregnancyVM.togglePrenatalVisit(visit, userId: owner) }
    }

    private func toggleChecklist(_ item: PregnancyChecklistItem) {
        guard let owner = ownerUserId else { return }
        Task { await pregnancyVM.toggleChecklistItem(item, userId: owner) }
    }

    private func addQuestion(_ text: String) {
        guard let visit = nextVisit, let owner = ownerUserId else { return }
        Task { await pregnancyVM.addVisitQuestion(to: visit, text: text, userId: owner) }
    }

    private func toggleQuestion(_ question: VisitPrepQuestion) {
        guard let visit = nextVisit, let owner = ownerUserId else { return }
        Task { await pregnancyVM.toggleVisitQuestion(in: visit, questionId: question.id, userId: owner) }
    }

    private func deleteQuestion(_ question: VisitPrepQuestion) {
        guard let visit = nextVisit, let owner = ownerUserId else { return }
        Task { await pregnancyVM.deleteVisitQuestion(in: visit, questionId: question.id, userId: owner) }
    }

    private func saveVoucherUsed(_ amount: Int) {
        guard let owner = ownerUserId else { return }
        Task { await pregnancyVM.updateVoucherUsed(amount, userId: owner) }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        PrenatalCareView()
    }
    .environment(PregnancyViewModel())
    .environment(AuthViewModel())
    .tint(DS2.Color.pregnancy)
}
#endif
