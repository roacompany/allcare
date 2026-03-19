import SwiftUI
import Charts

struct PurchaseHistoryView: View {
    @Environment(PurchaseViewModel.self) var purchaseVM
    @Environment(AuthViewModel.self) var authVM

    var body: some View {
        @Bindable var vm = purchaseVM

        ScrollView {
            VStack(spacing: 20) {
                // Period selector
                periodSelector

                if purchaseVM.isLoading {
                    ProgressView()
                        .padding(.vertical, 40)
                } else if purchaseVM.filteredRecords.isEmpty {
                    emptyState
                } else {
                    totalSpentCard
                    monthlyChart
                    categoryChart
                    topProductsSection
                    recordsList
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("구매 분석")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let userId = authVM.currentUserId else { return }
            await purchaseVM.loadRecords(userId: userId)
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PurchaseViewModel.Period.allCases, id: \.self) { period in
                    FilterChip(
                        title: period.rawValue,
                        isSelected: purchaseVM.selectedPeriod == period
                    ) {
                        purchaseVM.selectedPeriod = period
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("구매 기록이 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("용품 상세에서 구매 기록을 추가해보세요")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
