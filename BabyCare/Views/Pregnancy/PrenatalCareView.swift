import SwiftUI

/// ③ 검진 탭 루트 (서브프로젝트 5).
/// Phase A = 면책 + 한국 산전검진 타임라인. Phase B = 다음 검진 히어로 + 타임라인 노드 탭→검진 추가(프리필).
/// 후속 Phase: 산모수첩 미러 · 국민행복카드 바우처 · 체크리스트 · 진료준비 질문 · 음식 안전. (SCREENS.md §③검진)
@MainActor
struct PrenatalCareView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var formPrefill: VisitFormPrefill?

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

                KoreanPrenatalTimelineCard(currentWeek: currentWeek) { item in
                    formPrefill = VisitFormPrefill(
                        visitType: item.visitTypeHint,
                        date: PrenatalVisitPlanner.suggestedDate(for: item, lmpDate: pregnancyVM.activePregnancy?.lmpDate)
                    )
                }

                upcomingNote
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
    }

    /// 후속 Phase 진행 안내(빈 화면 금지 원칙은 히어로·타임라인이 충족 — 1줄 표시).
    private var upcomingNote: some View {
        HStack(spacing: DS2.Spacing.sm) {
            Image(systemName: "hourglass")
                .font(.caption)
                .foregroundStyle(DS2.Color.pregnancy.opacity(0.6))
            Text("산모수첩·국민행복카드·체크리스트는 순차 제공돼요.")
                .font(DS2.Font.caption2)
                .foregroundStyle(DS2.Color.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS2.Spacing.xs)
    }

    private func toggleNextVisit() {
        guard let visit = nextVisit, let owner = ownerUserId else { return }
        Task { await pregnancyVM.togglePrenatalVisit(visit, userId: owner) }
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
