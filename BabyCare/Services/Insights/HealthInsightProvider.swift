import Foundation

/// 건강 인사이트 후보. 발열일(highTempDays), 약 복용 횟수.
/// 변화율보다 절대값이 의학적으로 의미 있는 경우가 많아 prev=0이어도 surface 가능하도록 처리.
enum HealthInsightProvider: InsightProvider {

    static func candidates(_ ctx: InsightContext) -> [InsightCandidate] {
        var out: [InsightCandidate] = []
        let cur = ctx.current.health
        let prevActs = ctx.previousActivities

        // 1) 발열일
        let prevHighTemp = countHighTempDays(in: prevActs)
        if let c = makeFeverCandidate(curDays: cur.highTempDays, prevDays: prevHighTemp, weight: ctx.weights.healthFever, sample: ctx.currentDays) {
            out.append(c)
        }

        // 2) 약 복용 횟수
        let prevMedCount = prevActs.filter { $0.type == .medication }.count
        if let c = makeMedicationCandidate(curCount: cur.medicationCount, prevCount: prevMedCount, weight: ctx.weights.healthMedication, sample: ctx.currentDays) {
            out.append(c)
        }

        return out
    }

    // MARK: - Fever

    private static func makeFeverCandidate(curDays: Int, prevDays: Int, weight: Double, sample: Int) -> InsightCandidate? {
        // 둘 다 0이면 surface 안 함
        guard curDays > 0 || prevDays > 0 else { return nil }
        // prev=0인데 curDays>0이면 changePct=무한대 → 큰 양수로 강조 (300%)
        let changePct: Double
        if prevDays == 0 {
            changePct = 300
        } else {
            changePct = (Double(curDays) - Double(prevDays)) / Double(prevDays) * 100
        }
        let trend = Self.trend(for: changePct)
        let title: String
        if curDays > 0 && prevDays == 0 {
            title = "발열 \(curDays)일 발생"
        } else if curDays == 0 && prevDays > 0 {
            title = "발열 사라짐"
        } else if trend == .stable {
            title = "발열일 안정 (\(curDays)일)"
        } else {
            title = "발열일 \(trend == .increasing ? "증가" : "감소")"
        }
        let detail = "\(prevDays)일 → \(curDays)일 (전주 대비)"
        return InsightCandidate(
            category: .health, metricKey: "health.fever",
            title: title, detail: detail,
            changePercent: changePct, trend: trend,
            medicalWeight: weight, sampleSize: sample
        )
    }

    // MARK: - Medication

    private static func makeMedicationCandidate(curCount: Int, prevCount: Int, weight: Double, sample: Int) -> InsightCandidate? {
        guard curCount > 0 || prevCount > 0 else { return nil }
        let changePct: Double
        if prevCount == 0 {
            changePct = 200
        } else {
            changePct = (Double(curCount) - Double(prevCount)) / Double(prevCount) * 100
        }
        let trend = Self.trend(for: changePct)
        let title = trend == .stable
            ? "약 복용 안정 (\(curCount)회)"
            : "약 복용 \(Int(abs(changePct).rounded()))% \(trend == .increasing ? "증가" : "감소")"
        let detail = "\(prevCount)회 → \(curCount)회 (전주 대비)"
        return InsightCandidate(
            category: .health, metricKey: "health.medication",
            title: title, detail: detail,
            changePercent: changePct, trend: trend,
            medicalWeight: weight, sampleSize: sample
        )
    }

    // MARK: - Helpers

    /// 활동 배열 내 38°C 이상 체온 기록이 있는 날(unique date) 수.
    private static func countHighTempDays(in activities: [Activity]) -> Int {
        let cal = Calendar.current
        let highTempDates: Set<Date> = Set(
            activities
                .filter { $0.type == .temperature && ($0.temperature ?? 0) >= 38.0 }
                .map { cal.startOfDay(for: $0.startTime) }
        )
        return highTempDates.count
    }

    private static func trend(for changePct: Double) -> Trend {
        if abs(changePct) < 5 { return .stable }
        return changePct > 0 ? .increasing : .decreasing
    }
}
