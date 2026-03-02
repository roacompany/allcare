import Foundation

struct GrowthRecord: Identifiable, Codable, Hashable {
    var id: String
    var babyId: String
    var date: Date
    var height: Double?
    var weight: Double?
    var headCircumference: Double?
    var note: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        babyId: String,
        date: Date = Date(),
        height: Double? = nil,
        weight: Double? = nil,
        headCircumference: Double? = nil,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.babyId = babyId
        self.date = date
        self.height = height
        self.weight = weight
        self.headCircumference = headCircumference
        self.note = note
        self.createdAt = createdAt
    }
}
