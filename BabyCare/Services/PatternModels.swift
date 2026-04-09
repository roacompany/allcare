import Foundation

import Foundation

// MARK: - Data Structures

enum Trend: String {
    case increasing = "증가"
    case decreasing = "감소"
    case stable = "유지"
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
