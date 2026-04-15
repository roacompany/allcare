import Foundation

// MARK: - FoodSafetyStatus

enum FoodSafetyStatus: String, Codable, CaseIterable, Hashable {
    case safe = "safe"
    case caution = "caution"
    case forbidden = "forbidden"

    var displayName: String {
        switch self {
        case .safe: return NSLocalizedString("food.safety.status.safe", comment: "")
        case .caution: return NSLocalizedString("food.safety.status.caution", comment: "")
        case .forbidden: return NSLocalizedString("food.safety.status.forbidden", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.seal.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .forbidden: return "xmark.seal.fill"
        }
    }

    var colorName: String {
        switch self {
        case .safe: return "successColor"
        case .caution: return "warmOrangeColor"
        case .forbidden: return "coralColor"
        }
    }
}

// MARK: - FoodHistoryEventKind

enum FoodHistoryEventKind: String, Codable, Hashable {
    case tried = "tried"
    case reaction = "reaction"
    case safe = "safe"

    var displayName: String {
        switch self {
        case .tried: return NSLocalizedString("food.history.kind.tried", comment: "")
        case .reaction: return NSLocalizedString("food.history.kind.reaction", comment: "")
        case .safe: return NSLocalizedString("food.history.kind.safe", comment: "")
        }
    }

    var icon: String {
        switch self {
        case .tried: return "fork.knife.circle"
        case .reaction: return "exclamationmark.triangle"
        case .safe: return "checkmark.circle"
        }
    }
}

// MARK: - FoodHistoryEvent

struct FoodHistoryEvent: Identifiable, Codable, Hashable {
    var id: String
    var foodName: String
    var date: Date
    var kind: FoodHistoryEventKind
    var note: String?

    init(
        id: String = UUID().uuidString,
        foodName: String,
        date: Date,
        kind: FoodHistoryEventKind,
        note: String? = nil
    ) {
        self.id = id
        self.foodName = foodName
        self.date = date
        self.kind = kind
        self.note = note
    }
}

// MARK: - FoodSafetyEntry

struct FoodSafetyEntry: Identifiable, Codable, Hashable {
    var id: String
    var foodName: String
    var status: FoodSafetyStatus
    var trialCount: Int
    var reactionCount: Int
    var firstTriedDate: Date?
    var lastTriedDate: Date?
    var note: String?

    init(
        id: String = UUID().uuidString,
        foodName: String,
        status: FoodSafetyStatus,
        trialCount: Int = 0,
        reactionCount: Int = 0,
        firstTriedDate: Date? = nil,
        lastTriedDate: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.foodName = foodName
        self.status = status
        self.trialCount = trialCount
        self.reactionCount = reactionCount
        self.firstTriedDate = firstTriedDate
        self.lastTriedDate = lastTriedDate
        self.note = note
    }
}
