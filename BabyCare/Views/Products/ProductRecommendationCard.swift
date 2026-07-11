import SwiftUI

// MARK: - ProductRecommendationCard

/// 대시보드/제품 탭 공용 추천 카드.
/// Views → Services 직접 참조 금지. ViewModel을 통해 URL을 받아 표시합니다.
struct ProductRecommendationCard: View {
    let recommendation: ProductRecommendation
    let onTapCoupang: (URL) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 아이콘
            Image(systemName: recommendation.icon ?? recommendation.category.icon)
                .font(.title3)
                .foregroundStyle(AppColors.primaryAccent)
                .frame(width: 40, height: 40)
                .background(AppColors.primaryAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(recommendation.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if let reason = recommendation.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let start = recommendation.ageRangeStart, let end = recommendation.ageRangeEnd {
                    Text(
                        String(
                            format: NSLocalizedString("product.recommend.age.range", comment: ""),
                            start,
                            end
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // 쿠팡 바로가기 버튼
            Button {
                let url = CoupangAffiliateService.deepLink(
                    productName: recommendation.name,
                    keyword: recommendation.coupangKeyword
                )
                if let url {
                    onTapCoupang(url)
                }
            } label: {
                Image(systemName: "cart.badge.plus")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.primaryAccent)
                    .padding(8)
                    .background(AppColors.primaryAccent.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

