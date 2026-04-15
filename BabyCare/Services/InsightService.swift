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
        case vaccination
    }
}

// MARK: - InsightService

/// 대시보드 컨텍스트 인사이트 카드 4종을 생성하는 단일 책임 서비스.
/// Views → Services 직접 참조 금지 원칙에 따라 ViewModel을 통해서만 노출됨.
@MainActor @Observable
final class InsightService {

    // MARK: - Published State

    private(set) var insights: [DashboardInsight] = []

    // MARK: - Reorder Insight

    /// 재구매 임박 소모품이 있을 때 대시보드 인사이트 카드를 생성합니다.
    /// - Parameters:
    ///   - products: 재구매 임박 제품 목록 (이미 7일 이내 필터링된 목록)
    /// - Returns: 재구매 알림 카드 (제품이 없으면 nil)
    func makeReorderInsight(products: [BabyProduct]) -> DashboardInsight? {
        guard let first = products.first else { return nil }

        let primaryText: String
        let secondaryText: String?

        if products.count == 1 {
            primaryText = String(
                format: NSLocalizedString("product.reorder.insight.single", comment: ""),
                first.name
            )
            secondaryText = NSLocalizedString("product.reorder.insight.sub", comment: "")
        } else {
            primaryText = String(
                format: NSLocalizedString("product.reorder.insight.multiple", comment: ""),
                first.name,
                products.count - 1
            )
            secondaryText = NSLocalizedString("product.reorder.insight.sub", comment: "")
        }

        return DashboardInsight(
            kind: .milestone,
            icon: "cart.badge.plus",
            colorName: "warmOrangeColor",
            primaryText: primaryText,
            secondaryText: secondaryText
        )
    }

    // MARK: - Public API

    /// 인사이트를 갱신합니다.
    /// - Parameters:
    ///   - todayActivities: 오늘의 전체 활동 기록
    ///   - recentActivities: 최근 7일 활동 기록 (오늘 제외)
    ///   - recentTemperatureActivities: 최근 48시간 체온 활동 기록
    ///   - baby: 선택된 아기 정보
    ///   - pendingMilestones: 아직 달성하지 못한 마일스톤 목록
    ///   - upcomingVaccinations: 미완료 접종 목록 (D-day 카드용)
    func refresh(
        todayActivities: [Activity],
        recentActivities: [Activity],
        recentTemperatureActivities: [Activity],
        baby: Baby?,
        pendingMilestones: [Milestone],
        upcomingVaccinations: [Vaccination] = []
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

        if let vaccination = makeVaccinationInsight(upcomingVaccinations: upcomingVaccinations) {
            result.append(vaccination)
        }

        insights = result
    }

    // MARK: - Feeding Insight

    /// 오늘 수유 횟수와 "현재 시각까지 기대 횟수"를 비교합니다.
    /// 하루가 끝나지 않은 시점에 풀일 평균과 비교하면 불안 조성 — 경과 시간 비례 expected count 사용.
    func makeFeedingInsight(
        todayActivities: [Activity],
        recentActivities: [Activity],
        now: Date = Date()
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

        // 경과 시간 기반 expected count — 자정부터 현재까지 분 / 1440
        let startOfToday = calendar.startOfDay(for: now)
        let minutesElapsed = now.timeIntervalSince(startOfToday) / 60.0
        // 최소 60분 (앱 오픈 직후 분모 0 방지), 최대 1440분
        let dayFraction = min(max(minutesElapsed, 60.0), 1440.0) / 1440.0
        let expectedByNow = dailyAverage * dayFraction

        // 의미 있는 차이 임계: max(1, expected * 0.25) — 25% 편차만 경고
        let tolerance = max(1.0, expectedByNow * 0.25)
        let deltaRaw = Double(todayCount) - expectedByNow

        let primaryText: String
        let secondaryText: String?

        if dailyAverage <= 0 || abs(deltaRaw) < tolerance {
            // 정상 범위 (또는 데이터 부족) — 비교 문구 없이 현재 횟수만
            primaryText = String(
                format: NSLocalizedString("insight.feeding.normal", comment: ""),
                todayCount
            )
            secondaryText = NSLocalizedString("insight.feeding.normal.sub", comment: "")
        } else if deltaRaw > 0 {
            // 기대보다 많음 — 풀일 평균 대비 차이로 표시 (하루가 끝나야 완전 비교)
            let dailyDiff = todayCount - Int(dailyAverage.rounded())
            primaryText = String(
                format: NSLocalizedString("insight.feeding.more", comment: ""),
                todayCount
            )
            secondaryText = dailyDiff > 0 ? String(
                format: NSLocalizedString("insight.feeding.more.sub", comment: ""),
                dailyDiff
            ) : NSLocalizedString("insight.feeding.normal.sub", comment: "")
        } else {
            // 기대보다 적음 — 오후 6시 이후에만 경고 문구 노출 (새벽/오전 불안 조성 방지)
            let hour = calendar.component(.hour, from: now)
            let showLessWarning = hour >= 18
            primaryText = String(
                format: NSLocalizedString("insight.feeding.less", comment: ""),
                todayCount
            )
            if showLessWarning {
                let dailyDiff = Int(dailyAverage.rounded()) - todayCount
                secondaryText = dailyDiff > 0 ? String(
                    format: NSLocalizedString("insight.feeding.less.sub", comment: ""),
                    dailyDiff
                ) : NSLocalizedString("insight.feeding.normal.sub", comment: "")
            } else {
                secondaryText = NSLocalizedString("insight.feeding.normal.sub", comment: "")
            }
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

    // MARK: - Vaccination Insight

    /// D-7 이내인 다음 접종 일정을 대시보드 카드로 반환합니다.
    /// D-7 초과이면 카드를 표시하지 않습니다 (과도한 알림 방지).
    func makeVaccinationInsight(upcomingVaccinations: [Vaccination]) -> DashboardInsight? {
        // 완료되지 않은 접종 중 예정일이 가장 가까운 것
        let next = upcomingVaccinations
            .filter { !$0.isCompleted && $0.scheduledDate >= Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .first
        guard let vaccination = next,
              let days = vaccination.daysUntilScheduled,
              days <= 7 else { return nil }

        let primaryText: String
        if days == 0 {
            primaryText = String(
                format: NSLocalizedString("vaccination.insight.today", comment: ""),
                vaccination.vaccine.displayName,
                vaccination.doseNumber
            )
        } else {
            primaryText = String(
                format: NSLocalizedString("vaccination.insight.dday", comment: ""),
                vaccination.vaccine.displayName,
                vaccination.doseNumber,
                days
            )
        }
        let secondaryText = NSLocalizedString("vaccination.insight.sub", comment: "")

        return DashboardInsight(
            kind: .vaccination,
            icon: "syringe.fill",
            colorName: "healthColor",
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
