import Foundation

/// 배변 인사이트 후보. 소변(wet) / 대변(dirty) / 발진(rash) 각각 별도 candidate.
enum DiaperInsightProvider: InsightProvider {

    static func candidates(_ ctx: InsightContext) -> [InsightCandidate] {
        var out: [InsightCandidate] = []
        let cur = ctx.current.diaper
        let prevDiapers = ctx.previousActivities.filter { $0.type.category == .diaper }
        let prevDays = max(1, ctx.previousDays)
        let curDays = max(1, ctx.currentDays)

        // 1) 소변 (wet, both 포함)
        let curWet = cur.wetVsDirtyRatio.wet + cur.wetVsDirtyRatio.both
        let prevWet = prevDiapers.filter { $0.type == .diaperWet || $0.type == .diaperBoth }.count
        if let c = subMetricCandidate(
            label: "소변",
            metricKey: "diaper.wet",
            curCount: curWet, curDays: curDays,
            prevCount: prevWet, prevDays: prevDays,
            weight: ctx.weights.diaperWet, sample: curDays
        ) {
            out.append(c)
        }

        // 2) 대변 (dirty, both 포함)
        let curDirty = cur.wetVsDirtyRatio.dirty + cur.wetVsDirtyRatio.both
        let prevDirty = prevDiapers.filter { $0.type == .diaperDirty || $0.type == .diaperBoth }.count
        if let c = subMetricCandidate(
            label: "대변",
            metricKey: "diaper.dirty",
            curCount: curDirty, curDays: curDays,
            prevCount: prevDirty, prevDays: prevDays,
            weight: ctx.weights.diaperDirty, sample: curDays
        ) {
            out.append(c)
        }

        return out
    }

    // MARK: - Sub-metric candidate

    private static func subMetricCandidate(
        label: String, metricKey: String,
        curCount: Int, curDays: Int,
        prevCount: Int, prevDays: Int,
        weight: Double, sample: Int
    ) -> InsightCandidate? {
        let prevDailyAvg = Double(prevCount) / Double(prevDays)
        guard prevDailyAvg > 0 else { return nil }
        let curDailyAvg = Double(curCount) / Double(curDays)
        let changePct = (curDailyAvg - prevDailyAvg) / prevDailyAvg * 100
        let trend = Self.trend(for: changePct)
        let title = trend == .stable
            ? "\(label) 안정화"
            : "\(label) \(Int(abs(changePct).rounded()))% \(trend == .increasing ? "증가" : "감소")"
        let detail = "일 평균 \(fmt(prevDailyAvg))회 → \(fmt(curDailyAvg))회 (전주 대비)"
        return InsightCandidate(
            category: .diaper, metricKey: metricKey,
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
