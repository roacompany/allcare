import Foundation
import Darwin

// MARK: - GrowthMetric

enum GrowthMetric {
    case weight          // kg
    case height          // cm (length)
    case headCircumference // cm
}

// MARK: - GrowthVelocityResult

struct GrowthVelocityResult {
    enum ChangeDirection {
        case increasing
        case decreasing
        case stable
    }

    let currentPercentile: Double
    let previousPercentile: Double
    let changeDirection: ChangeDirection
    /// true if percentile change crosses 2 major bands (3/15/50/85/97)
    let isSignificant: Bool
}

// MARK: - PercentileCalculator
// 출처: WHO Child Growth Standards 2006 (LMS method)
// https://www.who.int/tools/child-growth-standards

enum PercentileCalculator {

    // MARK: - LMS Table Entry

    private struct LMS {
        let L: Double
        let M: Double
        let S: Double
    }

    // MARK: - WHO 2006 LMS Tables (0–24 months)

    // Weight-for-age Boys
    private static let weightBoys: [LMS] = [
        LMS(L: 0.3487,  M: 3.3464,  S: 0.14602), // 0
        LMS(L: 0.2297,  M: 4.4709,  S: 0.13395), // 1
        LMS(L: 0.1970,  M: 5.5675,  S: 0.12385), // 2
        LMS(L: 0.1738,  M: 6.3762,  S: 0.11727), // 3
        LMS(L: 0.1553,  M: 7.0023,  S: 0.11316), // 4
        LMS(L: 0.1395,  M: 7.5105,  S: 0.10960), // 5
        LMS(L: 0.1257,  M: 7.9340,  S: 0.10652), // 6
        LMS(L: 0.1134,  M: 8.2970,  S: 0.10394), // 7
        LMS(L: 0.1021,  M: 8.6151,  S: 0.10183), // 8
        LMS(L: 0.0917,  M: 8.9014,  S: 0.10012), // 9
        LMS(L: 0.0822,  M: 9.1649,  S: 0.09878), // 10
        LMS(L: 0.0733,  M: 9.4122,  S: 0.09774), // 11
        LMS(L: 0.0651,  M: 9.6479,  S: 0.09695), // 12
        LMS(L: 0.0576,  M: 9.8749,  S: 0.09637), // 13
        LMS(L: 0.0506,  M: 10.0953, S: 0.09596), // 14
        LMS(L: 0.0441,  M: 10.3108, S: 0.09568), // 15
        LMS(L: 0.0381,  M: 10.5228, S: 0.09551), // 16
        LMS(L: 0.0326,  M: 10.7319, S: 0.09544), // 17
        LMS(L: 0.0275,  M: 10.9385, S: 0.09544), // 18
        LMS(L: 0.0228,  M: 11.1430, S: 0.09553), // 19
        LMS(L: 0.0183,  M: 11.3462, S: 0.09566), // 20
        LMS(L: 0.0141,  M: 11.5486, S: 0.09584), // 21
        LMS(L: 0.0102,  M: 11.7504, S: 0.09607), // 22
        LMS(L: 0.0065,  M: 11.9514, S: 0.09634), // 23
        LMS(L: 0.0030,  M: 12.1515, S: 0.09664), // 24
    ]

    // Weight-for-age Girls
    private static let weightGirls: [LMS] = [
        LMS(L: 0.3809,  M: 3.2322,  S: 0.14171), // 0
        LMS(L: 0.1714,  M: 4.1873,  S: 0.13724), // 1
        LMS(L: 0.0962,  M: 5.1282,  S: 0.13000), // 2
        LMS(L: 0.0402,  M: 5.8458,  S: 0.12619), // 3
        LMS(L: -0.0050, M: 6.4237,  S: 0.12402), // 4
        LMS(L: -0.0430, M: 6.8985,  S: 0.12274), // 5
        LMS(L: -0.0756, M: 7.2970,  S: 0.12204), // 6
        LMS(L: -0.1039, M: 7.6422,  S: 0.12178), // 7
        LMS(L: -0.1288, M: 7.9487,  S: 0.12181), // 8
        LMS(L: -0.1507, M: 8.2254,  S: 0.12199), // 9
        LMS(L: -0.1700, M: 8.4800,  S: 0.12223), // 10
        LMS(L: -0.1872, M: 8.7192,  S: 0.12247), // 11
        LMS(L: -0.2024, M: 8.9481,  S: 0.12268), // 12
        LMS(L: -0.2158, M: 9.1699,  S: 0.12283), // 13
        LMS(L: -0.2278, M: 9.3870,  S: 0.12294), // 14
        LMS(L: -0.2384, M: 9.6008,  S: 0.12299), // 15
        LMS(L: -0.2478, M: 9.8124,  S: 0.12303), // 16
        LMS(L: -0.2562, M: 10.0226, S: 0.12306), // 17
        LMS(L: -0.2637, M: 10.2315, S: 0.12309), // 18
        LMS(L: -0.2703, M: 10.4393, S: 0.12315), // 19
        LMS(L: -0.2762, M: 10.6464, S: 0.12323), // 20
        LMS(L: -0.2815, M: 10.8534, S: 0.12335), // 21
        LMS(L: -0.2862, M: 11.0608, S: 0.12351), // 22
        LMS(L: -0.2903, M: 11.2688, S: 0.12371), // 23
        LMS(L: -0.2941, M: 11.4775, S: 0.12396), // 24
    ]

    // Length-for-age Boys
    private static let heightBoys: [LMS] = [
        LMS(L: 1, M: 49.8842, S: 0.03795), // 0
        LMS(L: 1, M: 54.7244, S: 0.03557), // 1
        LMS(L: 1, M: 58.4249, S: 0.03424), // 2
        LMS(L: 1, M: 61.4292, S: 0.03328), // 3
        LMS(L: 1, M: 63.8860, S: 0.03257), // 4
        LMS(L: 1, M: 65.9026, S: 0.03204), // 5
        LMS(L: 1, M: 67.6236, S: 0.03165), // 6
        LMS(L: 1, M: 69.1645, S: 0.03139), // 7
        LMS(L: 1, M: 70.5994, S: 0.03124), // 8
        LMS(L: 1, M: 71.9687, S: 0.03117), // 9
        LMS(L: 1, M: 73.2812, S: 0.03118), // 10
        LMS(L: 1, M: 74.5388, S: 0.03125), // 11
        LMS(L: 1, M: 75.7488, S: 0.03137), // 12
        LMS(L: 1, M: 76.9186, S: 0.03154), // 13
        LMS(L: 1, M: 78.0497, S: 0.03174), // 14
        LMS(L: 1, M: 79.1458, S: 0.03197), // 15
        LMS(L: 1, M: 80.2113, S: 0.03222), // 16
        LMS(L: 1, M: 81.2487, S: 0.03248), // 17
        LMS(L: 1, M: 82.2587, S: 0.03277), // 18
        LMS(L: 1, M: 83.2418, S: 0.03307), // 19
        LMS(L: 1, M: 84.1996, S: 0.03337), // 20
        LMS(L: 1, M: 85.1348, S: 0.03369), // 21
        LMS(L: 1, M: 86.0477, S: 0.03401), // 22
        LMS(L: 1, M: 86.9412, S: 0.03433), // 23
        LMS(L: 1, M: 87.8161, S: 0.03466), // 24
    ]

    // Length-for-age Girls
    // Month 1 S: 0.03599 (WHO 2006 공식 테이블)
    private static let heightGirls: [LMS] = [
        LMS(L: 1, M: 49.1477, S: 0.03790), // 0
        LMS(L: 1, M: 53.6872, S: 0.03599), // 1
        LMS(L: 1, M: 57.0673, S: 0.03444), // 2
        LMS(L: 1, M: 59.8029, S: 0.03392), // 3
        LMS(L: 1, M: 62.0899, S: 0.03351), // 4
        LMS(L: 1, M: 64.0301, S: 0.03319), // 5
        LMS(L: 1, M: 65.7311, S: 0.03293), // 6
        LMS(L: 1, M: 67.2873, S: 0.03275), // 7
        LMS(L: 1, M: 68.7498, S: 0.03262), // 8
        LMS(L: 1, M: 70.1435, S: 0.03255), // 9
        LMS(L: 1, M: 71.4818, S: 0.03254), // 10
        LMS(L: 1, M: 72.7710, S: 0.03257), // 11
        LMS(L: 1, M: 74.0153, S: 0.03265), // 12
        LMS(L: 1, M: 75.2154, S: 0.03278), // 13
        LMS(L: 1, M: 76.3817, S: 0.03293), // 14
        LMS(L: 1, M: 77.5199, S: 0.03312), // 15
        LMS(L: 1, M: 78.6330, S: 0.03334), // 16
        LMS(L: 1, M: 79.7236, S: 0.03358), // 17
        LMS(L: 1, M: 80.7934, S: 0.03383), // 18
        LMS(L: 1, M: 81.8424, S: 0.03410), // 19
        LMS(L: 1, M: 82.8725, S: 0.03439), // 20
        LMS(L: 1, M: 83.8856, S: 0.03468), // 21
        LMS(L: 1, M: 84.8820, S: 0.03498), // 22
        LMS(L: 1, M: 85.8643, S: 0.03529), // 23
        LMS(L: 1, M: 86.8329, S: 0.03561), // 24
    ]

    // Head-circumference-for-age Boys
    private static let headBoys: [LMS] = [
        LMS(L: 1, M: 34.4618, S: 0.03686), // 0
        LMS(L: 1, M: 37.2759, S: 0.03133), // 1
        LMS(L: 1, M: 39.1285, S: 0.02997), // 2
        LMS(L: 1, M: 40.5135, S: 0.02918), // 3
        LMS(L: 1, M: 41.6317, S: 0.02868), // 4
        LMS(L: 1, M: 42.5576, S: 0.02837), // 5
        LMS(L: 1, M: 43.3306, S: 0.02817), // 6
        LMS(L: 1, M: 43.9803, S: 0.02804), // 7
        LMS(L: 1, M: 44.5300, S: 0.02796), // 8
        LMS(L: 1, M: 44.9998, S: 0.02792), // 9
        LMS(L: 1, M: 45.4051, S: 0.02790), // 10
        LMS(L: 1, M: 45.7573, S: 0.02790), // 11
        LMS(L: 1, M: 46.0661, S: 0.02791), // 12
        LMS(L: 1, M: 46.3395, S: 0.02793), // 13
        LMS(L: 1, M: 46.5844, S: 0.02795), // 14
        LMS(L: 1, M: 46.8066, S: 0.02797), // 15
        LMS(L: 1, M: 47.0106, S: 0.02799), // 16
        LMS(L: 1, M: 47.1996, S: 0.02801), // 17
        LMS(L: 1, M: 47.3762, S: 0.02802), // 18
        LMS(L: 1, M: 47.5422, S: 0.02804), // 19
        LMS(L: 1, M: 47.6985, S: 0.02806), // 20
        LMS(L: 1, M: 47.8463, S: 0.02807), // 21
        LMS(L: 1, M: 47.9863, S: 0.02809), // 22
        LMS(L: 1, M: 48.1190, S: 0.02811), // 23
        LMS(L: 1, M: 48.2450, S: 0.02813), // 24
    ]

    // Head-circumference-for-age Girls
    private static let headGirls: [LMS] = [
        LMS(L: 1, M: 33.8787, S: 0.03496), // 0
        LMS(L: 1, M: 36.5463, S: 0.03099), // 1
        LMS(L: 1, M: 38.2521, S: 0.02998), // 2
        LMS(L: 1, M: 39.5328, S: 0.02941), // 3
        LMS(L: 1, M: 40.5817, S: 0.02907), // 4
        LMS(L: 1, M: 41.4590, S: 0.02884), // 5
        LMS(L: 1, M: 42.1995, S: 0.02869), // 6
        LMS(L: 1, M: 42.8290, S: 0.02860), // 7
        LMS(L: 1, M: 43.3671, S: 0.02855), // 8
        LMS(L: 1, M: 43.8299, S: 0.02852), // 9
        LMS(L: 1, M: 44.2319, S: 0.02851), // 10
        LMS(L: 1, M: 44.5844, S: 0.02851), // 11
        LMS(L: 1, M: 44.8965, S: 0.02852), // 12
        LMS(L: 1, M: 45.1752, S: 0.02853), // 13
        LMS(L: 1, M: 45.4265, S: 0.02855), // 14
        LMS(L: 1, M: 45.6550, S: 0.02856), // 15
        LMS(L: 1, M: 45.8650, S: 0.02858), // 16
        LMS(L: 1, M: 46.0598, S: 0.02859), // 17
        LMS(L: 1, M: 46.2424, S: 0.02861), // 18
        LMS(L: 1, M: 46.4152, S: 0.02863), // 19
        LMS(L: 1, M: 46.5801, S: 0.02864), // 20
        LMS(L: 1, M: 46.7384, S: 0.02866), // 21
        LMS(L: 1, M: 46.8913, S: 0.02868), // 22
        LMS(L: 1, M: 47.0391, S: 0.02870), // 23
        LMS(L: 1, M: 47.1822, S: 0.02872), // 24
    ]

    // MARK: - Z-score 계산
    // Z = [(X/M)^L - 1] / (L × S)   (L ≠ 0)
    // Z = ln(X/M) / S                (L = 0)
    // 출처: WHO Technical Note, LMS method
    static func lmsZScore(value: Double, L: Double, M: Double, S: Double) -> Double {
        guard value > 0, M > 0, S > 0 else { return 0 }
        let z: Double
        if abs(L) < 1e-10 {
            // L=0 special case: use natural log
            z = log(value / M) / S
        } else {
            z = (pow(value / M, L) - 1.0) / (L * S)
        }
        // Clamp to ±6
        return min(max(z, -6.0), 6.0)
    }

    // MARK: - Percentile 변환
    // percentile = 0.5 × (1 + erf(z / √2)) × 100
    static func zScoreToPercentile(_ z: Double) -> Double {
        return 0.5 * (1.0 + erf(z / sqrt(2.0))) * 100.0
    }

    // MARK: - Probit (역 표준정규분포)
    // 출처: Peter Acklam 근사식 (최대 오차 1.15e-9)
    private static func probit(_ p: Double) -> Double {
        let pClamped = min(max(p, 1e-10), 1.0 - 1e-10)
        let q = pClamped - 0.5
        if abs(q) <= 0.425 {
            let r = 0.180625 - q * q
            return q * (((((((2.5090809287301226727e3 * r + 3.3430575583588128105e4) * r
                + 6.7265770927008700853e4) * r + 4.5921953931549871457e4) * r
                + 1.3731693765509461125e4) * r + 1.9715909503065514427e3) * r
                + 1.3731693765509461125e2) * r + 3.7442163487909700102e0)
            / (((((((5.2264952788528545610e3 * r + 2.8729085735721942674e4) * r
                + 3.9307895800092710610e4) * r + 2.1213794301586595867e4) * r
                + 5.3941960214247511077e3) * r + 6.8718700749205790830e2) * r
                + 4.2313330701600911252e1) * r + 1.0)
        } else {
            var r = pClamped < 0.5 ? pClamped : 1.0 - pClamped
            r = sqrt(-log(r))
            let val: Double
            if r <= 5.0 {
                r -= 1.6
                val = (((((((7.7133361990960248132e-5 * r + 2.3105786152686598490e-4) * r
                    - 2.7517406297064545428e-3) * r + 1.7928595602732714483e-3) * r
                    + 1.1823861168977886978e-3) * r - 2.8368827566272588840e-3) * r
                    + 3.4662784498600892447e-4) * r + 7.4054830498898219226e-4)
                / ((((((1.0578491091918808006e-5 * r + 1.0581588582427879602e-4) * r
                    + 7.7425940718813823888e-4) * r + 2.6280423716007866038e-3) * r
                    + 7.6480980862268199562e-3) * r + 1.5850434510283533068e-2) * r
                    + 2.7044302606987040621e-2)
            } else {
                r -= 5.0
                val = ((2.010334087e-1 * r + 2.6997510408e0) * r + 3.23774891776e0)
                    / ((6.02427039482e-2 * r + 1.64450282446e0) * r + 1.0)
            }
            return q < 0 ? -val : val
        }
    }

    // MARK: - 역 LMS: 백분위 → 측정값
    // X = M × (1 + L·S·z)^(1/L)  (L ≠ 0)
    // X = M × exp(S·z)             (L = 0)
    /// 특정 월령·성별·지표의 WHO 참조값 (백분위 → 측정값)
    static func referenceValue(
        percentile p: Double,
        ageMonths: Int,
        gender: Baby.Gender,
        metric: GrowthMetric
    ) -> Double? {
        guard ageMonths >= 0, ageMonths <= 24 else { return nil }
        guard p > 0, p < 100 else { return nil }

        let table: [LMS]
        switch (metric, gender) {
        case (.weight, .male):              table = weightBoys
        case (.weight, .female):            table = weightGirls
        case (.height, .male):              table = heightBoys
        case (.height, .female):            table = heightGirls
        case (.headCircumference, .male):   table = headBoys
        case (.headCircumference, .female): table = headGirls
        }

        let entry = table[ageMonths]
        let z = probit(p / 100.0)
        let L = entry.L, M = entry.M, S = entry.S
        if abs(L) < 1e-10 {
            return M * exp(S * z)
        } else {
            let base = 1.0 + L * S * z
            guard base > 0 else { return nil }
            return M * pow(base, 1.0 / L)
        }
    }

    // MARK: - Public API

    /// WHO 2006 LMS 백분위수 계산
    /// - Parameters:
    ///   - value: 측정값 (체중: kg, 신장: cm, 두위: cm)
    ///   - ageMonths: 월령 (0–24)
    ///   - gender: 성별
    ///   - metric: 지표 종류
    /// - Returns: 백분위수 (0–100), 입력값이 유효하지 않으면 nil
    static func percentile(
        value: Double,
        ageMonths: Int,
        gender: Baby.Gender,
        metric: GrowthMetric
    ) -> Double? {
        // 방어: 음수 또는 0 값 거부
        guard value > 0 else { return nil }
        // 월령 범위: 0–24
        guard ageMonths >= 0, ageMonths <= 24 else { return nil }

        let table: [LMS]
        switch (metric, gender) {
        case (.weight, .male):           table = weightBoys
        case (.weight, .female):         table = weightGirls
        case (.height, .male):           table = heightBoys
        case (.height, .female):         table = heightGirls
        case (.headCircumference, .male): table = headBoys
        case (.headCircumference, .female): table = headGirls
        }

        let entry = table[ageMonths]
        let z = lmsZScore(value: value, L: entry.L, M: entry.M, S: entry.S)
        return zScoreToPercentile(z)
    }

    // MARK: - Growth Velocity

    /// 최근 2개 기록을 비교하여 성장 속도(백분위 변화)를 계산합니다.
    /// - Parameters:
    ///   - records: 날짜순 정렬된 성장 기록 배열
    ///   - metric: 분석할 지표
    ///   - gender: 아기 성별
    ///   - birthDate: 아기 생년월일
    /// - Returns: 백분위 변화 결과. 해당 metric 기록이 2개 미만이면 nil
    static func growthVelocity(
        records: [GrowthRecord],
        metric: GrowthMetric,
        gender: Baby.Gender,
        birthDate: Date
    ) -> GrowthVelocityResult? {
        // metric 값이 존재하는 기록만 추출 (날짜 오름차순)
        let relevant: [(date: Date, value: Double)] = records
            .sorted { $0.date < $1.date }
            .compactMap { r in
                let val: Double?
                switch metric {
                case .weight:           val = r.weight
                case .height:           val = r.height
                case .headCircumference: val = r.headCircumference
                }
                guard let v = val else { return nil }
                return (r.date, v)
            }

        guard relevant.count >= 2 else { return nil }

        let prev = relevant[relevant.count - 2]
        let curr = relevant[relevant.count - 1]

        let prevMonths = max(0, min(24, Int(prev.date.timeIntervalSince(birthDate) / (86400 * 30.4375))))
        let currMonths = max(0, min(24, Int(curr.date.timeIntervalSince(birthDate) / (86400 * 30.4375))))

        guard let prevPct = percentile(value: prev.value, ageMonths: prevMonths, gender: gender, metric: metric),
              let currPct = percentile(value: curr.value, ageMonths: currMonths, gender: gender, metric: metric) else {
            return nil
        }

        // 방향 판정
        let diff = currPct - prevPct
        let direction: GrowthVelocityResult.ChangeDirection
        if diff > 2 {
            direction = .increasing
        } else if diff < -2 {
            direction = .decreasing
        } else {
            direction = .stable
        }

        // 주요 밴드 경계: 3 / 15 / 50 / 85 / 97
        let bands: [Double] = [3, 15, 50, 85, 97]
        func bandIndex(_ p: Double) -> Int {
            var idx = 0
            for (i, b) in bands.enumerated() {
                if p >= b { idx = i + 1 }
            }
            return idx
        }
        let prevBand = bandIndex(prevPct)
        let currBand = bandIndex(currPct)
        let isSignificant = abs(currBand - prevBand) >= 2

        return GrowthVelocityResult(
            currentPercentile: currPct,
            previousPercentile: prevPct,
            changeDirection: direction,
            isSignificant: isSignificant
        )
    }
}
