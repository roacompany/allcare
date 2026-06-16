import SwiftUI

// TODO(v3 서브프로젝트 3): 여정 타임라인 구현.
// 최종 목표: sticky 헤더(NN주N일·D-day·40주 진행바) + "오늘" 섹션(데일리팁/크기비교/QuickLogStrip/동적승격카드/체크리스트) +
// 위로 스크롤(과거 주차 응집 카드 lazy 페이징) + 아래로 스크롤(미래 주차 콘텐츠 + 검진 마일스톤 핀) + 의료면책배너.
// DashboardPregnancyView를 이 탭으로 승격하는 방식으로 구현 예정.
// SCREENS.md §①여정 참조.

/// ① 여정 탭 루트 (서브프로젝트 3에서 DashboardPregnancyView 승격·재배치 예정).
@MainActor
struct PregnancyJourneyView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM

    var body: some View {
        ScrollView {
            VStack(spacing: DS2.Spacing.xl) {
                DS2EmptyState(
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    title: "여정",
                    message: "곧 제공됩니다\n이 주차의 기록과 다가올 마일스톤을 한눈에 볼 수 있어요."
                )

                // 예정 기능 미리보기
                comingSoonList
            }
            .padding(.horizontal, DS2.Spacing.lg)
            .padding(.top, DS2.Spacing.xl)
        }
        .navigationTitle("여정")
        .navigationBarTitleDisplayMode(.large)
    }

    private var comingSoonList: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                Text("구현 예정")
                    .font(DS2.Font.headline)
                    .foregroundStyle(DS2.Color.pregnancy)

                let features = [
                    "NN주N일 · D-day · 40주 진행바 sticky 헤더",
                    "오늘의 데일리팁 / 아기 크기 비교",
                    "QuickLogStrip (태동·증상·체중 1탭 시트)",
                    "검진 D-2 임박 / 37주+ 진통 타이머 동적 승격",
                    "미완 체크리스트 상위 3 미리보기",
                    "지난 주차 응집 카드 (초음파·일기·측정)",
                    "다가올 주차 콘텐츠 + 한국 산전검진 핀",
                    "의료 면책 배너"
                ]

                ForEach(features, id: \.self) { feature in
                    HStack(spacing: DS2.Spacing.sm) {
                        Image(systemName: "circle")
                            .font(.caption2)
                            .foregroundStyle(DS2.Color.pregnancy.opacity(0.5))
                        Text(feature)
                            .font(DS2.Font.caption)
                            .foregroundStyle(DS2.Color.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        PregnancyJourneyView()
    }
    .environment(PregnancyViewModel())
    .tint(DS2.Color.pregnancy)
}
#endif
