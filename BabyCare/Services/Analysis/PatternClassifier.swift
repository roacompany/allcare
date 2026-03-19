import Foundation

// MARK: - Step 4: Layer 3 — 다변량 패턴 분류

enum PatternClassifier {

    static func classify(flags: [MetricFlag], aggregates: [DailyAggregate]) -> [DetectedPattern] {
        var patterns: [DetectedPattern] = []

        let feeding = flags.first { $0.metric == .feeding }
        let sleep   = flags.first { $0.metric == .sleep }
        let diaper  = flags.first { $0.metric == .diaper }
        let temp    = flags.first { $0.metric == .temperature }

        // 성장급등: 수유↓ + 수면↑ 동시 발생
        if let f = feeding, let s = sleep,
           f.direction == .down, s.direction == .up {
            patterns.append(.growthSpurt)
        }

        // 성장급등 추가 패턴: 수유↑ + 수면↑ (급등 전 과식기)
        if let f = feeding, let s = sleep,
           f.direction == .up, s.direction == .up,
           !patterns.contains(.growthSpurt) {
            patterns.append(.growthSpurt)
        }

        // 감염 의심: 수면↓ + 체온↑ (또는 기저귀 이상)
        let recentFever = aggregates.suffix(5).contains { ($0.avgTemperature ?? 0) >= 38.0 }
        if let s = sleep, s.direction == .down, (temp?.direction == .up || recentFever) {
            patterns.append(.infectionSuspected)
        }

        // 탈수 위험: 기저귀↓ + 수유↓ 동시 발생
        if let d = diaper, let f = feeding,
           d.direction == .down, f.direction == .down {
            patterns.append(.dehydrationRisk)
        }

        // 단순 변동 (위에 해당 없고 플래그만 있는 경우)
        if patterns.isEmpty && !flags.isEmpty {
            patterns.append(.normalVariation)
        }

        return patterns
    }

    // 성장급등 감지 시 Layer 2 플래그 재분류 (오경보 억제)
    static func suppressGrowthSpurtFlags(_ flags: [MetricFlag], patterns: [DetectedPattern]) -> [MetricFlag] {
        guard patterns.contains(.growthSpurt) else { return flags }

        // 성장급등 패턴이면 수유↓, 수면↑ 플래그의 우선순위 낮춤 (제거 아닌 score 감소)
        return flags.map { flag in
            var f = flag
            if (f.metric == .feeding && f.direction == .down) ||
               (f.metric == .sleep   && f.direction == .up) {
                f.score *= 0.4
            }
            return f
        }
    }
}
