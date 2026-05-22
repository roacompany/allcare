import SwiftUI

/// Apple Health "Favorites" 스타일 메트릭 카드. 큰 숫자 + 활동색 dot + 보조 텍스트.
/// Dashboard V3 (Apple Health 정신) 시범 컴포넌트.
struct HealthStyleFavoriteCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String?
    let supporting: String?  // "1시간 전" / "30분 후" 등
    let tint: Color
    let chevron: Bool

    init(
        icon: String,
        title: String,
        value: String,
        unit: String? = nil,
        supporting: String? = nil,
        tint: Color,
        chevron: Bool = true
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.unit = unit
        self.supporting = supporting
        self.tint = tint
        self.chevron = chevron
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row — dot + name + chevron
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            // Big value
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let unit = unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Supporting line
            if let supporting = supporting {
                Text(supporting)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview("Favorites Grid 2x2") {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
        HealthStyleFavoriteCard(
            icon: "drop.fill", title: "수유", value: "8", unit: "회",
            supporting: "1시간 전 · 480ml",
            tint: AppColors.feedingColor
        )
        HealthStyleFavoriteCard(
            icon: "moon.zzz.fill", title: "수면", value: "5h 32m",
            supporting: "4시간 전 깸",
            tint: AppColors.sleepColor
        )
        HealthStyleFavoriteCard(
            icon: "humidity.fill", title: "기저귀", value: "6", unit: "회",
            supporting: "30분 전 · 대변",
            tint: AppColors.diaperColor
        )
        HealthStyleFavoriteCard(
            icon: "clock.badge.fill", title: "다음 수유", value: "30",
            unit: "분 후",
            supporting: "권장 간격 3h",
            tint: AppColors.warmOrangeColor
        )
    }
    .padding()
}
