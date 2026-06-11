import SwiftUI

// TODO(v3 서브프로젝트 5): 더보기 탭 구현.
// 최종 목표: 섹션 접어 묶기 — 도구함(예정일계산·출산준비물·출산가방·출산계획서·이름짓기·다태아·위젯) +
// 콘텐츠 서가(발달일러스트·감수아티클·태교음악/동화·운동/요가·영양가이드/영양제) +
// 정서·추억(임신일기·만삭타임랩스·초음파타임라인·아기편지/태담) +
// 함께보기(부부/가족 초대코드·응원/태담 스탬프) + 커뮤니티 + 공간설정(알림·임신정보수정·출산/종료전환).
// SCREENS.md §④더보기 참조. 비대화 방지를 위해 섹션 접어 묶기 필수.

/// ④ 더보기 탭 루트 (서브프로젝트 5 구현 예정).
@MainActor
struct PregnancyMoreView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM

    var body: some View {
        ScrollView {
            VStack(spacing: DS2.Spacing.xl) {
                DS2EmptyState(
                    icon: "ellipsis.circle",
                    title: "더보기",
                    message: "곧 제공됩니다\n도구함, 콘텐츠 서가, 추억, 함께보기, 공간설정이 여기에 모여요."
                )

                comingSoonList
            }
            .padding(.horizontal, DS2.Spacing.lg)
            .padding(.top, DS2.Spacing.xl)
        }
        .navigationTitle("더보기")
        .navigationBarTitleDisplayMode(.large)
    }

    private var comingSoonList: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                Text("구현 예정")
                    .font(DS2.Font.headline)
                    .foregroundStyle(DS2.Color.pregnancy)

                let sections: [(header: String, items: [String])] = [
                    ("도구함 (1회성)", ["예정일 계산기", "출산 준비물·가방", "출산 계획서", "이름 짓기", "다태아 안내", "D-day 위젯"]),
                    ("콘텐츠 서가", ["주차별 발달 일러스트·감수아티클", "태교음악·동화", "운동·요가 가이드", "영양 가이드·영양제"]),
                    ("정서·추억", ["임신 일기", "만삭 타임랩스", "초음파 타임라인", "아기편지·태담"]),
                    ("함께보기", ["부부/가족 초대코드", "응원·태담 스탬프"]),
                    ("공간설정", ["알림 절제(주차/검진/태동)", "임신 정보 수정", "출산·종료 전환"])
                ]

                ForEach(sections, id: \.header) { section in
                    VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                        Text(section.header)
                            .font(DS2.Font.caption.weight(.semibold))
                            .foregroundStyle(DS2.Color.pregnancy)

                        ForEach(section.items, id: \.self) { item in
                            HStack(spacing: DS2.Spacing.sm) {
                                Image(systemName: "circle")
                                    .font(.caption2)
                                    .foregroundStyle(DS2.Color.pregnancy.opacity(0.5))
                                Text(item)
                                    .font(DS2.Font.caption)
                                    .foregroundStyle(DS2.Color.textSecondary)
                            }
                        }
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
        PregnancyMoreView()
    }
    .environment(PregnancyViewModel())
    .tint(DS2.Color.pregnancy)
}
#endif
