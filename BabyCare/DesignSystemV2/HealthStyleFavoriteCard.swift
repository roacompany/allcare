import SwiftUI

/// Apple Health "Summary > Favorites" 카드 정확 spec 기반 (Agent 외부 리서치 결과).
///
/// 핵심 (Apple HIG + sarunw.com Dark Color Cheat Sheet + WWDC25 Session 323):
/// - 카드 배경: **solid** `Color(.secondarySystemGroupedBackground)` — material 금지
/// - radius: 12pt (iOS 17~18 inset grouped 패턴)
/// - padding: 16pt
/// - minHeight: ~84pt (sparkline 없는 경우)
/// - shadow 없음
/// - icon: 13pt SF Symbol + semantic tint
/// - title: `.footnote.semibold` + 같은 tint
/// - value: 28pt rounded .semibold + primary
/// - unit: .footnote + secondary
/// - supporting: .caption2 + tertiary
/// - chevron: 12pt + tertiary
struct HealthStyleFavoriteCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String?
    let supporting: String?
    let tint: Color

    init(
        icon: String,
        title: String,
        value: String,
        unit: String? = nil,
        supporting: String? = nil,
        tint: Color
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.unit = unit
        self.supporting = supporting
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS2.Spacing.md) {
            VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                // Title row
                HStack(spacing: 5) {  // Apple Health spec: 5pt off-grid (icon-title), 의도적 비-토큰 (DESIGN.md §3)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint)
                }

                // Big value
                HStack(alignment: .firstTextBaseline, spacing: 3) {  // Apple Health spec: 3pt off-grid baseline gap, 의도적 비-토큰
                    Text(value)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let unit = unit {
                        Text(unit)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                // Supporting (timestamp)
                if let supporting = supporting {
                    Text(supporting)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(DS2.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)  // 84: Apple Health 카드 높이 spec
        .background(Color(.secondarySystemGroupedBackground))  // Apple HIG inset-grouped 강제 (DESIGN.md §3)
        .clipShape(RoundedRectangle(cornerRadius: DS2.Radius.sm, style: .continuous))
    }
}

#Preview("Apple Health Favorites — Light") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("관심 항목")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text("전체 보기")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                VStack(spacing: 12) {
                    HealthStyleFavoriteCard(
                        icon: "drop.fill", title: "수유", value: "8", unit: "회",
                        supporting: "오늘, 오후 1:23 · 480ml",
                        tint: AppColors.feedingColor
                    )
                    HealthStyleFavoriteCard(
                        icon: "moon.zzz.fill", title: "수면", value: "5h 32m",
                        supporting: "오늘, 오전 6:00",
                        tint: AppColors.sleepColor
                    )
                    HealthStyleFavoriteCard(
                        icon: "humidity.fill", title: "기저귀", value: "6", unit: "회",
                        supporting: "오늘, 오후 1:54",
                        tint: AppColors.diaperColor
                    )
                }
            }
            .padding(16)
        }
    }
}

#Preview("Apple Health Favorites — Dark") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("관심 항목")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text("전체 보기")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                VStack(spacing: 12) {
                    HealthStyleFavoriteCard(
                        icon: "drop.fill", title: "수유", value: "8", unit: "회",
                        supporting: "오늘, 오후 1:23 · 480ml",
                        tint: AppColors.feedingColor
                    )
                    HealthStyleFavoriteCard(
                        icon: "moon.zzz.fill", title: "수면", value: "5h 32m",
                        supporting: "오늘, 오전 6:00",
                        tint: AppColors.sleepColor
                    )
                }
            }
            .padding(16)
        }
    }
    .preferredColorScheme(.dark)
}
