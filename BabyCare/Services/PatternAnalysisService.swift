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

        // 🔑 기간 조회는 자정 넘김 밤잠을 잡으려고 **하루 앞당겨** 부른다(호출부).
        // 세는 자리(횟수·분포·막대)는 기간 안에서 시작한 것만 보고,
        // 시간 합계만 걸친 것 전체를 보고 기간·날짜 경계로 자른다.
        let inWindow = ActivityDayAttribution.startedWithin(activities, from: startDate.startOfDay, to: endDate)
        let feeding = analyzeFeeding(activities: inWindow, days: days, startDate: startDate, endDate: endDate)
        let sleep = analyzeSleep(activities: inWindow, spanning: activities, days: days, startDate: startDate, endDate: endDate)
        let diaper = analyzeDiaper(activities: inWindow, days: days)
        let health = analyzeHealth(activities: inWindow)
        let summary = analyzeSummary(activities: inWindow, startDate: startDate, endDate: endDate)

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

        // 🔑 이번 기간과 **같은 자로** 재야 한다 — 이번 주는 자정으로 잘라 재는데
        // 지난주만 통째로 더하면 비교가 사과 대 오렌지가 된다.
        let prevInWindow = ActivityDayAttribution.startedWithin(
            previousActivities, from: previousPeriod.start.startOfDay, to: previousPeriod.end
        )

        // Previous feeding daily average
        let prevFeedingCount = prevInWindow.filter { $0.type.category == .feeding }.count
        let prevFeedingDailyAverage = Double(prevFeedingCount) / Double(previousDays)

        // Previous sleep daily average (hours) — 기간 경계 클립
        let prevSleepActivities = previousActivities.filter { $0.type == .sleep }
        let prevSleepTotalHours = prevSleepActivities.reduce(0.0) {
            $0 + ActivityDayAttribution.clippedDuration(
                from: previousPeriod.start, to: previousPeriod.end,
                startTime: $1.startTime, endTime: $1.endTime, duration: $1.duration
            )
        } / 3600
        let prevSleepDailyAverageHours = prevSleepTotalHours / Double(previousDays)

        // Previous diaper daily average
        let prevDiaperCount = prevInWindow.filter { $0.type.category == .diaper }.count
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
            previousDailyAverageHours: prevSleepDailyAverageHours,
            regressionWarning: currentReport.sleep.regressionWarning,
            optimalBedtime: currentReport.sleep.optimalBedtime,
            napNightRatios: currentReport.sleep.napNightRatios,
            qualityScore: currentReport.sleep.qualityScore
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
                if interval < AppConstants.secondsPerDay { // 24시간 이내만
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

        // Breast vs Bottle — 모유 = 직수 + 유축 모유 병수유(둘 다 모유), 분유 = isFormulaBottle 만.
        // 유축 모유 병수유를 '분유'로 세지 않는다 (병원 프롬프트 "모유:x 분유:y" 오정보 방지 #14).
        let breast = feedingActivities.filter { $0.type == .feedingBreast || $0.isBreastMilkBottle }.count
        let bottle = feedingActivities.filter { $0.isFormulaBottle }.count

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

    /// - Parameter spanning: 기간에 **걸친** 기록까지 포함한 목록(하루 앞당겨 부른 조회 결과).
    ///   시간 합계만 이걸 보고 자른다. nil 이면 activities 와 같다(옛 호출부 호환).
    static func analyzeSleep(
        activities: [Activity], spanning: [Activity]? = nil, days: Int, startDate: Date, endDate: Date
    ) -> SleepPattern {
        let sleepActivities = activities.filter { $0.type == .sleep }
        let spanningSleeps = (spanning ?? activities).filter { $0.type == .sleep }

        // 기간 경계 클립 — 자정 넘김 수면이 기간 밖 시간까지 합산되는 왜곡 방지 (D1)
        let totalHours = spanningSleeps.reduce(0.0) {
            $0 + ActivityDayAttribution.clippedDuration(
                from: startDate, to: endDate,
                startTime: $1.startTime, endTime: $1.endTime, duration: $1.duration
            )
        } / 3600
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
        // 자정 클립 — 막대는 기간 안에서 시작한 날에만 세우고(유령 막대 방지),
        // 그 날의 시간은 걸친 기록 전체에서 그 날짜 몫만 잘라 더한다.
        let dailyHours = groupByDay(sleepActivities).map { date, _ in
            (date: date, hours: ActivityDayAttribution.totalClippedDuration(spanningSleeps, on: date) / 3600)
        }.sorted { $0.date < $1.date }

        let analysis = SleepAnalysisService.analyze(sleepActivities: sleepActivities)

        return SleepPattern(
            totalHours: totalHours,
            dailyAverageHours: dailyAverageHours,
            averageDuration: averageDuration,
            durationTrend: durationTrend,
            qualityDistribution: qualityDist,
            methodDistribution: methodDist,
            peakSleepHours: peakSleepHours,
            dailyHours: dailyHours,
            previousDailyAverageHours: nil,
            regressionWarning: analysis.regressionWarning,
            optimalBedtime: analysis.optimalBedtime,
            napNightRatios: analysis.napNightRatios,
            qualityScore: analysis.qualityScore
        )
    }
}
