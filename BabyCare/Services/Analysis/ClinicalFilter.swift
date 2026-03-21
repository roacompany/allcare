import Foundation

// MARK: - Step 5: Layer 4 — 임상적 유의성 필터
// 임계값: 전문가 합의 기반 (문헌 미확정)
// ⚠️ 면책: 이 기준은 임상 관찰 기반 참고값이며 의사 판단을 대체하지 않습니다.

enum ClinicalFilter {

    // MARK: - 연령별 임상 임계값 계산

    private static func thresholds(ageInDays: Int) -> (feedingCount: Double, feedingAmount: Double, sleep: Double, diaper: Double) {
        switch ageInDays {
        case ..<90:
            // 신생아: 민감하게 — 작은 변화도 유의
            return (feedingCount: 1.0, feedingAmount: 20.0, sleep: 45.0, diaper: 1.5)
        case 90..<365:
            // 영아: 기본값
            return (feedingCount: 1.5, feedingAmount: 30.0, sleep: 60.0, diaper: 2.0)
        default:
            // 유아 (>365일): 덜 민감하게 — 더 큰 변화만 유의
            return (feedingCount: 2.0, feedingAmount: 40.0, sleep: 75.0, diaper: 2.5)
        }
    }

    // MARK: - 임상 유의성 필터

    static func filter(flags: [MetricFlag], aggregates: [DailyAggregate], ageInDays: Int = 90) -> [MetricFlag] {
        // 이상치 제거 후 임계값 비교 (BaselineDetector와 동일 기준)
        let clean = aggregates.filter { !$0.hasOutlier }
        let base = clean.isEmpty ? aggregates : clean

        let t = thresholds(ageInDays: ageInDays)

        return flags.filter { flag in
            switch flag.metric {
            case .feeding:
                let recentMean = recentMean(base.map { Double($0.feedingCount) }, days: 7)
                let baselineMean = baselineMean(base.map { Double($0.feedingCount) })
                return abs(recentMean - baselineMean) >= t.feedingCount

            case .feedingAmount:
                let recentMean = recentMean(base.map { $0.feedingAmountMl }, days: 7)
                let baselineMean = baselineMean(base.map { $0.feedingAmountMl })
                return abs(recentMean - baselineMean) >= t.feedingAmount

            case .sleep:
                let recentMean = recentMean(base.map { $0.sleepMinutes }, days: 7)
                let baselineMean = baselineMean(base.map { $0.sleepMinutes })
                return abs(recentMean - baselineMean) >= t.sleep

            case .diaper:
                let recentMean = recentMean(base.map { Double($0.diaperCount) }, days: 7)
                let baselineMean = baselineMean(base.map { Double($0.diaperCount) })
                return abs(recentMean - baselineMean) >= t.diaper

            case .temperature:
                return true  // 체온 이상은 항상 유의
            }
        }
    }

    // MARK: - 우선순위 스코어링 + 정렬
    // priority = Σ(layerWeight × σDistance)

    static func prioritize(flags: [MetricFlag], patterns: [DetectedPattern]) -> [MetricFlag] {
        let patternBonus: Double = patterns.contains(.dehydrationRisk) ? 2.0 :
                                   patterns.contains(.infectionSuspected) ? 1.5 :
                                   patterns.contains(.mildDehydrationConcern) ? 1.3 : 1.0

        return flags.map { flag in
            var f = flag
            let layerWeight: Double = flag.layer == .baseline ? 1.5 : 1.0
            f.score = layerWeight * flag.sigmaDistance * patternBonus
            return f
        }.sorted { $0.score > $1.score }
    }

    // MARK: - 체크리스트 항목 생성

    static func generateChecklist(
        flags: [MetricFlag],
        patterns: [DetectedPattern],
        ageInDays: Int
    ) -> [String] {
        var items: [String] = []

        // 패턴별 기본 질문
        if patterns.contains(.growthSpurt) {
            items.append("수유와 수면 패턴에 변화가 있었는데, 성장급등 가능성이 있나요?")
        }
        if patterns.contains(.infectionSuspected) {
            items.append("최근 열이 있었고 수면이 줄었는데, 감염 여부를 확인해 주세요.")
        }
        if patterns.contains(.dehydrationRisk) {
            items.append("수유와 기저귀 횟수가 모두 줄었습니다. 탈수 위험이 있는지 확인해 주세요.")
        }
        if patterns.contains(.mildDehydrationConcern) {
            items.append("기저귀 횟수가 줄었습니다. 수분 섭취를 확인해주세요.")
        }

        // 플래그별 세부 질문
        for flag in flags.prefix(5) {
            switch (flag.metric, flag.direction) {
            case (.feeding, .down):
                items.append("수유 횟수가 평소보다 줄었습니다. 원인이 있을까요?")
            case (.feeding, .up):
                items.append("수유 횟수가 평소보다 늘었습니다. 정상 범위인가요?")
            case (.feedingAmount, .down):
                items.append("1회 수유량이 줄었습니다. 수유 거부 징후가 있는지 확인해 주세요.")
            case (.sleep, .down):
                items.append("수면 시간이 줄었습니다. 불편감이나 통증이 원인일 수 있나요?")
            case (.sleep, .up):
                items.append("수면 시간이 늘었습니다. 이 시기의 성장에 정상적인가요?")
            case (.diaper, .down):
                items.append("기저귀 횟수가 줄었습니다. 배변 상태를 확인해 주세요.")
            case (.temperature, .up):
                items.append("체온이 높은 날이 있었습니다. 발열 원인을 확인해 주세요.")
            default:
                break
            }
        }

        // 연령별 기본 체크 항목
        if ageInDays <= 90 {
            items.append("현재 체중은 정상 성장 곡선에 있나요?")
        }
        if ageInDays >= 120 && ageInDays <= 180 {
            items.append("이유식 시작 시기에 대해 조언을 구하고 싶습니다.")
        }

        // 중복 제거 (순서 유지)
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }

    // MARK: - 헬퍼

    private static func recentMean(_ values: [Double], days: Int) -> Double {
        let recent = Array(values.suffix(days))
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0, +) / Double(recent.count)
    }

    private static func baselineMean(_ values: [Double]) -> Double {
        let baseline = Array(values.prefix(7))
        guard !baseline.isEmpty else { return 0 }
        return baseline.reduce(0, +) / Double(baseline.count)
    }
}
