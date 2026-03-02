import Foundation

struct Routine: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var items: [RoutineItem]
    var babyId: String?
    var createdAt: Date

    struct RoutineItem: Codable, Hashable, Identifiable {
        var id: String
        var title: String
        var order: Int
        var isCompleted: Bool

        init(
            id: String = UUID().uuidString,
            title: String,
            order: Int,
            isCompleted: Bool = false
        ) {
            self.id = id
            self.title = title
            self.order = order
            self.isCompleted = isCompleted
        }
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        items: [RoutineItem] = [],
        babyId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.babyId = babyId
        self.createdAt = createdAt
    }
}
