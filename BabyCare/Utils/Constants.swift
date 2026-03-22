import SwiftUI

enum AppColors {
    // MARK: - Activity Colors (Asset Catalog, 다크 모드 대응)
    static let feedingColor = Color("feedingColor")
    static let sleepColor = Color("sleepColor")
    static let diaperColor = Color("diaperColor")
    static let solidColor = Color("solidColor")
    static let bathColor = Color("bathColor")
    static let temperatureColor = Color("temperatureColor")
    static let medicationColor = Color("medicationColor")

    // MARK: - Semantic Colors (Asset Catalog, 다크 모드 대응)
    static let background = Color("backgroundColor")
    static let cardBackground = Color("cardBackground")
    static let primaryAccent = Color("primaryAccent")
    static let successColor = Color("successColor")       // #4CAF50
    static let healthColor = Color("healthColor")          // #9FDFBF
    static let coralColor = Color("coralColor")            // #F4845F
    static let indigoColor = Color("indigoColor")          // #7B9FE8
    static let sageColor = Color("sageColor")              // #85C1A3
    static let warmOrangeColor = Color("warmOrangeColor")  // #F4A261
    static let skyBlueColor = Color("skyBlueColor")        // #5CB8E4
    static let softPurpleColor = Color("softPurpleColor")  // #A078D4

    // MARK: - Pastel Colors (다크 모드에서 opacity로 자동 대응)
    static let pastelPink = Color(hex: "FFB5C2")
    static let pastelBlue = Color(hex: "B5D5FF")
    static let pastelMint = Color(hex: "B5FFD9")
    static let pastelYellow = Color(hex: "FFF3B5")
    static let pastelPurple = Color(hex: "D9B5FF")
    static let pastelOrange = Color(hex: "FFDAB5")

    // MARK: - Default Activity Colors (시맨틱 별칭)
    static let feedingDefault = feedingColor
    static let sleepDefault = sleepColor
    static let diaperDefault = diaperColor
    static let solidDefault = solidColor
    static let bathDefault = bathColor
    static let temperatureDefault = temperatureColor
    static let medicationDefault = medicationColor
}

enum AppConstants {
    static let defaultFeedingIntervalHours: Double = 3
    static let maxPhotoSizeBytes: Int = 1_048_576 // 1MB
    static let photoCompressionQuality: CGFloat = 0.7
    static let maxPhotoDimension: CGFloat = 1024
    static let firestoreBatchLimit = 500

    /// 월령별 적정 수유 간격 (시간) — AAP/대한소아과학회 기준
    static func feedingIntervalHours(ageInMonths: Int) -> Double {
        switch ageInMonths {
        case 0:       return 2.0   // 신생아: 1.5~2.5시간
        case 1:       return 2.5   // 1개월: 2~3시간
        case 2...3:   return 3.0   // 2~3개월: 2.5~3.5시간
        case 4...5:   return 3.5   // 4~5개월: 3~4시간
        case 6...8:   return 4.0   // 6~8개월: 이유식 병행
        case 9...11:  return 4.5   // 9~11개월
        default:      return 5.0   // 12개월+: 식사 위주
        }
    }
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
    static let fcmTokens = "fcmTokens"
    static let announcements = "announcements"
    static let hospitalVisits = "hospitalVisits"
    static let purchases = "purchases"
    static let productCatalog = "productCatalog"
}

enum CoupangConfig {
    private static let affiliateCode = "AF5256637"
    private static let subId = "babycareapp"
    private static let baseURL = "https://link.coupang.com/re/AFFSRP"

    static func searchURL(keyword: String) -> URL? {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        return URL(string: "\(baseURL)?lptag=\(affiliateCode)&subid=\(subId)&pageKey=\(encoded)")
    }

    static func defaultKeyword(for category: BabyProduct.ProductCategory) -> String {
        switch category {
        case .diaper: "아기 기저귀"
        case .formula: "분유"
        case .babyFood: "이유식"
        case .skincare: "아기 로션"
        case .medicine: "아기 상비약"
        case .clothes: "아기 옷"
        case .toy: "아기 장난감"
        case .feeding: "아기 젖병"
        case .bath: "아기 목욕용품"
        case .bedding: "아기 침구"
        case .gear: "유모차"
        case .other: "아기 용품"
        }
    }
}
