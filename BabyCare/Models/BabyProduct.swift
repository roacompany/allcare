import Foundation

struct BabyProduct: Identifiable, Codable, Hashable {
    var id: String
    var babyId: String?
    var name: String
    var brand: String?
    var category: ProductCategory
    var purchaseDate: Date?
    var purchasePrice: Int?
    var purchaseStore: String?
    var quantity: Int?
    var remainingQuantity: Int?
    var quantityUnit: QuantityUnit?
    var size: String?
    var rating: Int?              // 1-5
    var babyReaction: BabyReaction?
    var allergyNote: String?
    var note: String?
    var photoURL: String?
    var isActive: Bool            // 현재 사용 중
    var openedDate: Date?         // 개봉일 (분유 등)
    var expiryDate: Date?         // 유통기한
    var reorderReminder: Bool
    var reorderThreshold: Int?    // 잔량 n개 이하면 알림
    var catalogId: String? = nil
    var coupangURL: String? = nil
    var createdAt: Date
    var updatedAt: Date

    enum ProductCategory: String, Codable, CaseIterable {
        case diaper = "diaper"
        case formula = "formula"
        case babyFood = "baby_food"
        case skincare = "skincare"
        case medicine = "medicine"
        case clothes = "clothes"
        case toy = "toy"
        case feeding = "feeding"       // 젖병, 빨대컵 등
        case bath = "bath"             // 목욕용품
        case bedding = "bedding"       // 침구류
        case gear = "gear"             // 유모차, 카시트 등
        case other = "other"

        var displayName: String {
            switch self {
            case .diaper: "기저귀"
            case .formula: "분유"
            case .babyFood: "이유식/간식"
            case .skincare: "스킨케어"
            case .medicine: "의약품"
            case .clothes: "의류"
            case .toy: "장난감"
            case .feeding: "수유용품"
            case .bath: "목욕용품"
            case .bedding: "침구류"
            case .gear: "외출용품"
            case .other: "기타"
            }
        }

        var defaultUnit: QuantityUnit {
            switch self {
            case .formula, .babyFood: .gram
            case .skincare, .bath, .medicine: .ml
            default: .count
            }
        }

        var icon: String {
            switch self {
            case .diaper: "humidity.fill"
            case .formula: "cup.and.saucer.fill"
            case .babyFood: "carrot.fill"
            case .skincare: "drop.fill"
            case .medicine: "pills.fill"
            case .clothes: "tshirt.fill"
            case .toy: "teddybear.fill"
            case .feeding: "cup.and.saucer"
            case .bath: "bathtub.fill"
            case .bedding: "bed.double.fill"
            case .gear: "stroller.fill"
            case .other: "bag.fill"
            }
        }
    }

    enum QuantityUnit: String, Codable, CaseIterable {
        case count = "count"   // 개
        case gram = "g"        // g
        case ml = "ml"         // ml

        var displayName: String {
            switch self {
            case .count: "개"
            case .gram: "g"
            case .ml: "ml"
            }
        }

        var stepAmount: Int {
            switch self {
            case .count: 1
            case .gram: 10
            case .ml: 10
            }
        }
    }

    enum BabyReaction: String, Codable, CaseIterable {
        case great = "great"
        case good = "good"
        case neutral = "neutral"
        case bad = "bad"
        case allergic = "allergic"

        var displayName: String {
            switch self {
            case .great: "아주 좋음"
            case .good: "좋음"
            case .neutral: "보통"
            case .bad: "안 맞음"
            case .allergic: "알러지"
            }
        }

        var emoji: String {
            switch self {
            case .great: "😍"
            case .good: "😊"
            case .neutral: "😐"
            case .bad: "😣"
            case .allergic: "🚨"
            }
        }
    }

    var effectiveUnit: QuantityUnit {
        quantityUnit ?? category.defaultUnit
    }

    var isLowStock: Bool {
        guard let remaining = remainingQuantity,
              let threshold = reorderThreshold else { return false }
        return remaining <= threshold
    }

    var isExpired: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry < Date()
    }

    var isExpiringSoon: Bool {
        guard let expiry = expiryDate else { return false }
        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        return daysUntilExpiry <= 7 && daysUntilExpiry > 0
    }

    var priceText: String? {
        guard let price = purchasePrice else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: price)) ?? "\(price)") + "원"
    }

    init(
        id: String = UUID().uuidString,
        babyId: String? = nil,
        name: String,
        brand: String? = nil,
        category: ProductCategory,
        purchaseDate: Date? = nil,
        purchasePrice: Int? = nil,
        purchaseStore: String? = nil,
        quantity: Int? = nil,
        remainingQuantity: Int? = nil,
        quantityUnit: QuantityUnit? = nil,
        size: String? = nil,
        rating: Int? = nil,
        babyReaction: BabyReaction? = nil,
        allergyNote: String? = nil,
        note: String? = nil,
        photoURL: String? = nil,
        isActive: Bool = true,
        openedDate: Date? = nil,
        expiryDate: Date? = nil,
        reorderReminder: Bool = false,
        reorderThreshold: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.babyId = babyId
        self.name = name
        self.brand = brand
        self.category = category
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.purchaseStore = purchaseStore
        self.quantity = quantity
        self.remainingQuantity = remainingQuantity
        self.quantityUnit = quantityUnit
        self.size = size
        self.rating = rating
        self.babyReaction = babyReaction
        self.allergyNote = allergyNote
        self.note = note
        self.photoURL = photoURL
        self.isActive = isActive
        self.openedDate = openedDate
        self.expiryDate = expiryDate
        self.reorderReminder = reorderReminder
        self.reorderThreshold = reorderThreshold
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
