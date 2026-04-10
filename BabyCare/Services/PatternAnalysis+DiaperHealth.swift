import Foundation

extension PatternAnalysisService {
        // MARK: - Diaper

    static func analyzeDiaper(activities: [Activity], days: Int) -> DiaperPattern {
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
            dailyCounts: dailyCounts,
            previousDailyAverage: nil
        )
    }

    // MARK: - Health

    static func analyzeHealth(activities: [Activity]) -> HealthPattern {
        let tempActivities = activities.filter { $0.type == .temperature }
        let medActivities = activities.filter { $0.type == .medication }

        // Temperature readings
        let readings = tempActivities.compactMap { act -> (date: Date, temp: Double)? in
            guard let temp = act.temperature else { return nil }
            return (date: act.startTime, temp: temp)
        }.sorted { $0.date < $1.date }

        let avgTemp: Double? = readings.isEmpty ? nil : readings.map(\.temp).reduce(0, +) / Double(readings.count)
        let highTempDays = Set(readings.filter { $0.temp >= ReferenceTable.feverThreshold }.map { $0.date.startOfDay }).count

        // Consecutive fever days
        let feverDays = readings
            .filter { $0.temp >= ReferenceTable.feverThreshold }
            .map { Calendar.current.startOfDay(for: $0.date) }
        let uniqueFeverDays = Array(Set(feverDays)).sorted()

        var consecutiveFeverDays = 0
        var currentStreak = 0
        for i in 0..<uniqueFeverDays.count {
            if i == 0 {
                currentStreak = 1
            } else {
                let diff = Calendar.current.dateComponents([.day], from: uniqueFeverDays[i - 1], to: uniqueFeverDays[i]).day ?? 0
                if diff == 1 {
                    currentStreak += 1
                } else {
                    currentStreak = 1
                }
            }
            if currentStreak > consecutiveFeverDays {
                consecutiveFeverDays = currentStreak
            }
        }

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
            medicationNames: medNames,
            consecutiveFeverDays: consecutiveFeverDays
        )
    }
}
