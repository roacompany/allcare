import Foundation

struct PurchaseRecord: Identifiable, Codable, Hashable {
    var id: String
    var productId: String
    var productName: String
    var category: BabyProduct.ProductCategory
    var price: Int
    var quantity: Int
    var store: String
    var purchaseDate: Date
    var isAffiliate: Bool
    var note: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        productId: String,
        productName: String,
        category: BabyProduct.ProductCategory,
        price: Int,
        quantity: Int = 1,
        store: String = "쿠팡",
        purchaseDate: Date = Date(),
        isAffiliate: Bool = false,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.category = category
        self.price = price
        self.quantity = quantity
        self.store = store
        self.purchaseDate = purchaseDate
        self.isAffiliate = isAffiliate
        self.note = note
        self.createdAt = createdAt
    }
}
