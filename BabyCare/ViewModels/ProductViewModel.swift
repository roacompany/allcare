import Foundation
import UserNotifications

@MainActor @Observable
final class ProductViewModel {
    var products: [BabyProduct] = []
    var isLoading = false
    var errorMessage: String?
    var showAddProduct = false
    var selectedCategory: BabyProduct.ProductCategory?
    var searchText = ""

    // Form
    var name = ""
    var brand = ""
    var category: BabyProduct.ProductCategory = .diaper
    var purchaseDate = Date()
    var hasPurchaseDate = true
    var purchasePrice = ""
    var purchaseStore = ""
    var quantity = ""
    var size = ""
    var rating: Int?
    var babyReaction: BabyProduct.BabyReaction?
    var allergyNote = ""
    var note = ""
    var isActive = true
    var expiryDate: Date?
    var hasExpiry = false
    var reorderReminder = false
    var reorderThreshold = ""
    var selectedBabyId: String?

    // Catalog
    var catalog: [CatalogProduct] = []
    var isCatalogLoading = false
    var catalogError: String?
    var selectedCatalogProduct: CatalogProduct?

    let firestoreService = FirestoreService.shared

    func loadCatalog() async {
        isCatalogLoading = true
        catalogError = nil
        do {
            catalog = try await CatalogService.fetchCatalog()
            if catalog.isEmpty {
                catalogError = "Firestore 조회 성공, 문서 0개"
            }
        } catch {
            catalogError = error.localizedDescription
        }
        isCatalogLoading = false
    }

    // MARK: - Filtered Lists

    var filteredProducts: [BabyProduct] {
        var result = products

        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                ($0.brand?.lowercased().contains(query) ?? false)
            }
        }

        return result.sorted { $0.updatedAt > $1.updatedAt }
    }

    var activeProducts: [BabyProduct] {
        filteredProducts.filter(\.isActive)
    }

    var inactiveProducts: [BabyProduct] {
        filteredProducts.filter { !$0.isActive }
    }

    var lowStockProducts: [BabyProduct] {
        products.filter(\.isLowStock)
    }

    var expiringSoonProducts: [BabyProduct] {
        products.filter { $0.isExpiringSoon || $0.isExpired }
    }

    var totalSpent: Int {
        products.compactMap(\.purchasePrice).reduce(0, +)
    }

    var spentByCategory: [(BabyProduct.ProductCategory, Int)] {
        let grouped = Dictionary(grouping: products) { $0.category }
        return grouped.compactMap { category, items in
            let total = items.compactMap(\.purchasePrice).reduce(0, +)
            return total > 0 ? (category, total) : nil
        }.sorted { $0.1 > $1.1 }
    }
}
