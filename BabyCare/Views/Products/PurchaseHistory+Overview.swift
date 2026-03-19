import SwiftUI
import Charts

extension PurchaseHistoryView {
    // MARK: - Total Spent Card

    var totalSpentCard: some View {
        VStack(spacing: 8) {
            Text("총 지출")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(formattedPrice(purchaseVM.totalSpent))
                .font(.title.bold())
                .foregroundStyle(.primary)
            Text("\(purchaseVM.filteredRecords.count)건")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }
}
