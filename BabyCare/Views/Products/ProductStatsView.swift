import SwiftUI
import Charts

struct ProductStatsView: View {
    @Environment(ProductViewModel.self) private var productVM

    var body: some View {
        List {
            // Total spend
            Section {
                VStack(spacing: 4) {
                    Text("총 지출")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatPrice(productVM.totalSpent))
                        .font(.title.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            // Pie chart
            if !productVM.spentByCategory.isEmpty {
                Section("카테고리별 지출") {
                    Chart(productVM.spentByCategory, id: \.0) { item in
                        SectorMark(
                            angle: .value("금액", item.1),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("카테고리", item.0.displayName))
                        .cornerRadius(4)
                    }
                    .frame(height: 200)

                    ForEach(productVM.spentByCategory, id: \.0) { category, amount in
                        HStack {
                            Image(systemName: category.icon)
                                .font(.caption)
                                .frame(width: 24)
                            Text(category.displayName)
                                .font(.subheadline)
                            Spacer()
                            Text(formatPrice(amount))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Summary stats
            Section("요약") {
                HStack {
                    Text("등록 용품")
                    Spacer()
                    Text("\(productVM.products.count)개")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("사용 중")
                    Spacer()
                    Text("\(productVM.products.filter(\.isActive).count)개")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("재고 부족")
                    Spacer()
                    Text("\(productVM.lowStockProducts.count)개")
                        .foregroundStyle(productVM.lowStockProducts.isEmpty ? Color.secondary : Color.orange)
                }
            }
        }
        .navigationTitle("지출 통계")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatPrice(_ price: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: price)) ?? "\(price)") + "원"
    }
}
