import SwiftUI
import Charts

extension PurchaseHistoryView {
    // MARK: - Monthly Chart

    @ViewBuilder
    var monthlyChart: some View {
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
    var categoryChart: some View {
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
    var topProductsSection: some View {
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
}
