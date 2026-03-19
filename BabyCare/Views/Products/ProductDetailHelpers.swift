import SwiftUI
import SafariServices

extension ProductDetailView {

    func productPurchaseHistory(_ records: [PurchaseRecord]) -> some View {
        List {
            ForEach(records) { record in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.store)
                            .font(.subheadline.weight(.medium))
                        Text(DateFormatters.shortDate.string(from: record.purchaseDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formattedPrice(record.price * record.quantity))
                            .font(.subheadline.monospacedDigit())
                        if record.quantity > 1 {
                            Text("\(record.quantity)개")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("구매 이력")
        .navigationBarTitleDisplayMode(.inline)
    }

    func formattedPrice(_ price: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: price)) ?? "\(price)") + "원"
    }
}
