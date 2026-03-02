import Foundation

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

    private let firestoreService = FirestoreService.shared

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

    // MARK: - CRUD

    func loadProducts(userId: String) async {
        isLoading = true
        do {
            products = try await firestoreService.fetchProducts(userId: userId)
        } catch {
            errorMessage = "용품 목록을 불러오지 못했습니다."
        }
        isLoading = false
    }

    func addProduct(userId: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "용품 이름을 입력해주세요."
            return
        }

        let product = BabyProduct(
            babyId: selectedBabyId,
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces),
            category: category,
            purchaseDate: hasPurchaseDate ? purchaseDate : nil,
            purchasePrice: Int(purchasePrice),
            purchaseStore: purchaseStore.isEmpty ? nil : purchaseStore,
            quantity: Int(quantity),
            remainingQuantity: Int(quantity),
            size: size.isEmpty ? nil : size,
            rating: rating,
            babyReaction: babyReaction,
            allergyNote: allergyNote.isEmpty ? nil : allergyNote,
            note: note.isEmpty ? nil : note,
            isActive: isActive,
            expiryDate: hasExpiry ? expiryDate : nil,
            reorderReminder: reorderReminder,
            reorderThreshold: Int(reorderThreshold)
        )

        do {
            try await firestoreService.saveProduct(product, userId: userId)
            products.insert(product, at: 0)
            resetForm()
            showAddProduct = false
        } catch {
            errorMessage = "용품 추가에 실패했습니다."
        }
    }

    func updateProduct(_ product: BabyProduct, userId: String) async {
        var updated = product
        updated.updatedAt = Date()
        do {
            try await firestoreService.saveProduct(updated, userId: userId)
            if let index = products.firstIndex(where: { $0.id == product.id }) {
                products[index] = updated
            }
        } catch {
            errorMessage = "수정에 실패했습니다."
        }
    }

    func useProduct(_ product: BabyProduct, amount: Int, userId: String) async {
        guard var remaining = product.remainingQuantity else { return }
        remaining = max(0, remaining - amount)

        var updated = product
        updated.remainingQuantity = remaining
        updated.updatedAt = Date()

        if remaining == 0 {
            updated.isActive = false
        }

        await updateProduct(updated, userId: userId)

        if updated.isLowStock && updated.reorderReminder {
            let content = UNMutableNotificationContent()
            content.title = "재구매 알림"
            content.body = "\(product.name) 재고가 부족합니다. (\(remaining)개 남음)"
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "reorder-\(product.id)",
                content: content,
                trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func deleteProduct(_ product: BabyProduct, userId: String) async {
        do {
            try await firestoreService.deleteProduct(product.id, userId: userId)
            products.removeAll { $0.id == product.id }
        } catch {
            errorMessage = "삭제에 실패했습니다."
        }
    }

    func toggleActive(_ product: BabyProduct, userId: String) async {
        var updated = product
        updated.isActive.toggle()
        await updateProduct(updated, userId: userId)
    }

    func resetForm() {
        name = ""
        brand = ""
        category = .diaper
        purchaseDate = Date()
        hasPurchaseDate = true
        purchasePrice = ""
        purchaseStore = ""
        quantity = ""
        size = ""
        rating = nil
        babyReaction = nil
        allergyNote = ""
        note = ""
        isActive = true
        expiryDate = nil
        hasExpiry = false
        reorderReminder = false
        reorderThreshold = ""
        selectedBabyId = nil
        errorMessage = nil
    }
}

import UserNotifications
