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
}

struct DiaperPattern {
    let totalCount: Int
    let dailyAverage: Double
    let wetVsDirtyRatio: (wet: Int, dirty: Int, both: Int)
    let stoolColorDistribution: [Activity.StoolColor: Int]
    let consistencyDistribution: [Activity.StoolConsistency: Int]
    let rashCount: Int
    let dailyCounts: [(date: Date, count: Int)]
}

struct HealthPattern {
    let temperatureReadings: [(date: Date, temp: Double)]
    let averageTemp: Double?
    let highTempDays: Int
    let medicationCount: Int
    let medicationNames: [String: Int]
}

struct SummaryPattern {
    let totalRecords: Int
    let mostActiveDay: (date: Date, count: Int)?
    let leastActiveDay: (date: Date, count: Int)?
    let categoryDistribution: [Activity.ActivityCategory: Int]
}

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

    private static func analyzeFeeding(
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

    private static func analyzeSleep(
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

    // MARK: - Diaper

    private static func analyzeDiaper(activities: [Activity], days: Int) -> DiaperPattern {
        let diaperActivities = activities.filter { $0.type.category == .diaper }

        let totalCount = diaperActivities.count
        let dailyAverage = Double(totalCount) / Double(days)

        let wet = diaperActivities.filter { $0.type == .diaperWet }.count
        let dirty = diaperActivities.filter { $0.type == .diaperDirty }.count
        let both = diaperActivities.filter { $0.type == .diaperBoth }.count

        // Stool color
        var colorDist: [Activity.StoolColor: Int] = [:]
        for act in diaperActivities {
            if let color = act.stoolColor {
                colorDist[color, default: 0] += 1
            }
        }

        // Consistency
        var consistDist: [Activity.StoolConsistency: Int] = [:]
        for act in diaperActivities {
            if let consistency = act.stoolConsistency {
                consistDist[consistency, default: 0] += 1
            }
        }

        // Rash count
        let rashCount = diaperActivities.filter { $0.hasRash == true }.count

        // Daily counts
        let dailyCounts = groupByDay(diaperActivities)
            .map { (date: $0.key, count: $0.value.count) }
            .sorted { $0.date < $1.date }

        return DiaperPattern(
            totalCount: totalCount,
            dailyAverage: dailyAverage,
            wetVsDirtyRatio: (wet: wet, dirty: dirty, both: both),
            stoolColorDistribution: colorDist,
            consistencyDistribution: consistDist,
            rashCount: rashCount,
            dailyCounts: dailyCounts
        )
    }

    // MARK: - Health

    private static func analyzeHealth(activities: [Activity]) -> HealthPattern {
        let tempActivities = activities.filter { $0.type == .temperature }
        let medActivities = activities.filter { $0.type == .medication }

        // Temperature readings
        let readings = tempActivities.compactMap { act -> (date: Date, temp: Double)? in
            guard let temp = act.temperature else { return nil }
            return (date: act.startTime, temp: temp)
        }.sorted { $0.date < $1.date }

        let avgTemp: Double? = readings.isEmpty ? nil : readings.map(\.temp).reduce(0, +) / Double(readings.count)
        let highTempDays = Set(readings.filter { $0.temp >= 37.5 }.map { $0.date.startOfDay }).count

        // Medications
        var medNames: [String: Int] = [:]
        for act in medActivities {
            if let name = act.medicationName, !name.isEmpty {
                medNames[name, default: 0] += 1
            }
        }

        return HealthPattern(
            temperatureReadings: readings,
            averageTemp: avgTemp,
            highTempDays: highTempDays,
            medicationCount: medActivities.count,
            medicationNames: medNames
        )
    }

    // MARK: - Summary

    private static func analyzeSummary(activities: [Activity]) -> SummaryPattern {
        let totalRecords = activities.count
        let grouped = groupByDay(activities)

        let dayCounts = grouped.map { (date: $0.key, count: $0.value.count) }
        let mostActive = dayCounts.max(by: { $0.count < $1.count })
        let leastActive = dayCounts.min(by: { $0.count < $1.count })

        var categoryDist: [Activity.ActivityCategory: Int] = [:]
        for act in activities {
            categoryDist[act.type.category, default: 0] += 1
        }

        return SummaryPattern(
            totalRecords: totalRecords,
            mostActiveDay: mostActive,
            leastActiveDay: leastActive,
            categoryDistribution: categoryDist
        )
    }

    // MARK: - Helpers

    private static func groupByDay(_ activities: [Activity]) -> [Date: [Activity]] {
        Dictionary(grouping: activities) { $0.startTime.startOfDay }
    }

    private static func computePeakHours(activities: [Activity], topN: Int) -> [Int] {
        var hourCounts = [Int: Int]()
        for act in activities {
            let hour = Calendar.current.component(.hour, from: act.startTime)
            hourCounts[hour, default: 0] += 1
        }
        return hourCounts.sorted { $0.value > $1.value }
            .prefix(topN)
            .map(\.key)
            .sorted()
    }

    private static func computeIntervalTrend(sorted: [Activity]) -> Trend {
        guard sorted.count >= 4 else { return .stable }
        let mid = sorted.count / 2

        func avgInterval(_ slice: ArraySlice<Activity>) -> Double? {
            guard slice.count >= 2 else { return nil }
            var intervals: [TimeInterval] = []
            let arr = Array(slice)
            for i in 1..<arr.count {
                let interval = arr[i].startTime.timeIntervalSince(arr[i - 1].startTime)
                if interval < 86400 { intervals.append(interval) }
            }
            guard !intervals.isEmpty else { return nil }
            return intervals.reduce(0, +) / Double(intervals.count)
        }

        guard let firstHalf = avgInterval(sorted[..<mid]),
              let secondHalf = avgInterval(sorted[mid...]) else { return .stable }

        let ratio = secondHalf / firstHalf
        if ratio > 1.15 { return .increasing }
        if ratio < 0.85 { return .decreasing }
        return .stable
    }

    private static func computeDurationTrend(activities: [Activity]) -> Trend {
        let sorted = activities.sorted { $0.startTime < $1.startTime }
        guard sorted.count >= 4 else { return .stable }
        let mid = sorted.count / 2

        let firstDurations = sorted[..<mid].compactMap(\.duration)
        let secondDurations = sorted[mid...].compactMap(\.duration)

        guard !firstDurations.isEmpty, !secondDurations.isEmpty else { return .stable }

        let firstAvg = firstDurations.reduce(0, +) / Double(firstDurations.count)
        let secondAvg = secondDurations.reduce(0, +) / Double(secondDurations.count)

        guard firstAvg > 0 else { return .stable }
        let ratio = secondAvg / firstAvg
        if ratio > 1.15 { return .increasing }
        if ratio < 0.85 { return .decreasing }
        return .stable
    }

    // MARK: - AI Prompt Builder

    static func buildAIPrompt(report: PatternReport, babyName: String, babyAge: String, gender: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d"
        let startStr = dateFormatter.string(from: report.startDate)
        let endStr = dateFormatter.string(from: report.endDate)

        var lines: [String] = []
        lines.append("아기 정보: \(babyName), \(babyAge), \(gender)")
        lines.append("기간: 최근 \(report.period) (\(startStr)~\(endStr))")
        lines.append("")

        // Feeding
        let f = report.feeding
        lines.append("[수유 패턴]")
        lines.append("- 총 \(f.totalCount)회, 일평균 \(String(format: "%.1f", f.dailyAverage))회")
        if let interval = f.averageInterval {
            lines.append("- 평균 간격: \(interval.shortDuration) (\(f.intervalTrend.rawValue) 추세)")
        }
        if f.breastVsBottleRatio.breast + f.breastVsBottleRatio.bottle > 0 {
            lines.append("- 모유:\(f.breastVsBottleRatio.breast) 분유:\(f.breastVsBottleRatio.bottle)")
        }
        if f.totalMl > 0 {
            lines.append("- 수유량: 일평균 \(String(format: "%.0f", f.dailyMlAverage))ml")
        }
        if !f.peakHours.isEmpty {
            lines.append("- 피크 시간: \(f.peakHours.map { "\($0)시" }.joined(separator: ", "))")
        }
        lines.append("")

        // Sleep
        let s = report.sleep
        lines.append("[수면 패턴]")
        lines.append("- 일평균 \(String(format: "%.1f", s.dailyAverageHours))시간 (\(s.durationTrend.rawValue) 추세)")
        lines.append("- 1회 평균: \(s.averageDuration.shortDuration)")
        if !s.qualityDistribution.isEmpty {
            let total = Double(s.qualityDistribution.values.reduce(0, +))
            let qualityTexts = s.qualityDistribution.map { key, value in
                "\(key.displayName) \(Int(Double(value) / total * 100))%"
            }
            lines.append("- 수면 질: \(qualityTexts.joined(separator: ", "))")
        }
        if !s.methodDistribution.isEmpty {
            let total = Double(s.methodDistribution.values.reduce(0, +))
            let methodTexts = s.methodDistribution.map { key, value in
                "\(key.displayName) \(Int(Double(value) / total * 100))%"
            }
            lines.append("- 잠드는 방법: \(methodTexts.joined(separator: ", "))")
        }
        lines.append("")

        // Diaper
        let d = report.diaper
        lines.append("[배변 패턴]")
        lines.append("- 총 \(d.totalCount)회, 일평균 \(String(format: "%.1f", d.dailyAverage))회")
        lines.append("- 소변:\(d.wetVsDirtyRatio.wet) 대변:\(d.wetVsDirtyRatio.dirty) 혼합:\(d.wetVsDirtyRatio.both)")
        if !d.stoolColorDistribution.isEmpty {
            let total = Double(d.stoolColorDistribution.values.reduce(0, +))
            let colorTexts = d.stoolColorDistribution.map { key, value in
                "\(key.displayName) \(Int(Double(value) / total * 100))%"
            }
            lines.append("- 대변 색: \(colorTexts.joined(separator: ", "))")
        }
        if !d.consistencyDistribution.isEmpty {
            let total = Double(d.consistencyDistribution.values.reduce(0, +))
            let consistTexts = d.consistencyDistribution.map { key, value in
                "\(key.displayName) \(Int(Double(value) / total * 100))%"
            }
            lines.append("- 농도: \(consistTexts.joined(separator: ", "))")
        }
        lines.append("- 발진: \(d.rashCount)회")
        lines.append("")

        // Health
        let h = report.health
        lines.append("[건강]")
        if let avg = h.averageTemp {
            lines.append("- 체온: 평균 \(String(format: "%.1f", avg))°C, 발열 \(h.highTempDays)일")
        }
        lines.append("- 투약: \(h.medicationCount)회")
        if !h.medicationNames.isEmpty {
            let medTexts = h.medicationNames.map { "\($0.key)(\($0.value)회)" }
            lines.append("  \(medTexts.joined(separator: ", "))")
        }
        lines.append("")
        lines.append("이 데이터를 바탕으로 아기의 행동 패턴을 분석하고 부모에게 실질적인 조언을 해주세요. 특이사항이나 주의할 점이 있으면 알려주세요.")

        return lines.joined(separator: "\n")
    }
}
