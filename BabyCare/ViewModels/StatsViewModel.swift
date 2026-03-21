import Foundation

@MainActor @Observable
final class StatsViewModel {
    var weeklyActivities: [Activity] = []
    var isLoading = false
    var errorMessage: String?
    var selectedPeriod: StatsPeriod = .week

    enum StatsPeriod: String, CaseIterable {
        case week = "주간"
        case month = "월간"
    }

    private let firestoreService = FirestoreService.shared

    // MARK: - Computed Feeding Stats

    var feedingActivities: [Activity] {
        weeklyActivities.filter { $0.type.category == .feeding }
    }

    var dailyFeedingCounts: [(date: Date, count: Int)] {
        groupByDay(feedingActivities).map { ($0.key, $0.value.count) }
            .sorted { $0.date < $1.date }
    }

    var dailyFeedingAmounts: [(date: Date, amount: Double)] {
        groupByDay(feedingActivities).map { date, activities in
            (date, activities.compactMap(\.amount).reduce(0, +))
        }
        .sorted { $0.date < $1.date }
    }

    var averageFeedingInterval: TimeInterval? {
        let sorted = feedingActivities.sorted { $0.startTime < $1.startTime }
        guard sorted.count >= 2 else { return nil }
        var intervals: [TimeInterval] = []
        for i in 1..<sorted.count {
            let interval = sorted[i].startTime.timeIntervalSince(sorted[i-1].startTime)
            // 밤사이 공백(6시간 초과) 제외 — 평균 수유 간격 왜곡 방지
            if interval <= 21600 {
                intervals.append(interval)
            }
        }
        guard !intervals.isEmpty else { return nil }
        return intervals.reduce(0, +) / Double(intervals.count)
    }

    // MARK: - Computed Sleep Stats

    var sleepActivities: [Activity] {
        weeklyActivities.filter { $0.type == .sleep }
    }

    var dailySleepDurations: [(date: Date, hours: Double)] {
        groupByDay(sleepActivities).map { date, activities in
            (date, activities.compactMap(\.duration).reduce(0, +) / 3600)
        }
        .sorted { $0.date < $1.date }
    }

    var averageSleepHours: Double {
        let durations = dailySleepDurations
        guard !durations.isEmpty else { return 0 }
        return durations.map(\.hours).reduce(0, +) / Double(durations.count)
    }

    // MARK: - Computed Diaper Stats

    var diaperActivities: [Activity] {
        weeklyActivities.filter { $0.type.category == .diaper }
    }

    var dailyDiaperCounts: [(date: Date, count: Int)] {
        groupByDay(diaperActivities).map { ($0.key, $0.value.count) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Load Data

    func loadStats(userId: String, babyId: String) async {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let endDate = Date()
        let startDate: Date

        switch selectedPeriod {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        }

        do {
            weeklyActivities = try await firestoreService.fetchActivities(
                userId: userId, babyId: babyId,
                from: startDate.startOfDay, to: endDate.endOfDay
            )
        } catch {
            weeklyActivities = []
            errorMessage = "통계 데이터를 불러오지 못했습니다."
        }
    }

    // MARK: - Helper

    private func groupByDay(_ activities: [Activity]) -> [Date: [Activity]] {
        Dictionary(grouping: activities) { $0.startTime.startOfDay }
    }
}
