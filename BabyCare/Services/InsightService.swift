import Foundation

// MARK: - Insight Model

struct DashboardInsight: Identifiable {
    let id = UUID()
    let kind: Kind
    let icon: String
    let colorName: String
    let primaryText: String
    let secondaryText: String?

    enum Kind {
        case feeding
        case sleep
        case health
        case milestone
    }
}

// MARK: - InsightService

/// 대시보드 컨텍스트 인사이트 카드 4종을 생성하는 단일 책임 서비스.
/// Views → Services 직접 참조 금지 원칙에 따라 ViewModel을 통해서만 노출됨.
@MainActor @Observable
final class InsightService {

    // MARK: - Published State

    private(set) var insights: [DashboardInsight] = []

    // MARK: - Public API

    /// 인사이트를 갱신합니다.
    /// - Parameters:
    ///   - todayActivities: 오늘의 전체 활동 기록
    ///   - recentActivities: 최근 7일 활동 기록 (오늘 제외)
    ///   - recentTemperatureActivities: 최근 48시간 체온 활동 기록
    ///   - baby: 선택된 아기 정보
    ///   - pendingMilestones: 아직 달성하지 못한 마일스톤 목록
    func refresh(
        todayActivities: [Activity],
        recentActivities: [Activity],
        recentTemperatureActivities: [Activity],
        baby: Baby?,
        pendingMilestones: [Milestone]
    ) {
        var result: [DashboardInsight] = []

        if let feeding = makeFeedingInsight(
            todayActivities: todayActivities,
            recentActivities: recentActivities
        ) {
            result.append(feeding)
        }

        if let sleep = makeSleepInsight(
            todayActivities: todayActivities,
            recentActivities: recentActivities,
            baby: baby
        ) {
            result.append(sleep)
        }

        if let health = makeHealthInsight(
            recentTemperatureActivities: recentTemperatureActivities
        ) {
            result.append(health)
        }

        if let milestone = makeMilestoneInsight(
            baby: baby,
            pendingMilestones: pendingMilestones
        ) {
            result.append(milestone)
        }

        insights = result
    }

    // MARK: - Feeding Insight

    /// 오늘 수유 횟수와 최근 7일 일평균을 비교합니다.
    func makeFeedingInsight(
        todayActivities: [Activity],
        recentActivities: [Activity]
    ) -> DashboardInsight? {
        let todayCount = todayActivities.filter { $0.type.category == .feeding }.count
        guard todayCount > 0 else { return nil }

        let recentFeedings = recentActivities.filter { $0.type.category == .feeding }
        let calendar = Calendar.current

        // 최근 7일 일평균 (오늘 제외)
        let days = Set(recentFeedings.map {
            calendar.startOfDay(for: $0.startTime)
        }).count
        let dailyAverage: Double = days > 0
            ? Double(recentFeedings.count) / Double(days)
            : Double(todayCount)

        let diff = todayCount - Int(dailyAverage.rounded())
        let primaryText: String
        let secondaryText: String?

        if diff == 0 || dailyAverage <= 0 {
            primaryText = String(
                format: NSLocalizedString("insight.feeding.normal", comment: ""),
                todayCount
            )
            secondaryText = NSLocalizedString("insight.feeding.normal.sub", comment: "")
        } else if diff > 0 {
            primaryText = String(
                format: NSLocalizedString("insight.feeding.more", comment: ""),
                todayCount
            )
            secondaryText = String(
                format: NSLocalizedString("insight.feeding.more.sub", comment: ""),
                diff
            )
        } else {
            primaryText = String(
                format: NSLocalizedString("insight.feeding.less", comment: ""),
                todayCount
            )
            secondaryText = String(
                format: NSLocalizedString("insight.feeding.less.sub", comment: ""),
                abs(diff)
            )
        }

        return DashboardInsight(
            kind: .feeding,
            icon: "drop.fill",
            colorName: "feedingColor",
            primaryText: primaryText,
            secondaryText: secondaryText
        )
    }

    // MARK: - Sleep Insight

    /// 마지막 수면 기록을 바탕으로 낮잠 예상 시간을 추정합니다.
    func makeSleepInsight(
        todayActivities: [Activity],
        recentActivities: [Activity],
        baby: Baby?
    ) -> DashboardInsight? {
        let allSleeps = (recentActivities + todayActivities)
            .filter { $0.type == .sleep }
            .sorted { $0.startTime < $1.startTime }

        guard let lastSleep = allSleeps.last else { return nil }

        // 현재 수면 중이면 예측 불필요
        let isCurrentlySleeping = todayActivities.contains {
            $0.type == .sleep && $0.endTime == nil
        }
        guard !isCurrentlySleeping else { return nil }

        // 최근 수면들의 평균 간격 계산 (낮잠 간격 추정)
        let ageMonths = baby.map {
            Calendar.current.dateComponents([.month], from: $0.birthDate, to: Date()).month ?? 6
        } ?? 6

        let typicalNapIntervalHours = napIntervalHours(ageMonths: ageMonths)
        let napInterval = typicalNapIntervalHours * 3600

        // 수면 간격 계산 (실제 데이터 기반)
        var intervals: [TimeInterval] = []
        let daySleeps = allSleeps.filter { sleep in
            let hour = Calendar.current.component(.hour, from: sleep.startTime)
            return hour >= 6 && hour < 20  // 낮잠만
        }
        if daySleeps.count >= 2 {
            for i in 1..<daySleeps.count {
                let gap = daySleeps[i].startTime.timeIntervalSince(
                    daySleeps[i - 1].endTime ?? daySleeps[i - 1].startTime
                )
                if gap > 0 && gap < 7 * 3600 {
                    intervals.append(gap)
                }
            }
        }

        let effectiveInterval = intervals.isEmpty
            ? napInterval
            : intervals.reduce(0, +) / Double(intervals.count)

        let sleepEnd = lastSleep.endTime ?? lastSleep.startTime
        let nextNapEstimate = sleepEnd.addingTimeInterval(effectiveInterval)
        let now = Date()
        let remaining = nextNapEstimate.timeIntervalSince(now)

        // 다음 낮잠이 너무 멀거나 이미 지났으면 카드 생략
        guard remaining > -1800 && remaining < 4 * 3600 else { return nil }

        let primaryText: String
        let secondaryText: String?

        if remaining <= 0 {
            primaryText = NSLocalizedString("insight.sleep.now", comment: "")
            secondaryText = NSLocalizedString("insight.sleep.now.sub", comment: "")
        } else {
            let minutes = Int(remaining / 60)
            if minutes < 60 {
                primaryText = String(
                    format: NSLocalizedString("insight.sleep.soon", comment: ""),
                    minutes
                )
            } else {
                let hours = minutes / 60
                let mins = minutes % 60
                primaryText = String(
                    format: NSLocalizedString("insight.sleep.later", comment: ""),
                    hours,
                    mins
                )
            }
            secondaryText = NSLocalizedString("insight.sleep.sub", comment: "")
        }

        return DashboardInsight(
            kind: .sleep,
            icon: "moon.zzz.fill",
            colorName: "sleepColor",
            primaryText: primaryText,
            secondaryText: secondaryText
        )
    }

    // MARK: - Health Insight

    /// 최근 48시간 체온 기록에서 38도 이상 연속 발열 일수를 감지합니다.
    func makeHealthInsight(
        recentTemperatureActivities: [Activity]
    ) -> DashboardInsight? {
        let highTempThreshold = 38.0
        let highTemps = recentTemperatureActivities.filter {
            ($0.temperature ?? 0) >= highTempThreshold
        }
        guard !highTemps.isEmpty else { return nil }

        let calendar = Calendar.current
        let highTempDays = Set(highTemps.map {
            calendar.startOfDay(for: $0.startTime)
        }).count

        let latestTemp = highTemps.max(by: { $0.startTime < $1.startTime })?.temperature ?? highTempThreshold

        let primaryText: String
        let secondaryText: String?

        if highTempDays >= 2 {
            primaryText = String(
                format: NSLocalizedString("insight.health.fever.consecutive", comment: ""),
                highTempDays
            )
            secondaryText = NSLocalizedString("insight.health.fever.consecutive.sub", comment: "")
        } else {
            primaryText = String(
                format: NSLocalizedString("insight.health.fever.today", comment: ""),
                String(format: "%.1f", latestTemp)
            )
            secondaryText = NSLocalizedString("insight.health.fever.today.sub", comment: "")
        }

        return DashboardInsight(
            kind: .health,
            icon: "thermometer.medium",
            colorName: "temperatureColor",
            primaryText: primaryText,
            secondaryText: secondaryText
        )
    }

    // MARK: - Milestone Insight

    /// 아기 월령에 맞는 다음 미달성 마일스톤을 반환합니다.
    func makeMilestoneInsight(
        baby: Baby?,
        pendingMilestones: [Milestone]
    ) -> DashboardInsight? {
        guard let baby = baby else { return nil }
        guard !pendingMilestones.isEmpty else { return nil }

        let ageMonths = Calendar.current.dateComponents(
            [.month], from: baby.birthDate, to: Date()
        ).month ?? 0

        // 현재 월령 이후에 예상되는 마일스톤 중 가장 이른 것
        let upcoming = pendingMilestones
            .filter { milestone in
                let expected = milestone.expectedAgeMonths ?? 0
                return expected >= ageMonths
            }
            .sorted { ($0.expectedAgeMonths ?? 0) < ($1.expectedAgeMonths ?? 0) }
            .first

        guard let next = upcoming else {
            // 현재 월령보다 낮은 예상값의 마일스톤 중 가장 가까운 것 표시
            let overdue = pendingMilestones
                .sorted { ($0.expectedAgeMonths ?? 0) < ($1.expectedAgeMonths ?? 0) }
                .last
            guard let ms = overdue else { return nil }
            let start = ms.expectedAgeMonths ?? 0
            let end = ms.expectedAgeRangeEnd ?? start
            let primaryText = String(
                format: NSLocalizedString("insight.milestone.next", comment: ""),
                ms.title
            )
            let secondaryText = end > start
                ? String(format: NSLocalizedString("insight.milestone.range", comment: ""), start, end)
                : String(format: NSLocalizedString("insight.milestone.month", comment: ""), start)
            return DashboardInsight(
                kind: .milestone,
                icon: "star.fill",
                colorName: "solidColor",
                primaryText: primaryText,
                secondaryText: secondaryText
            )
        }

        let start = next.expectedAgeMonths ?? 0
        let end = next.expectedAgeRangeEnd ?? start

        let primaryText = String(
            format: NSLocalizedString("insight.milestone.next", comment: ""),
            next.title
        )
        let secondaryText = end > start
            ? String(format: NSLocalizedString("insight.milestone.range", comment: ""), start, end)
            : String(format: NSLocalizedString("insight.milestone.month", comment: ""), start)

        return DashboardInsight(
            kind: .milestone,
            icon: "star.fill",
            colorName: "solidColor",
            primaryText: primaryText,
            secondaryText: secondaryText
        )
    }

    // MARK: - Sleep Regression Insight

    /// 수면 퇴행 감지 시 대시보드 인사이트 카드를 생성합니다.
    /// - 이 카드는 정보 제공 목적이며 의학적 진단이 아닙니다.
    func makeSleepRegressionInsight(
        allSleepActivities: [Activity],
        baby: Baby?
    ) -> DashboardInsight? {
        let babyAgeMonths: Int
        if let baby {
            babyAgeMonths = Calendar.current.dateComponents(
                [.month], from: baby.birthDate, to: Date()
            ).month ?? 0
        } else {
            babyAgeMonths = 0
        }

        let warning: SleepRegressionWarning?
        if babyAgeMonths > 0 {
            warning = SleepAnalysisService.detectRegression(
                sleepActivities: allSleepActivities,
                babyAgeMonths: babyAgeMonths
            )
        } else {
            warning = SleepAnalysisService.detectRegression(sleepActivities: allSleepActivities)
        }
        guard let warning else { return nil }

        let declinePct = Int(abs((warning.declineRate ?? 0) * 100))
        let primaryText = String(
            format: NSLocalizedString("sleep.regression.primary", comment: ""),
            declinePct
        )
        let secondaryText = NSLocalizedString("sleep.regression.secondary", comment: "")

        return DashboardInsight(
            kind: .sleep,
            icon: "exclamationmark.triangle.fill",
            colorName: "sleepColor",
            primaryText: primaryText,
            secondaryText: secondaryText
        )
    }

    // MARK: - Helpers

    /// 월령별 낮잠 간격 (시간) 기준값
    func napIntervalHours(ageMonths: Int) -> Double {
        switch ageMonths {
        case 0...2:   return 1.0
        case 3...5:   return 1.5
        case 6...8:   return 2.0
        case 9...11:  return 2.5
        case 12...17: return 3.0
        default:      return 4.0
        }
    }
}
