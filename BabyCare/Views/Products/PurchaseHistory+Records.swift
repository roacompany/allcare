import SwiftUI
import Charts

extension PurchaseHistoryView {
    // MARK: - Records List

    var recordsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("전체 구매 기록")
                .font(.headline)

            ForEach(purchaseVM.filteredRecords) { record in
                HStack(spacing: 12) {
                    Image(systemName: record.category.icon)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.productName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(record.store)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(DateFormatters.shortDate.string(from: record.purchaseDate))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formattedPrice(record.price * record.quantity))
                            .font(.subheadline.monospacedDigit())
                        if record.quantity > 1 {
                            Text("\(record.quantity)개")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.vertical, 4)
                .contextMenu {
                    Button(role: .destructive) {
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            await purchaseVM.deleteRecord(record, userId: userId)
                        }
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    // MARK: - Helpers

    func formattedPrice(_ price: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: price)) ?? "\(price)") + "원"
    }

    func shortPrice(_ value: Int) -> String {
        if value >= 10000 {
            return "\(value / 10000)만"
        } else if value >= 1000 {
            return "\(value / 1000)천"
        }
        return "\(value)"
    }
}
