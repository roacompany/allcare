import Foundation

struct DiaryEntry: Identifiable, Codable, Hashable {
    var id: String
    var babyId: String
    var date: Date
    var content: String
    var photoURLs: [String]
    var mood: Mood?
    var createdAt: Date
    var updatedAt: Date

    enum Mood: String, Codable, CaseIterable {
        case happy = "happy"
        case love = "love"
        case calm = "calm"
        case tired = "tired"
        case sick = "sick"
        case fussy = "fussy"

        var emoji: String {
            switch self {
            case .happy: "😊"
            case .love: "🥰"
            case .calm: "😌"
            case .tired: "😴"
            case .sick: "🤒"
            case .fussy: "😭"
            }
        }

        var displayName: String {
            switch self {
            case .happy: "행복"
            case .love: "사랑"
            case .calm: "평온"
            case .tired: "피곤"
            case .sick: "아픔"
            case .fussy: "칭얼"
            }
        }
    }

    init(
        id: String = UUID().uuidString,
        babyId: String,
        date: Date = Date(),
        content: String = "",
        photoURLs: [String] = [],
        mood: Mood? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.babyId = babyId
        self.date = date
        self.content = content
        self.photoURLs = photoURLs
        self.mood = mood
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
