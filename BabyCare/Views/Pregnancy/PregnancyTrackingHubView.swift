import SwiftUI

// TODO(v3 서브프로젝트 4): 기록·추적 허브 구현.
// 최종 목표: 세그먼트 컨트롤(매일 도구/상태별/선택 모듈) + 오늘 요약 스트립 +
// 태동 카운터·체중 그래프·증상/기분 스탬프·혈압/혈당·진통 타이머·약/수분/수면 선택 모듈 카드 그리드.
// PregnancyRecordingSheets(KickRecordingSheet·WeightEntrySheet·SymptomMemoSheet) 재사용 예정.
// SCREENS.md §②기록 참조.

/// ② 기록·추적 허브 탭 루트 (서브프로젝트 4 구현 예정).
@MainActor
struct PregnancyTrackingHubView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM

    var body: some View {
        ScrollView {
            VStack(spacing: DS2.Spacing.xl) {
                DS2EmptyState(
                    icon: "square.and.pencil",
                    title: "기록",
                    message: "곧 제공됩니다\n태동·체중·증상·혈압·혈당·진통 타이머를 한 곳에서 기록해요."
                )

                comingSoonList
            }
            .padding(.horizontal, DS2.Spacing.lg)
            .padding(.top, DS2.Spacing.xl)
        }
        .navigationTitle("기록")
        .navigationBarTitleDisplayMode(.large)
    }

    private var comingSoonList: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                Text("구현 예정")
                    .font(DS2.Font.headline)
                    .foregroundStyle(DS2.Color.pregnancy)

                let features = [
                    "[매일 도구] 태동 카운터 (ACOG 2h/10회 기준)",
                    "[매일 도구] 체중 + 증가 그래프 (Korean BMI 밴드)",
                    "[매일 도구] 증상/기분 스탬프 (주차별 추천칩)",
                    "[상태별] 혈압/혈당 (임당 목표선 RuleMark)",
                    "[상태별] 진통 간격 타이머 (5-1-1 규칙)",
                    "[선택 모듈] 약 복용·수분·수면 토글 카드",
                    "오늘 요약 스트립 (기록 개수 칩)",
                    "저장 시 ① 여정 해당 주차 카드 자동 역류"
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
        PregnancyTrackingHubView()
    }
    .environment(PregnancyViewModel())
    .tint(DS2.Color.pregnancy)
}
#endif
