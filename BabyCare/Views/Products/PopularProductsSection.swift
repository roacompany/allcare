import SwiftUI

// MARK: - PopularProductsSection

/// 카탈로그 기반 인기 용품 섹션.
/// Views → Services 직접 참조 금지. ProductViewModel을 통해 데이터를 받습니다.
struct PopularProductsSection: View {
    let popularProducts: [CatalogProduct]
    let onTapCoupang: (URL) -> Void

    var body: some View {
        if !popularProducts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    NSLocalizedString("product.popular.section.title", comment: ""),
                    systemImage: "flame.fill"
                )
                .font(.headline)
                .foregroundStyle(AppColors.coralColor)
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(popularProducts) { product in
                            PopularProductTile(product: product, onTapCoupang: onTapCoupang)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - PopularProductTile

private struct PopularProductTile: View {
    let product: CatalogProduct
    let onTapCoupang: (URL) -> Void

    private var categoryIcon: String {
        BabyProduct.ProductCategory(rawValue: product.category)?.icon ?? "bag.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 아이콘
            Image(systemName: categoryIcon)
                .font(.title2)
                .foregroundStyle(AppColors.primaryAccent)
                .frame(width: 44, height: 44)
                .background(AppColors.primaryAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(product.name)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(product.brand)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button {
                let url: URL?
                if !product.coupangURL.isEmpty {
                    url = URL(string: product.coupangURL)
                } else {
                    url = CoupangConfig.searchURL(keyword: product.name)
                }
                if let url {
                    onTapCoupang(url)
                }
            } label: {
                Label(
                    NSLocalizedString("product.popular.buy", comment: ""),
                    systemImage: "cart"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.primaryAccent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.primaryAccent.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 120, height: 160)
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}
