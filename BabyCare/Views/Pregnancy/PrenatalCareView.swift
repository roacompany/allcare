import SwiftUI

/// ③ 검진 탭 루트 (서브프로젝트 5).
/// Phase A = 면책 배너 + 🔴 한국 산전검진 타임라인(주차 자동 매핑).
/// 후속 Phase: 다음 검진 히어로 카드 · 국민행복카드 바우처 · 산모수첩 디지털 미러 ·
/// 주차별 체크리스트 · 진료 준비 질문 메모 · 음식 안전 조회. (SCREENS.md §③검진)
@MainActor
struct PrenatalCareView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM

    private var currentWeek: Int? { pregnancyVM.currentWeekAndDay?.weeks }

    var body: some View {
        ScrollView {
            VStack(spacing: DS2.Spacing.xl) {
                PrenatalDisclaimerBanner()
                KoreanPrenatalTimelineCard(currentWeek: currentWeek)
                upcomingNote
            }
            .padding(.horizontal, DS2.Spacing.lg)
            .padding(.vertical, DS2.Spacing.lg)
        }
        .navigationTitle("검진")
        .navigationBarTitleDisplayMode(.large)
    }

    /// 후속 Phase 진행 안내(빈 화면 금지 원칙은 타임라인이 충족 — 이건 가벼운 표시 1줄).
    private var upcomingNote: some View {
        HStack(spacing: DS2.Spacing.sm) {
            Image(systemName: "hourglass")
                .font(.caption)
                .foregroundStyle(DS2.Color.pregnancy.opacity(0.6))
            Text("다음 검진 알림·국민행복카드·산모수첩은 순차 제공돼요.")
                .font(DS2.Font.caption2)
                .foregroundStyle(DS2.Color.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS2.Spacing.xs)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        PrenatalCareView()
    }
    .environment(PregnancyViewModel())
    .tint(DS2.Color.pregnancy)
}
#endif
