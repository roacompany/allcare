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
    static let pumpingColor = Color("pumpingColor")        // 유축 — 보라/자두 (mint/teal palette collision 회피, spec §8)
    static let neutralGray = Color("neutralGrayColor")     // .unknown(forward-compat 센티넬) 중립 회색

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

    // MARK: - Time
    static let secondsPerHour: TimeInterval = 3_600
    static let secondsPerDay: TimeInterval = 86_400

    // MARK: - Domain Limits
    /// 태동 세션 최대 길이 (2시간). 초과 시 자동 정지.
    static let kickSessionMaxSeconds: TimeInterval = 2 * secondsPerHour
    /// 수유 타이머 최대 길이 (8시간). Live Activity 종료 임계.
    static let feedingTimerMaxSeconds: TimeInterval = 8 * secondsPerHour
    /// 주간 하이라이트 AI 캐시 TTL (7일).
    static let highlightCacheTTLSeconds: TimeInterval = 7 * secondsPerDay

    // MARK: - Medical Thresholds
    /// 발열 임계 온도 (°C). AAP/대한소아과학회 기준.
    /// 별칭: Services/Analysis/ReferenceTable.feverThreshold 와 동일 값 — 통계 분석 파이프라인은 ReferenceTable 사용.
    static let feverThresholdCelsius: Double = 38.0

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
    static let allergies = "allergies"
    static let cryRecords = "cryRecords"
    static let sounds = "sounds"
    static let hospitalReports = "hospitalReports"
    static let familySharing = "familySharing"
    static let badges = "badges"
    static let stats = "stats"
    // MARK: - Pregnancy Mode
    static let pregnancies = "pregnancies"
    static let kickSessions = "kickSessions"
    static let prenatalVisits = "prenatalVisits"
    static let pregnancyChecklists = "pregnancyChecklists"
    static let pregnancyWeights = "pregnancyWeights"
    static let pregnancySymptoms = "pregnancySymptoms"
    static let pregnancyVitals = "pregnancyVitals"
    static let contractionSessions = "contractionSessions"
    // MARK: - Insights ML
    /// 주간 metric 스냅샷. 경로: users/{uid}/babies/{bid}/weeklyMetrics/{weekKey}
    /// Phase 1 통계적 이상치 탐지의 history input. Phase 2 ML 학습 입력.
    static let weeklyMetrics = "weeklyMetrics"
    // MARK: - Weekly Highlights
    /// AI 주간 하이라이트 캐시. 경로: users/{uid}/babies/{bid}/highlightCache/{weekKey}
    /// HighlightAISummaryService 생성 결과 영속. TTL 7일.
    static let highlightCache = "highlightCache"
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
