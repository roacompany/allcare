import Foundation

// MARK: - Step 1: 전처리 엔진

enum Preprocessor {

    // MARK: - 분석 기간 계산

    static func analysisPeriod(
        scheduledDate: Date,
        previousVisitDate: Date?
    ) -> AnalysisPeriod {
        let calendar = Calendar.current
        let to = calendar.date(byAdding: .day, value: -1, to: scheduledDate) ?? scheduledDate

        let rawFrom: Date
        if let prev = previousVisitDate {
            rawFrom = prev
        } else {
            rawFrom = calendar.date(byAdding: .day, value: -90, to: scheduledDate) ?? scheduledDate
        }

        // 최대 90일 클램프: rawFrom이 90일보다 이전이면 90일 전으로 제한
        let maxFrom = calendar.date(byAdding: .day, value: -90, to: scheduledDate) ?? rawFrom
        let clampedFrom = max(rawFrom, maxFrom)  // 더 최근 날짜 선택 = 기간 단축

        // 최소 7일 보장: clampedFrom이 to-7d보다 늦으면(기간 < 7일) to-7d로 확장
        // 단, previousVisitDate가 설정된 경우 해당 날짜를 최대한 존중
        let minFrom = calendar.date(byAdding: .day, value: -7, to: to) ?? to
        let finalFrom: Date
        if previousVisitDate != nil {
            // 이전 방문이 있으면 최소 7일 강제 확장하지 않음 (이전 방문 이전 데이터 오염 방지)
            finalFrom = clampedFrom
        } else {
            // 이전 방문 없는 경우(첫 방문)만 최소 7일 보장
            finalFrom = min(clampedFrom, minFrom)
        }
        return AnalysisPeriod(from: finalFrom, to: to)
    }

    // MARK: - 교정 연령 계산

    static func correctedAgeInDays(
        birthDate: Date,
        gestationalWeeks: Int = 40,
        referenceDate: Date = Date()
    ) -> Int {
        let calendar = Calendar.current
        let chronologicalDays = calendar.dateComponents([.day], from: birthDate, to: referenceDate).day ?? 0

        // 조산아 보정: 재태주수 37주 미만이면 만삭(40주)과의 차이만큼 차감
        if gestationalWeeks < 37 {
            let correctionDays = (40 - gestationalWeeks) * 7
            return max(0, chronologicalDays - correctionDays)
        }
        return chronologicalDays
    }

    // MARK: - 일별 집계

    static func aggregate(
        activities: [Activity],
        period: AnalysisPeriod
    ) -> [DailyAggregate] {
        let calendar = Calendar.current

        // 기간 내 날짜 목록 생성
        var current = calendar.startOfDay(for: period.from)
        let end = calendar.startOfDay(for: period.to)
        var dates: [Date] = []
        while current <= end {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        // 날짜별 활동 그룹화
        let grouped = Dictionary(grouping: activities.filter {
            $0.startTime >= period.from && $0.startTime <= period.to
        }) { calendar.startOfDay(for: $0.startTime) }

        var aggregates: [DailyAggregate] = []
        var previousAggregate: DailyAggregate?

        for date in dates {
            let dayActivities = grouped[date] ?? []

            if dayActivities.isEmpty, let prev = previousAggregate {
                // LOCF: 이전 값으로 채움
                var filled = prev
                filled.date = date
                filled.isMissingData = true
                aggregates.append(filled)
                previousAggregate = filled
                continue
            }

            let feeding = dayActivities.filter { $0.type.category == .feeding }
            let sleep = dayActivities.filter { $0.type == .sleep }
            let diaper = dayActivities.filter { $0.type.category == .diaper }
            let temps = dayActivities.compactMap { $0.temperature }

            let feedingCount = feeding.count
            let feedingAmount = feeding.compactMap { $0.amount }.reduce(0, +)
            let sleepMinutes = sleep.compactMap { $0.duration }.reduce(0, +) / 60.0
            let diaperCount = diaper.count
            let avgTemp = temps.isEmpty ? nil : temps.reduce(0, +) / Double(temps.count)

            // 이상치 검사 (기저귀 횟수 IQR×3 단순 플래그 — 집계 후 BaselineDetector에서 정밀 검사)
            let hasOutlier = feedingCount > 20 || sleepMinutes > 1440 || diaperCount > 25

            let agg = DailyAggregate(
                date: date,
                feedingCount: feedingCount,
                feedingAmountMl: feedingAmount,
                sleepMinutes: sleepMinutes,
                diaperCount: diaperCount,
                avgTemperature: avgTemp,
                isMissingData: false,
                hasOutlier: hasOutlier
            )
            aggregates.append(agg)
            previousAggregate = agg
        }

        // 연속 결측 3일 초과 MNAR 경고 (콘솔 로그)
        let missingRuns = aggregates.filter { $0.isMissingData }.count
        if missingRuns > 3 {
            print("[Analysis] MNAR 경고: \(missingRuns)일 결측 — 분석 신뢰도 저하")
        }

        return aggregates
    }
}
