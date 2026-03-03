import SwiftUI
import Charts

struct PurchaseHistoryView: View {
    @Environment(PurchaseViewModel.self) private var purchaseVM
    @Environment(AuthViewModel.self) private var authVM

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

    // MARK: - Total Spent Card

    private var totalSpentCard: some View {
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

    // MARK: - Monthly Chart

    @ViewBuilder
    private var monthlyChart: some View {
        let data = purchaseVM.spentByMonth
        if !data.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("월별 지출")
                    .font(.headline)

                Chart(data, id: \.0) { item in
                    BarMark(
                        x: .value("월", item.0),
                        y: .value("금액", item.1)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text(shortPrice(v))
                            }
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
    }

    // MARK: - Category Chart

    @ViewBuilder
    private var categoryChart: some View {
        let data = purchaseVM.spentByCategory
        if !data.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("카테고리별 지출")
                    .font(.headline)

                Chart(data, id: \.0) { item in
                    SectorMark(
                        angle: .value("금액", item.1),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value("카테고리", item.0.displayName))
                    .cornerRadius(3)
                }
                .frame(height: 200)

                VStack(spacing: 6) {
                    ForEach(data, id: \.0) { item in
                        HStack {
                            Image(systemName: item.0.icon)
                                .font(.caption)
                                .frame(width: 20)
                            Text(item.0.displayName)
                                .font(.caption)
                            Spacer()
                            Text(formattedPrice(item.1))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
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
    }

    // MARK: - Top Products

    @ViewBuilder
    private var topProductsSection: some View {
        let data = purchaseVM.mostPurchasedProducts
        if !data.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("자주 구매한 상품")
                    .font(.headline)

                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle().fill(index < 3 ? Color.accentColor : Color(.systemGray4))
                            )

                        Text(item.0)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        Text("\(item.1)회")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
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
    }

    // MARK: - Records List

    private var recordsList: some View {
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

    private func formattedPrice(_ price: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: price)) ?? "\(price)") + "원"
    }

    private func shortPrice(_ value: Int) -> String {
        if value >= 10000 {
            return "\(value / 10000)만"
        } else if value >= 1000 {
            return "\(value / 1000)천"
        }
        return "\(value)"
    }
}
