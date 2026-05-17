import Foundation

/// 수유 인사이트 후보. 횟수, 용량(mL), 평균 간격을 각각 별도 candidate로 만듦.
enum FeedingInsightProvider: InsightProvider {

    static func candidates(_ ctx: InsightContext) -> [InsightCandidate] {
        var out: [InsightCandidate] = []
        let cur = ctx.current.feeding
        let prevActs = ctx.previousActivities.filter { $0.type.category == .feeding }
        let prevDays = max(1, ctx.previousDays)

        // 1) 수유 횟수
        if let c = makeCountCandidate(cur: cur, prevActs: prevActs, prevDays: prevDays, weight: ctx.weights.feedingCount, sample: ctx.currentDays) {
            out.append(c)
        }

        // 2) 수유 용량 (mL)
        if let c = makeVolumeCandidate(cur: cur, prevActs: prevActs, prevDays: prevDays, weight: ctx.weights.feedingVolume, sample: ctx.currentDays) {
            out.append(c)
        }

        // 3) 평균 간격
        if let c = makeIntervalCandidate(cur: cur, prevActs: prevActs, weight: ctx.weights.feedingInterval, sample: ctx.currentDays) {
            out.append(c)
        }

        return out
    }

    // MARK: - Count

    private static func makeCountCandidate(
        cur: FeedingPattern, prevActs: [Activity], prevDays: Int,
        weight: Double, sample: Int
    ) -> InsightCandidate? {
        let prevCount = Double(prevActs.count)
        let prevDailyAvg = prevCount / Double(prevDays)
        guard prevDailyAvg > 0 else { return nil }
        let curDailyAvg = cur.dailyAverage
        let changePct = (curDailyAvg - prevDailyAvg) / prevDailyAvg * 100
        let trend = Self.trend(for: changePct)
        let title = trend == .stable
            ? "수유 횟수 안정화"
            : "수유 횟수 \(Int(abs(changePct).rounded()))% \(trend == .increasing ? "증가" : "감소")"
        let detail = "일 평균 \(fmt(prevDailyAvg))회 → \(fmt(curDailyAvg))회 (전주 대비)"
        return InsightCandidate(
            category: .feeding, metricKey: "feeding.count",
            currentValue: curDailyAvg,
            title: title, detail: detail,
            changePercent: changePct, trend: trend,
            medicalWeight: weight, sampleSize: sample
        )
    }

    // MARK: - Volume

    private static func makeVolumeCandidate(
        cur: FeedingPattern, prevActs: [Activity], prevDays: Int,
        weight: Double, sample: Int
    ) -> InsightCandidate? {
        let prevTotalMl = prevActs.compactMap(\.amount).reduce(0, +)
        guard prevTotalMl > 0 else { return nil }
        let prevDailyMl = prevTotalMl / Double(prevDays)
        let curDailyMl = cur.dailyMlAverage
        guard curDailyMl > 0 else { return nil }
        let changePct = (curDailyMl - prevDailyMl) / prevDailyMl * 100
        let trend = Self.trend(for: changePct)
        let title = trend == .stable
            ? "수유 용량 안정화"
            : "수유 용량 \(Int(abs(changePct).rounded()))% \(trend == .increasing ? "증가" : "감소")"
        let detail = "일 평균 \(Int(prevDailyMl.rounded()))mL → \(Int(curDailyMl.rounded()))mL (전주 대비)"
        return InsightCandidate(
            category: .feeding, metricKey: "feeding.volume",
            currentValue: curDailyMl,
            title: title, detail: detail,
            changePercent: changePct, trend: trend,
            medicalWeight: weight, sampleSize: sample
        )
    }

    // MARK: - Interval

    private static func makeIntervalCandidate(
        cur: FeedingPattern, prevActs: [Activity],
        weight: Double, sample: Int
    ) -> InsightCandidate? {
        guard let curInterval = cur.averageInterval, curInterval > 0 else { return nil }
        let sortedPrev = prevActs.sorted { $0.startTime < $1.startTime }
        guard sortedPrev.count >= 2 else { return nil }
        var prevIntervals: [TimeInterval] = []
        for i in 1..<sortedPrev.count {
            let gap = sortedPrev[i].startTime.timeIntervalSince(sortedPrev[i - 1].startTime)
            if gap < AppConstants.secondsPerDay { prevIntervals.append(gap) }
        }
        guard !prevIntervals.isEmpty else { return nil }
        let prevAvg = prevIntervals.reduce(0, +) / Double(prevIntervals.count)
        guard prevAvg > 0 else { return nil }
        let changePct = (curInterval - prevAvg) / prevAvg * 100
        let trend = Self.trend(for: changePct)
        let curHr = curInterval / 3600
        let prevHr = prevAvg / 3600
        let title = trend == .stable
            ? "수유 간격 안정화"
            : "수유 간격 \(Int(abs(changePct).rounded()))% \(trend == .increasing ? "길어짐" : "짧아짐")"
        let detail = "평균 \(fmt(prevHr))시간 → \(fmt(curHr))시간 (전주 대비)"
        return InsightCandidate(
            category: .feeding, metricKey: "feeding.interval",
            currentValue: curHr,
            title: title, detail: detail,
            changePercent: changePct, trend: trend,
            medicalWeight: weight, sampleSize: sample
        )
    }

    // MARK: - Helpers

    private static func trend(for changePct: Double) -> Trend {
        if abs(changePct) < 5 { return .stable }
        return changePct > 0 ? .increasing : .decreasing
    }

    private static func fmt(_ v: Double) -> String {
        String(format: "%.1f", v)
    }
}
