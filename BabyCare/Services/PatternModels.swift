import Foundation

// MARK: - Data Structures

enum Trend: String {
    case increasing = "증가"
    case decreasing = "감소"
    case stable = "유지"
}

// MARK: - Sleep Analysis Models

/// 수면 퇴행 감지 결과 모델
struct SleepRegressionWarning: Identifiable, Codable, Hashable {
    var id: String?
    /// 감지된 퇴행 월령 (4, 8, 12개월)
    var regressionAgeMonth: Int?
    /// 최근 7일 일평균 수면 시간 (시간)
    var recentAvgHours: Double?
    /// 직전 14~28일 일평균 수면 시간 (시간)
    var baselineAvgHours: Double?
    /// 감소율 (0~1, 음수 = 감소)
    var declineRate: Double?

    init(
        id: String = UUID().uuidString,
        regressionAgeMonth: Int? = nil,
        recentAvgHours: Double? = nil,
        baselineAvgHours: Double? = nil,
        declineRate: Double? = nil
    ) {
        self.id = id
        self.regressionAgeMonth = regressionAgeMonth
        self.recentAvgHours = recentAvgHours
        self.baselineAvgHours = baselineAvgHours
        self.declineRate = declineRate
    }
}

/// 최적 취침 시간 추천 모델
struct OptimalBedtime: Identifiable, Codable, Hashable {
    var id: String?
    /// 추천 취침 시작 시각 (초단위 자정 기준)
    var bedtimeStart: TimeInterval?
    /// 추천 취침 종료 시각 (windowStart + 3600)
    var bedtimeEnd: TimeInterval?
    /// 분석에 사용된 기준 중앙값 시각 (초단위)
    var medianBedtime: TimeInterval?
    /// 샘플 수
    var sampleCount: Int?

    init(
        id: String = UUID().uuidString,
        bedtimeStart: TimeInterval? = nil,
        bedtimeEnd: TimeInterval? = nil,
        medianBedtime: TimeInterval? = nil,
        sampleCount: Int? = nil
    ) {
        self.id = id
        self.bedtimeStart = bedtimeStart
        self.bedtimeEnd = bedtimeEnd
        self.medianBedtime = medianBedtime
        self.sampleCount = sampleCount
    }
}

/// 낮잠 vs 밤잠 비율 일별/주별 데이터
struct NapNightRatio: Identifiable, Codable, Hashable {
    var id: String?
    var date: Date?
    /// 낮잠 시간 (시간)
    var napHours: Double?
    /// 밤잠 시간 (시간)
    var nightHours: Double?
    /// 낮잠 비율 (0~1)
    var napRatio: Double?

    init(
        id: String = UUID().uuidString,
        date: Date? = nil,
        napHours: Double? = nil,
        nightHours: Double? = nil,
        napRatio: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.napHours = napHours
        self.nightHours = nightHours
        self.napRatio = napRatio
    }
}

/// 수면 품질 점수 모델 (0~100)
struct SleepQualityScore: Identifiable, Codable, Hashable {
    var id: String?
    /// 총 점수 (0~100)
    var score: Int?
    /// 총수면시간 점수 (0~50)
    var durationScore: Int?
    /// 깨는 횟수 역수 점수 (0~30)
    var wakeScore: Int?
    /// 낮잠 횟수 적정성 점수 (0~20)
    var napScore: Int?
    /// 분석 기간 일평균 수면 시간
    var avgDailyHours: Double?
    /// 분석 기간 총 수면 세션 수
    var totalSessions: Int?

    init(
        id: String = UUID().uuidString,
        score: Int? = nil,
        durationScore: Int? = nil,
        wakeScore: Int? = nil,
        napScore: Int? = nil,
        avgDailyHours: Double? = nil,
        totalSessions: Int? = nil
    ) {
        self.id = id
        self.score = score
        self.durationScore = durationScore
        self.wakeScore = wakeScore
        self.napScore = napScore
        self.avgDailyHours = avgDailyHours
        self.totalSessions = totalSessions
    }
}

struct PatternReport {
    let period: String
    let startDate: Date
    let endDate: Date
    let feeding: FeedingPattern
    let sleep: SleepPattern
    let diaper: DiaperPattern
    let health: HealthPattern
    let summary: SummaryPattern
}

struct FeedingPattern {
    let totalCount: Int
    let dailyAverage: Double
    let averageInterval: TimeInterval?
    let intervalTrend: Trend
    let totalMl: Double
    let dailyMlAverage: Double
    let breastVsBottleRatio: (breast: Int, bottle: Int)
    let peakHours: [Int]
    let dailyCounts: [(date: Date, count: Int)]
    let previousDailyAverage: Double?
}

struct SleepPattern {
    let totalHours: Double
    let dailyAverageHours: Double
    let averageDuration: TimeInterval
    let durationTrend: Trend
    let qualityDistribution: [Activity.SleepQualityType: Int]
    let methodDistribution: [Activity.SleepMethodType: Int]
    let peakSleepHours: [Int]
    let dailyHours: [(date: Date, hours: Double)]
    let previousDailyAverageHours: Double?
    // Sleep Analysis (optional — nil when insufficient data)
    var regressionWarning: SleepRegressionWarning?
    var optimalBedtime: OptimalBedtime?
    var napNightRatios: [NapNightRatio]?
    var qualityScore: SleepQualityScore?
}

struct DiaperPattern {
    let totalCount: Int
    let dailyAverage: Double
    let wetVsDirtyRatio: (wet: Int, dirty: Int, both: Int)
    let stoolColorDistribution: [Activity.StoolColor: Int]
    let consistencyDistribution: [Activity.StoolConsistency: Int]
    let rashCount: Int
    let dailyCounts: [(date: Date, count: Int)]
    let previousDailyAverage: Double?
}

struct HealthPattern {
    let temperatureReadings: [(date: Date, temp: Double)]
    let averageTemp: Double?
    let highTempDays: Int
    let medicationCount: Int
    let medicationNames: [String: Int]
    let consecutiveFeverDays: Int
}

struct SummaryPattern {
    let totalRecords: Int
    let mostActiveDay: (date: Date, count: Int)?
    let leastActiveDay: (date: Date, count: Int)?
    let categoryDistribution: [Activity.ActivityCategory: Int]
    let missingDays: Int
}
