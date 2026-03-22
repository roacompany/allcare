import Foundation

struct CatalogProduct: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var brand: String
    var category: String  // BabyProduct.ProductCategory rawValue
    var coupangURL: String
    var imageURL: String?
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
}
