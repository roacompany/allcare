import Foundation

// MARK: - Step 3: Layer 2 — 개인 기준선 이탈 감지
// EWMA (λ=0.15) + 강건 SD (IQR/1.35) + CUSUM (k=0.5σ, h=5σ)
// 검증: Page(1954) Biometrika, NIST e-Handbook §6.3.2.3-4, PMC10248291

enum BaselineDetector {

    private static let lambda: Double = 0.15
    private static let ewmaL: Double = 2.615      // UCL/LCL 계수 (ARL≈500, λ=0.15)
    private static let cusumK: Double = 0.5       // 참조값 계수 k = 0.5σ
    private static let cusumH: Double = 5.0       // 임계값 계수 h = 5σ (h=4보다 오경보 감소)

    // MARK: - 메인 감지

    static func detect(aggregates: [DailyAggregate], ageInDays: Int) -> [MetricFlag] {
        guard aggregates.count >= 7 else { return [] }

        var flags: [MetricFlag] = []

        // 이상치 제거 후 분석
        let clean = aggregates.filter { !$0.hasOutlier }

        flags += analyzeMetric(
            values: clean.map { Double($0.feedingCount) },
            dates: clean.map { $0.date },
            metric: .feeding,
            ageInDays: ageInDays
        )
        flags += analyzeMetric(
            values: clean.compactMap { $0.feedingAmountMl > 0 ? $0.feedingAmountMl : nil },
            dates: clean.filter { $0.feedingAmountMl > 0 }.map { $0.date },
            metric: .feedingAmount,
            ageInDays: ageInDays
        )
        flags += analyzeMetric(
            values: clean.map { $0.sleepMinutes / 60.0 },   // 시간으로 변환
            dates: clean.map { $0.date },
            metric: .sleep,
            ageInDays: ageInDays
        )
        flags += analyzeMetric(
            values: clean.map { Double($0.diaperCount) },
            dates: clean.map { $0.date },
            metric: .diaper,
            ageInDays: ageInDays
        )

        return flags
    }

    // MARK: - 지표별 분석

    private static func analyzeMetric(
        values: [Double],
        dates: [Date],
        metric: MetricFlag.Metric,
        ageInDays: Int
    ) -> [MetricFlag] {
        guard values.count >= 7 else { return [] }

        let baselineValues = Array(values.prefix(7))
        let mu0 = mean(baselineValues)
        let sigma1 = robustSD(baselineValues)
        guard sigma1 > 0 else { return [] }

        // EWMA
        let ewmaResult = ewma(values: values, mu0: mu0, sigma1: sigma1)

        // CUSUM
        let cusumResult = cusum(values: values, dates: dates, mu0: mu0, sigma1: sigma1)

        var flags: [MetricFlag] = []

        // EWMA UCL/LCL 위반
        let ewmaSD = ewmaL * sigma1 * sqrt(lambda / (2.0 - lambda))
        if let lastEWMA = ewmaResult.last {
            let deviation = abs(lastEWMA - mu0)
            if deviation > ewmaSD {
                let direction: MetricFlag.Direction = lastEWMA > mu0 ? .up : .down
                let score = deviation / sigma1
                flags.append(MetricFlag(
                    metric: metric,
                    layer: .baseline,
                    direction: direction,
                    sigmaDistance: score,
                    changePointDate: cusumResult.changePointDate,
                    score: score
                ))
            }
        }

        // CUSUM 단독 감지 (EWMA 미감지 시 추가)
        if flags.isEmpty, let changeDate = cusumResult.changePointDate {
            let recentMean = mean(Array(values.suffix(min(7, values.count))))
            let direction: MetricFlag.Direction = recentMean > mu0 ? .up : .down
            let score = abs(recentMean - mu0) / sigma1
            if score > 0.5 {
                flags.append(MetricFlag(
                    metric: metric,
                    layer: .baseline,
                    direction: direction,
                    sigmaDistance: score,
                    changePointDate: changeDate,
                    score: score
                ))
            }
        }

        return flags
    }

    // MARK: - EWMA

    private static func ewma(values: [Double], mu0: Double, sigma1: Double) -> [Double] {
        var z = mu0
        return values.map { x in
            z = lambda * x + (1 - lambda) * z
            return z
        }
    }

    // MARK: - CUSUM (Tabular)
    // S⁺ₜ = max(0, S⁺ₜ₋₁ + (xₜ - μ̂₁) - k·σ₁)
    // S⁻ₜ = max(0, S⁻ₜ₋₁ - (xₜ - μ̂₁) - k·σ₁)

    private static func cusum(
        values: [Double],
        dates: [Date],
        mu0: Double,
        sigma1: Double
    ) -> (sPlus: [Double], sMinus: [Double], changePointDate: Date?) {
        let k = cusumK * sigma1
        let h = cusumH * sigma1
        var sPlus = 0.0, sMinus = 0.0
        var sValues: [(Double, Double)] = []
        var changePointDate: Date?

        for (i, x) in values.enumerated() {
            sPlus = max(0, sPlus + (x - mu0) - k)
            sMinus = max(0, sMinus - (x - mu0) - k)
            sValues.append((sPlus, sMinus))

            if changePointDate == nil && (sPlus > h || sMinus > h) {
                changePointDate = i < dates.count ? dates[i] : nil
            }
        }

        return (sValues.map { $0.0 }, sValues.map { $0.1 }, changePointDate)
    }

    // MARK: - 강건 SD (IQR / 1.35)
    // 수학적 근거: 정규분포에서 IQR = 1.34898 × SD

    static func robustSD(_ values: [Double]) -> Double {
        guard values.count >= 4 else {
            let m = mean(values)
            return sqrt(values.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(values.count))
        }
        let sorted = values.sorted()
        let n = sorted.count
        let q1 = sorted[n / 4]
        let q3 = sorted[(3 * n) / 4]
        let iqr = q3 - q1
        return iqr / 1.35
    }

    private static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
