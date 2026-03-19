import SwiftUI

struct RecommendedProductsSection: View {
    let product: BabyProduct
    @Binding var safariURL: URL?
    @Binding var showSafari: Bool

    private var recommendations: [RecommendedProduct] {
        Array(RecommendedProductCatalog.recommendations(for: product).prefix(3))
    }

    var body: some View {
        if !recommendations.isEmpty {
            Section {
                ForEach(recommendations) { item in
                    Button {
                        if let url = item.affiliateURL {
                            safariURL = url
                            showSafari = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: product.category.icon)
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(categoryColor(product.category))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.brand)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text(item.priceText)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("구매하기")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.accentColor))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                HStack {
                    Text("이런 상품은 어때요?")
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } footer: {
                Text("쿠팡 파트너스 활동의 일환으로 일정액의 수수료를 제공받습니다.")
                    .font(.caption2)
            }
        }
    }

    private func categoryColor(_ category: BabyProduct.ProductCategory) -> Color {
        switch category {
        case .diaper: AppColors.diaperColor
        case .formula: AppColors.feedingColor
        case .babyFood: AppColors.healthColor
        case .skincare: AppColors.bathColor
        case .medicine: AppColors.medicationColor
        case .feeding: AppColors.feedingColor
        case .bath: AppColors.bathColor
        case .clothes: AppColors.pastelPink
        case .toy: AppColors.diaperColor
        default: Color(.systemGray4)
        }
    }
}
