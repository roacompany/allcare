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
        let summary = analyzeSummary(activities: activities, startDate: startDate, endDate: endDate)

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

    // MARK: - Comparison

    static func analyzeComparison(
        currentReport: PatternReport,
        previousActivities: [Activity],
        previousPeriod: (start: Date, end: Date)
    ) -> PatternReport {
        let calendar = Calendar.current
        let previousDays = max(1, calendar.dateComponents([.day], from: previousPeriod.start.startOfDay, to: previousPeriod.end.startOfDay).day ?? 1)

        // Previous feeding daily average
        let prevFeedingCount = previousActivities.filter { $0.type.category == .feeding }.count
        let prevFeedingDailyAverage = Double(prevFeedingCount) / Double(previousDays)

        // Previous sleep daily average (hours)
        let prevSleepActivities = previousActivities.filter { $0.type == .sleep }
        let prevSleepTotalHours = prevSleepActivities.compactMap(\.duration).reduce(0, +) / 3600
        let prevSleepDailyAverageHours = prevSleepTotalHours / Double(previousDays)

        // Previous diaper daily average
        let prevDiaperCount = previousActivities.filter { $0.type.category == .diaper }.count
        let prevDiaperDailyAverage = Double(prevDiaperCount) / Double(previousDays)

        // Build updated pattern structs
        let updatedFeeding = FeedingPattern(
            totalCount: currentReport.feeding.totalCount,
            dailyAverage: currentReport.feeding.dailyAverage,
            averageInterval: currentReport.feeding.averageInterval,
            intervalTrend: currentReport.feeding.intervalTrend,
            totalMl: currentReport.feeding.totalMl,
            dailyMlAverage: currentReport.feeding.dailyMlAverage,
            breastVsBottleRatio: currentReport.feeding.breastVsBottleRatio,
            peakHours: currentReport.feeding.peakHours,
            dailyCounts: currentReport.feeding.dailyCounts,
            previousDailyAverage: prevFeedingDailyAverage
        )

        let updatedSleep = SleepPattern(
            totalHours: currentReport.sleep.totalHours,
            dailyAverageHours: currentReport.sleep.dailyAverageHours,
            averageDuration: currentReport.sleep.averageDuration,
            durationTrend: currentReport.sleep.durationTrend,
            qualityDistribution: currentReport.sleep.qualityDistribution,
            methodDistribution: currentReport.sleep.methodDistribution,
            peakSleepHours: currentReport.sleep.peakSleepHours,
            dailyHours: currentReport.sleep.dailyHours,
            previousDailyAverageHours: prevSleepDailyAverageHours
        )

        let updatedDiaper = DiaperPattern(
            totalCount: currentReport.diaper.totalCount,
            dailyAverage: currentReport.diaper.dailyAverage,
            wetVsDirtyRatio: currentReport.diaper.wetVsDirtyRatio,
            stoolColorDistribution: currentReport.diaper.stoolColorDistribution,
            consistencyDistribution: currentReport.diaper.consistencyDistribution,
            rashCount: currentReport.diaper.rashCount,
            dailyCounts: currentReport.diaper.dailyCounts,
            previousDailyAverage: prevDiaperDailyAverage
        )

        return PatternReport(
            period: currentReport.period,
            startDate: currentReport.startDate,
            endDate: currentReport.endDate,
            feeding: updatedFeeding,
            sleep: updatedSleep,
            diaper: updatedDiaper,
            health: currentReport.health,
            summary: currentReport.summary
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
            dailyCounts: dailyCounts,
            previousDailyAverage: nil
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
            dailyHours: dailyHours,
            previousDailyAverageHours: nil
        )
    }
}
