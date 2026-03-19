import Foundation

// MARK: - Analysis Service

enum PatternAnalysisService {

    static func analyze(
        activities: [Activity],
        period: String,
        startDate: Date,
        endDate: Date
    ) -> PatternReport {
        let calendar = Calendar.current
        let days = max(1, calendar.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay).day ?? 1)

        let feeding = analyzeFeeding(activities: activities, days: days, startDate: startDate, endDate: endDate)
        let sleep = analyzeSleep(activities: activities, days: days, startDate: startDate, endDate: endDate)
        let diaper = analyzeDiaper(activities: activities, days: days)
        let health = analyzeHealth(activities: activities)
        let summary = analyzeSummary(activities: activities)

        return PatternReport(
            period: period,
            startDate: startDate,
            endDate: endDate,
            feeding: feeding,
            sleep: sleep,
            diaper: diaper,
            health: health,
            summary: summary
        )
    }

    // MARK: - Feeding

    static func analyzeFeeding(
        activities: [Activity], days: Int, startDate: Date, endDate: Date
    ) -> FeedingPattern {
        let feedingActivities = activities.filter { $0.type.category == .feeding }
        let sorted = feedingActivities.sorted { $0.startTime < $1.startTime }

        let totalCount = feedingActivities.count
        let dailyAverage = Double(totalCount) / Double(days)

        // Average interval
        var averageInterval: TimeInterval?
        if sorted.count >= 2 {
            var intervals: [TimeInterval] = []
            for i in 1..<sorted.count {
                let interval = sorted[i].startTime.timeIntervalSince(sorted[i - 1].startTime)
                if interval < 86400 { // 24시간 이내만
                    intervals.append(interval)
                }
            }
            if !intervals.isEmpty {
                averageInterval = intervals.reduce(0, +) / Double(intervals.count)
            }
        }

        // Interval trend (전반부 vs 후반부)
        let intervalTrend = computeIntervalTrend(sorted: sorted)

        // Total ml
        let totalMl = feedingActivities.compactMap(\.amount).reduce(0, +)
        let dailyMlAverage = totalMl / Double(days)

        // Breast vs Bottle
        let breast = feedingActivities.filter { $0.type == .feedingBreast }.count
        let bottle = feedingActivities.filter { $0.type == .feedingBottle }.count

        // Peak hours
        let peakHours = computePeakHours(activities: feedingActivities, topN: 3)

        // Daily counts
        let dailyCounts = groupByDay(feedingActivities)
            .map { (date: $0.key, count: $0.value.count) }
            .sorted { $0.date < $1.date }

        return FeedingPattern(
            totalCount: totalCount,
            dailyAverage: dailyAverage,
            averageInterval: averageInterval,
            intervalTrend: intervalTrend,
            totalMl: totalMl,
            dailyMlAverage: dailyMlAverage,
            breastVsBottleRatio: (breast: breast, bottle: bottle),
            peakHours: peakHours,
            dailyCounts: dailyCounts
        )
    }

    // MARK: - Sleep

    static func analyzeSleep(
        activities: [Activity], days: Int, startDate: Date, endDate: Date
    ) -> SleepPattern {
        let sleepActivities = activities.filter { $0.type == .sleep }

        let totalHours = sleepActivities.compactMap(\.duration).reduce(0, +) / 3600
        let dailyAverageHours = totalHours / Double(days)

        let durations = sleepActivities.compactMap(\.duration)
        let averageDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)

        // Duration trend
        let durationTrend = computeDurationTrend(activities: sleepActivities)

        // Quality distribution
        var qualityDist: [Activity.SleepQualityType: Int] = [:]
        for act in sleepActivities {
            if let quality = act.sleepQuality {
                qualityDist[quality, default: 0] += 1
            }
        }

        // Method distribution
        var methodDist: [Activity.SleepMethodType: Int] = [:]
        for act in sleepActivities {
            if let method = act.sleepMethod {
                methodDist[method, default: 0] += 1
            }
        }

        // Peak sleep hours
        let peakSleepHours = computePeakHours(activities: sleepActivities, topN: 3)

        // Daily hours
        let dailyHours = groupByDay(sleepActivities).map { date, acts in
            (date: date, hours: acts.compactMap(\.duration).reduce(0, +) / 3600)
        }.sorted { $0.date < $1.date }

        return SleepPattern(
            totalHours: totalHours,
            dailyAverageHours: dailyAverageHours,
            averageDuration: averageDuration,
            durationTrend: durationTrend,
            qualityDistribution: qualityDist,
            methodDistribution: methodDist,
            peakSleepHours: peakSleepHours,
            dailyHours: dailyHours
        )
    }
}
