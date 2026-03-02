import Foundation

struct TodoItem: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var description: String?
    var dueDate: Date?
    var isCompleted: Bool
    var category: TodoCategory
    var babyId: String?
    var isRecurring: Bool
    var recurringInterval: RecurringInterval?
    var createdAt: Date
    var completedAt: Date?

    enum TodoCategory: String, Codable, CaseIterable {
        case vaccination = "vaccination"
        case hospital = "hospital"
        case shopping = "shopping"
        case milestone = "milestone"
        case other = "other"

        var displayName: String {
            switch self {
            case .vaccination: "예방접종"
            case .hospital: "병원"
            case .shopping: "쇼핑"
            case .milestone: "발달"
            case .other: "기타"
            }
        }

        var icon: String {
            switch self {
            case .vaccination: "syringe.fill"
            case .hospital: "cross.case.fill"
            case .shopping: "cart.fill"
            case .milestone: "star.fill"
            case .other: "checklist"
            }
        }
    }

    enum RecurringInterval: String, Codable, CaseIterable {
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"

        var displayName: String {
            switch self {
            case .daily: "매일"
            case .weekly: "매주"
            case .monthly: "매월"
            }
        }
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        category: TodoCategory = .other,
        babyId: String? = nil,
        isRecurring: Bool = false,
        recurringInterval: RecurringInterval? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.category = category
        self.babyId = babyId
        self.isRecurring = isRecurring
        self.recurringInterval = recurringInterval
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
