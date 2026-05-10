import Foundation

/// 수면 인사이트 후보. 시간(hours), 품질(quality good 비율) 각각 별도 candidate.
enum SleepInsightProvider: InsightProvider {

    static func candidates(_ ctx: InsightContext) -> [InsightCandidate] {
        var out: [InsightCandidate] = []
        let cur = ctx.current.sleep
        let prevSleep = ctx.previousActivities.filter { $0.type == .sleep }
        let prevDays = max(1, ctx.previousDays)

        // 1) 수면 시간 (hours)
        if let c = makeHoursCandidate(cur: cur, prevSleep: prevSleep, prevDays: prevDays, weight: ctx.weights.sleepHours, sample: ctx.currentDays) {
            out.append(c)
        }

        // 2) 수면 품질 (good 비율)
        if let c = makeQualityCandidate(cur: cur, prevSleep: prevSleep, weight: ctx.weights.sleepQuality, sample: ctx.currentDays) {
            out.append(c)
        }

        return out
    }

    // MARK: - Hours

    private static func makeHoursCandidate(
        cur: SleepPattern, prevSleep: [Activity], prevDays: Int,
        weight: Double, sample: Int
    ) -> InsightCandidate? {
        let prevTotalSec = prevSleep.compactMap(\.duration).reduce(0, +)
        let prevDailyHours = prevTotalSec / 3600 / Double(prevDays)
        guard prevDailyHours > 0 else { return nil }
        let curDailyHours = cur.dailyAverageHours
        guard curDailyHours > 0 else { return nil }
        let changePct = (curDailyHours - prevDailyHours) / prevDailyHours * 100
        let trend = Self.trend(for: changePct)
        let title = trend == .stable
            ? "수면 시간 안정화"
            : "수면 시간 \(Int(abs(changePct).rounded()))% \(trend == .increasing ? "증가" : "감소")"
        let detail = "일 평균 \(fmt(prevDailyHours))시간 → \(fmt(curDailyHours))시간 (전주 대비)"
        return InsightCandidate(
            category: .sleep, metricKey: "sleep.hours",
            title: title, detail: detail,
            changePercent: changePct, trend: trend,
            medicalWeight: weight, sampleSize: sample
        )
    }

    // MARK: - Quality

    private static func makeQualityCandidate(
        cur: SleepPattern, prevSleep: [Activity],
        weight: Double, sample: Int
    ) -> InsightCandidate? {
        let curGood = cur.qualityDistribution[.good] ?? 0
        let curTotal = cur.qualityDistribution.values.reduce(0, +)
        guard curTotal > 0 else { return nil }
        let curGoodRatio = Double(curGood) / Double(curTotal) * 100

        let prevQualities = prevSleep.compactMap { $0.sleepQuality }
        guard !prevQualities.isEmpty else { return nil }
        let prevGood = prevQualities.filter { $0 == .good }.count
        let prevGoodRatio = Double(prevGood) / Double(prevQualities.count) * 100
        guard prevGoodRatio > 0 else { return nil }

        // 비율의 절대 차이를 % point로 표현, changePercent는 상대 변화
        let changePct = (curGoodRatio - prevGoodRatio) / prevGoodRatio * 100
        let trend = Self.trend(for: changePct)
        let title = trend == .stable
            ? "수면 품질 안정화"
            : "수면 품질 \(Int(abs(changePct).rounded()))% \(trend == .increasing ? "개선" : "저하")"
        let detail = "좋음 비율 \(Int(prevGoodRatio.rounded()))% → \(Int(curGoodRatio.rounded()))% (전주 대비)"
        return InsightCandidate(
            category: .sleep, metricKey: "sleep.quality",
            title: title, detail: detail,
            changePercent: changePct, trend: trend,
            medicalWeight: weight, sampleSize: sample
        )
    }

    private static func trend(for changePct: Double) -> Trend {
        if abs(changePct) < 5 { return .stable }
        return changePct > 0 ? .increasing : .decreasing
    }

    private static func fmt(_ v: Double) -> String {
        String(format: "%.1f", v)
    }
}
