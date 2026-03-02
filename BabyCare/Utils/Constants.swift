import SwiftUI

enum AppColors {
    static let feedingColor = Color("feedingColor")
    static let sleepColor = Color("sleepColor")
    static let diaperColor = Color("diaperColor")
    static let solidColor = Color("solidColor")
    static let bathColor = Color("bathColor")
    static let temperatureColor = Color("temperatureColor")
    static let medicationColor = Color("medicationColor")

    static let pastelPink = Color(hex: "FFB5C2")
    static let pastelBlue = Color(hex: "B5D5FF")
    static let pastelMint = Color(hex: "B5FFD9")
    static let pastelYellow = Color(hex: "FFF3B5")
    static let pastelPurple = Color(hex: "D9B5FF")
    static let pastelOrange = Color(hex: "FFDAB5")

    static let feedingDefault = Color(hex: "FF9FB5")
    static let sleepDefault = Color(hex: "9FB5FF")
    static let diaperDefault = Color(hex: "FFD59F")
    static let solidDefault = Color(hex: "9FDFBF")
    static let bathDefault = Color(hex: "9FD5FF")
    static let temperatureDefault = Color(hex: "FF9F9F")
    static let medicationDefault = Color(hex: "D59FFF")

    static let background = Color("backgroundColor")
    static let cardBackground = Color("cardBackground")
    static let primaryAccent = Color("primaryAccent")
}

enum AppConstants {
    static let defaultFeedingIntervalHours: Double = 3
    static let maxPhotoSizeBytes: Int = 1_048_576 // 1MB
    static let photoCompressionQuality: CGFloat = 0.7
    static let maxPhotoDimension: CGFloat = 1024
    static let firestoreBatchLimit = 500
}

enum FirestoreCollections {
    static let users = "users"
    static let babies = "babies"
    static let activities = "activities"
    static let growth = "growth"
    static let diary = "diary"
    static let todos = "todos"
    static let routines = "routines"
    static let products = "products"
    static let vaccinations = "vaccinations"
    static let milestones = "milestones"
    static let invites = "invites"
    static let sharedAccess = "sharedAccess"
}
