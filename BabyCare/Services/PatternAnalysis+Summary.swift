import Foundation

extension PatternAnalysisService {
        // MARK: - Summary

    static func analyzeSummary(activities: [Activity]) -> SummaryPattern {
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

    static func groupByDay(_ activities: [Activity]) -> [Date: [Activity]] {
        Dictionary(grouping: activities) { $0.startTime.startOfDay }
    }

    static func computePeakHours(activities: [Activity], topN: Int) -> [Int] {
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

    static func computeIntervalTrend(sorted: [Activity]) -> Trend {
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

    static func computeDurationTrend(activities: [Activity]) -> Trend {
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
