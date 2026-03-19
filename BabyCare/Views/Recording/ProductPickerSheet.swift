import SwiftUI

// MARK: - ProductPickerSheet

/// 같은 카테고리에 용품이 2개 이상일 때 어떤 용품에서 차감할지 선택하는 시트
struct ProductPickerSheet: View {
    let products: [BabyProduct]
    let onSelect: (BabyProduct) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(products) { product in
                Button {
                    onSelect(product)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: product.category.icon)
                            .font(.title3)
                            .foregroundStyle(AppColors.indigoColor)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if let brand = product.brand {
                                Text(brand)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if let remaining = product.remainingQuantity {
                            Text("\(remaining)개 남음")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("사용할 용품 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("건너뛰기") { dismiss() }
                }
            }
        }
    }
}
