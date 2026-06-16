import SwiftUI

// TODO(v3 서브프로젝트 5): 검진 탭 구현.
// 최종 목표: 다음 검진 히어로 카드(D-day 캡슐+표준매핑 칩+진료준비/완료 CTA) +
// 한국 산전검진 타임라인 자동 주차 매핑(11~13주 NT / 15~20주 정밀초음파 / 24~28주 임당 GTT) +
// 국민행복카드 바우처 잔액 카드 + 산모수첩 디지털 미러 + 주차별 체크리스트 + 진료 준비 질문 메모 + 음식 안전 조회.
// SCREENS.md §③검진 참조. 한국 산모 차별화 심장 화면.

/// ③ 검진 탭 루트 (서브프로젝트 5 구현 예정).
@MainActor
struct PrenatalCareView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM

    var body: some View {
        ScrollView {
            VStack(spacing: DS2.Spacing.xl) {
                DS2EmptyState(
                    icon: "stethoscope",
                    title: "검진",
                    message: "곧 제공됩니다\n한국 산전검진 일정·바우처·산모수첩을 한 화면에서 확인해요."
                )

                comingSoonList
            }
            .padding(.horizontal, DS2.Spacing.lg)
            .padding(.top, DS2.Spacing.xl)
        }
        .navigationTitle("검진")
        .navigationBarTitleDisplayMode(.large)
    }

    private var comingSoonList: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                Text("구현 예정")
                    .font(DS2.Font.headline)
                    .foregroundStyle(DS2.Color.pregnancy)

                let features = [
                    "다음 검진 히어로 카드 (D-day·표준매핑 칩)",
                    "🔴 한국 산전검진 타임라인 (11~13주 NT, 15~20주 정밀초음파, 24~28주 임당)",
                    "🔴 국민행복카드 바우처 잔액·안내",
                    "🔴 산모수첩 디지털 미러 (혈압·체중·자궁저높이·태아 추정체중)",
                    "주차별 체크리스트 + 완료율",
                    "진료 준비 질문 메모 (다음 검진 연결)",
                    "음식 안전 빠른 조회 (임신 중 먹어도 될까?)",
                    "의료 면책 배너 상시"
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
        PrenatalCareView()
    }
    .environment(PregnancyViewModel())
    .tint(DS2.Color.pregnancy)
}
#endif
