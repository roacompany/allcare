import Foundation

@MainActor @Observable
final class PurchaseViewModel {
    var records: [PurchaseRecord] = []
    var isLoading = false
    var errorMessage: String?
    var selectedPeriod: Period = .threeMonths

    enum Period: String, CaseIterable {
        case week = "1주"
        case month = "1개월"
        case threeMonths = "3개월"
        case sixMonths = "6개월"
        case year = "1년"
        case all = "전체"

        var startDate: Date? {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .week: return cal.date(byAdding: .day, value: -7, to: now)
            case .month: return cal.date(byAdding: .month, value: -1, to: now)
            case .threeMonths: return cal.date(byAdding: .month, value: -3, to: now)
            case .sixMonths: return cal.date(byAdding: .month, value: -6, to: now)
            case .year: return cal.date(byAdding: .year, value: -1, to: now)
            case .all: return nil
            }
        }
    }

    private let firestoreService = FirestoreService.shared

    // MARK: - Filtered Records

    var filteredRecords: [PurchaseRecord] {
        guard let start = selectedPeriod.startDate else { return records }
        return records.filter { $0.purchaseDate >= start }
    }

    // MARK: - Analytics

    var totalSpent: Int {
        filteredRecords.reduce(0) { $0 + $1.price * $1.quantity }
    }

    var spentByCategory: [(BabyProduct.ProductCategory, Int)] {
        let grouped = Dictionary(grouping: filteredRecords) { $0.category }
        return grouped.compactMap { category, items in
            let total = items.reduce(0) { $0 + $1.price * $1.quantity }
            return total > 0 ? (category, total) : nil
        }.sorted { $0.1 > $1.1 }
    }

    var spentByMonth: [(String, Int)] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yy.MM"

        let grouped = Dictionary(grouping: filteredRecords) { record -> String in
            let comps = cal.dateComponents([.year, .month], from: record.purchaseDate)
            return formatter.string(from: cal.date(from: comps) ?? record.purchaseDate)
        }

        return grouped.map { (month, items) in
            (month, items.reduce(0) { $0 + $1.price * $1.quantity })
        }.sorted { $0.0 < $1.0 }
    }

    var mostPurchasedProducts: [(String, Int)] {
        let grouped = Dictionary(grouping: filteredRecords) { $0.productName }
        return grouped.map { (name, items) in
            (name, items.reduce(0) { $0 + $1.quantity })
        }
        .sorted { $0.1 > $1.1 }
        .prefix(5)
        .map { ($0.0, $0.1) }
    }

    func averageReorderDays(for productId: String) -> Int? {
        let productRecords = records
            .filter { $0.productId == productId }
            .sorted { $0.purchaseDate < $1.purchaseDate }

        guard productRecords.count >= 2 else { return nil }

        var totalDays = 0
        for i in 1..<productRecords.count {
            let days = Calendar.current.dateComponents(
                [.day],
                from: productRecords[i - 1].purchaseDate,
                to: productRecords[i].purchaseDate
            ).day ?? 0
            totalDays += days
        }

        return totalDays / (productRecords.count - 1)
    }

    func recordsForProduct(_ productId: String) -> [PurchaseRecord] {
        records.filter { $0.productId == productId }
    }

    // MARK: - CRUD

    func loadRecords(userId: String) async {
        isLoading = true
        do {
            records = try await firestoreService.fetchPurchaseRecords(userId: userId)
        } catch {
            errorMessage = "구매 기록을 불러오지 못했습니다."
        }
        isLoading = false
    }

    func addRecord(_ record: PurchaseRecord, userId: String) async {
        do {
            try await firestoreService.savePurchaseRecord(record, userId: userId)
            records.insert(record, at: 0)
        } catch {
            errorMessage = "구매 기록 저장에 실패했습니다."
        }
    }

    func deleteRecord(_ record: PurchaseRecord, userId: String) async {
        let backup = records
        records.removeAll { $0.id == record.id }

        do {
            try await firestoreService.deletePurchaseRecord(record.id, userId: userId)
        } catch {
            records = backup
            errorMessage = "삭제에 실패했습니다."
        }
    }

    func recordPurchase(
        product: BabyProduct,
        price: Int,
        quantity: Int,
        store: String,
        purchaseDate: Date,
        isAffiliate: Bool,
        note: String?,
        userId: String
    ) async {
        let record = PurchaseRecord(
            productId: product.id,
            productName: product.name,
            category: product.category,
            price: price,
            quantity: quantity,
            store: store,
            purchaseDate: purchaseDate,
            isAffiliate: isAffiliate,
            note: note
        )
        await addRecord(record, userId: userId)
    }
}
