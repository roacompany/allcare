import SwiftUI

/// Apple Health "Favorites" 카드 1:1 visual.
///
/// 레이아웃 (HStack: 좌 content / 우 chevron):
/// - title row: icon(systemTint, 14pt semibold) + name(.subheadline.semibold, 시맨틱 색)
/// - big value: 34pt rounded bold + unit(.subheadline secondary)
/// - supporting caption (secondary)
/// - chevron right (.tertiary)
/// - background: secondarySystemGroupedBackground (Apple Health 카드 배경)
/// - radius: 12 / padding: 16 / minHeight: 120
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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }

                Spacer(minLength: 6)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let unit = unit {
                        Text(unit)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let supporting = supporting {
                    Text(supporting)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                VStack(spacing: 12) {
                    HealthStyleFavoriteCard(
                        icon: "drop.fill", title: "수유", value: "8", unit: "회",
                        supporting: "오늘, 1시간 전 · 480ml",
                        tint: AppColors.feedingColor
                    )
                    HealthStyleFavoriteCard(
                        icon: "moon.zzz.fill", title: "수면", value: "5h 32m",
                        supporting: "마지막 깸 4시간 전",
                        tint: AppColors.sleepColor
                    )
                    HealthStyleFavoriteCard(
                        icon: "humidity.fill", title: "기저귀", value: "6", unit: "회",
                        supporting: "마지막 30분 전 · 대변",
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
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                VStack(spacing: 12) {
                    HealthStyleFavoriteCard(
                        icon: "drop.fill", title: "수유", value: "8", unit: "회",
                        supporting: "오늘, 1시간 전 · 480ml",
                        tint: AppColors.feedingColor
                    )
                    HealthStyleFavoriteCard(
                        icon: "moon.zzz.fill", title: "수면", value: "5h 32m",
                        supporting: "마지막 깸 4시간 전",
                        tint: AppColors.sleepColor
                    )
                }
            }
            .padding(16)
        }
    }
    .preferredColorScheme(.dark)
}
