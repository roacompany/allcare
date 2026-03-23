import SwiftUI

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Product Row

struct ProductRowView: View {
    let product: BabyProduct

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: product.category.icon)
                .font(.title3)
                .foregroundStyle(product.isActive ? .primary : .secondary)
                .frame(width: 36, height: 36)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(product.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    if product.isLowStock {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 6) {
                    if let brand = product.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let size = product.size {
                        Text(size)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if let reaction = product.babyReaction {
                        Text(reaction.emoji)
                            .font(.caption)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let remaining = product.remainingQuantity, let total = product.quantity {
                    Text("\(remaining)/\(total)\(product.effectiveUnit.displayName)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(product.isLowStock ? .orange : .secondary)
                }

                if let price = product.priceText {
                    Text(price)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .opacity(product.isActive ? 1 : 0.6)
    }
}
